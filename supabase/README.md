# Supabase setup for Lexaa Wallet

1. Open the Supabase project connected to Lexaa.
2. Go to **SQL Editor**.
3. Open and run `supabase/migrations/20261122_lexaa_wallet_access.sql`.
4. Reload Lexaa (or close and reopen the PWA) to fetch the updated wallet page.

The phone + PIN wallet is linked to the currently signed-in Lexaa account. PIN hashes are stored server-side; raw PINs are never stored. The requested no-OTP flow does **not** verify ownership of a phone number. A user can claim an unregistered number, so do not treat this as verified phone identity or use it for high-value funds.
