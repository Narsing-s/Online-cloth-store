# THREAD & CO. — Online Cloth Store

Responsive multi-category shopping storefront for men's fashion, women's fashion, kids' wear, slippers/footwear, accessories, women's innerwear and boys' innerwear.

## Run locally
1. Install Node.js 20+.
2. Copy `.env.example` to `.env.local`.
3. Add your Supabase project URL and publishable/anon key.
4. Run `npm install` then `npm run dev`.

## Supabase setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in Supabase → SQL Editor.
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel → Project Settings → Environment Variables (Production, Preview and Development).
4. Register your own account on the website.
5. In Supabase → Authentication → Users, copy your user UUID. Run the final admin insert statement in `schema.sql` after replacing `YOUR_AUTH_USER_UUID`.
6. Refresh the website. Admin Studio appears only for the account granted the admin role.
7. Publish real products from Admin Studio. The demo catalogue is for display only.

## Included
- Responsive premium storefront for five departments.
- Search, category filtering, price sorting and quick-view product details.
- Size selection, persistent bag, quantity controls and a persistent, browsable wishlist.
- Free-shipping threshold display and order total.
- Supabase email/password authentication.
- Admin-only product publishing, inventory visibility controls and order-status management.
- Customer account order history, wishlist management and Indian mobile/PIN validation at checkout.
- Row-level security and transactional COD order creation with stock validation.

## Production notes
- Demo items cannot be ordered; publish products into Supabase first.
- Checkout currently supports cash on delivery only. Razorpay is not connected. Do not enable online payments until server-side order creation, signature verification and webhook handling are implemented.
- Server-side order totals apply the same ₹79 shipping charge below ₹1,499 as the storefront.
- Configure Supabase Auth email settings before launch.
- Only the Supabase publishable/anon key belongs in frontend variables. Never expose the service-role key.
- Add real shipping, returns, privacy, terms and customer-support information before public launch.
