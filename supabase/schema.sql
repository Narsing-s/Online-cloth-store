-- THREAD & CO. Supabase schema. Run in SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text,phone text,created_at timestamptz default now());
create table if not exists public.user_roles(user_id uuid references auth.users(id) on delete cascade,role text not null check(role in('admin','customer')),primary key(user_id,role));
create table if not exists public.products(id uuid primary key default gen_random_uuid(),name text not null,category text not null check(category in('Men','Women','Kids','Footwear','Accessories','Essentials')),type text not null,description text default '',price numeric(10,2) not null check(price>=0),compare_at_price numeric(10,2) default 0,image_url text not null,sizes text[] not null default '{}',stock integer not null default 0 check(stock>=0),active boolean not null default true,created_at timestamptz default now());
create table if not exists public.orders(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),status text not null default 'placed' check(status in('placed','confirmed','packed','shipped','delivered','cancelled')),total numeric(10,2) not null,payment_method text not null default 'COD',payment_status text not null default 'pending',shipping_address jsonb not null,created_at timestamptz default now());
create table if not exists public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,product_id uuid references public.products(id),product_name text not null,unit_price numeric(10,2) not null,quantity integer not null check(quantity>0),selected_size text);
create or replace function public.is_store_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.user_roles where user_id=auth.uid() and role='admin'); $$;
create or replace function public.handle_store_signup() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end; $$;
drop trigger if exists on_auth_user_created_store on auth.users;
create trigger on_auth_user_created_store after insert on auth.users for each row execute procedure public.handle_store_signup();
alter table public.profiles enable row level security;alter table public.user_roles enable row level security;alter table public.products enable row level security;alter table public.orders enable row level security;alter table public.order_items enable row level security;
drop policy if exists "profile owner or admin read" on public.profiles;create policy "profile owner or admin read" on public.profiles for select to authenticated using(id=auth.uid() or public.is_store_admin());
drop policy if exists "profile owner update" on public.profiles;create policy "profile owner update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
drop policy if exists "public active products" on public.products;create policy "public active products" on public.products for select using(active=true or public.is_store_admin());
drop policy if exists "admin manage products" on public.products;create policy "admin manage products" on public.products for all to authenticated using(public.is_store_admin()) with check(public.is_store_admin());
drop policy if exists "read own role" on public.user_roles;create policy "read own role" on public.user_roles for select to authenticated using(user_id=auth.uid() or public.is_store_admin());
drop policy if exists "read own orders" on public.orders;create policy "read own orders" on public.orders for select to authenticated using(user_id=auth.uid() or public.is_store_admin());
drop policy if exists "admin update orders" on public.orders;create policy "admin update orders" on public.orders for update to authenticated using(public.is_store_admin()) with check(public.is_store_admin());
drop policy if exists "read order items" on public.order_items;create policy "read order items" on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_store_admin())));
create or replace function public.place_store_order(p_address jsonb,p_items jsonb,p_payment_method text default 'COD') returns uuid language plpgsql security definer set search_path=public as $$
declare v_order uuid;v_total numeric(10,2):=0;v_item jsonb;v_product public.products%rowtype;v_qty integer;v_size text;
begin
 if auth.uid() is null then raise exception 'Sign in to place an order';end if;
 if p_payment_method<>'COD' then raise exception 'Online payment is not configured';end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty';end if;
 if coalesce(p_address->>'name','')='' or coalesce(p_address->>'phone','')='' or coalesce(p_address->>'line','')='' or coalesce(p_address->>'city','')='' or coalesce(p_address->>'pincode','')='' then raise exception 'Complete delivery details';end if;
 for v_item in select * from jsonb_array_elements(p_items) loop
  if nullif(v_item->>'product_id','') is null then raise exception 'Demo catalogue items cannot be ordered. Add published store products first.';end if;
  v_qty:=(v_item->>'quantity')::integer;v_size:=v_item->>'size';if v_qty<1 then raise exception 'Invalid quantity';end if;
  select * into v_product from public.products where id=(v_item->>'product_id')::uuid and active=true for update;
  if not found then raise exception 'Product is unavailable';end if;
  if v_product.stock<v_qty then raise exception 'Insufficient stock for %',v_product.name;end if;
  if not(v_size=any(v_product.sizes)) then raise exception 'Selected size is unavailable for %',v_product.name;end if;
  v_total:=v_total+v_product.price*v_qty;
 end loop;
 if v_total<1499 then v_total:=v_total+79; end if;
 insert into public.orders(user_id,total,payment_method,payment_status,shipping_address) values(auth.uid(),v_total,'COD','pending',p_address) returning id into v_order;
 for v_item in select * from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity')::integer;v_size:=v_item->>'size';select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
  insert into public.order_items(order_id,product_id,product_name,unit_price,quantity,selected_size) values(v_order,v_product.id,v_product.name,v_product.price,v_qty,v_size);
  update public.products set stock=stock-v_qty where id=v_product.id;
 end loop;
 return v_order;
end;$$;
revoke all on function public.place_store_order(jsonb,jsonb,text) from public;grant execute on function public.place_store_order(jsonb,jsonb,text) to authenticated;
-- After registering your own account, copy its UUID from Authentication > Users and run:
-- insert into public.user_roles(user_id,role) values('YOUR_AUTH_USER_UUID','admin');

-- Safe category expansion for projects that already ran an earlier schema version.
alter table public.products drop constraint if exists products_category_check;
alter table public.products add constraint products_category_check check(category in('Men','Women','Kids','Footwear','Accessories','Essentials'));
create index if not exists products_active_category_idx on public.products(category,active,created_at desc);
create index if not exists orders_user_created_idx on public.orders(user_id,created_at desc);
create index if not exists order_items_order_idx on public.order_items(order_id);
