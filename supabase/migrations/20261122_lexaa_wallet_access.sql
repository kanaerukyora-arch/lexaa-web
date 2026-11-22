-- Lexaa wallet access: phone + PIN, bound to the currently authenticated Lexaa account.
-- IMPORTANT: phone numbers are not verified because the requested flow intentionally has no OTP.
-- Anyone who can access an account can claim an unclaimed number; do not use this as proof of phone ownership.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.lexaa_wallet_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_e164 text not null unique,
  pin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  last_login_at timestamptz
);

alter table public.lexaa_wallet_access enable row level security;
revoke all on public.lexaa_wallet_access from anon, authenticated;

create or replace function public.lexaa_wallet_register(p_phone text, p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Please sign in to Lexaa first.'; end if;
  if p_phone !~ '^\+62[0-9]{8,13}$' then raise exception 'Invalid phone number.'; end if;
  if p_pin !~ '^[0-9]{6}$' then raise exception 'PIN must contain exactly 6 digits.'; end if;
  insert into public.lexaa_wallet_access(user_id, phone_e164, pin_hash)
  values (v_user, p_phone, extensions.crypt(p_pin, extensions.gen_salt('bf', 12)));
  return true;
exception
  when unique_violation then raise exception 'This phone number or wallet is already registered.';
end;
$$;

create or replace function public.lexaa_wallet_login(p_phone text, p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user uuid := auth.uid();
  v_row public.lexaa_wallet_access%rowtype;
begin
  if v_user is null then raise exception 'Please sign in to Lexaa first.'; end if;
  if p_phone !~ '^\+62[0-9]{8,13}$' or p_pin !~ '^[0-9]{6}$' then
    raise exception 'Invalid wallet credentials.';
  end if;

  select * into v_row
  from public.lexaa_wallet_access
  where user_id = v_user and phone_e164 = p_phone
  for update;

  if not found then raise exception 'Wallet number is not registered for this account.'; end if;
  if v_row.locked_until is not null and v_row.locked_until > now() then
    raise exception 'Too many attempts. Try again in 15 minutes.';
  end if;

  if extensions.crypt(p_pin, v_row.pin_hash) <> v_row.pin_hash then
    update public.lexaa_wallet_access
    set failed_attempts = failed_attempts + 1,
        locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else null end
    where user_id = v_user;
    raise exception 'Invalid wallet credentials.';
  end if;

  update public.lexaa_wallet_access
  set failed_attempts = 0, locked_until = null, last_login_at = now()
  where user_id = v_user;
  return true;
end;
$$;

revoke all on function public.lexaa_wallet_register(text,text) from public, anon;
revoke all on function public.lexaa_wallet_login(text,text) from public, anon;
grant execute on function public.lexaa_wallet_register(text,text) to authenticated;
grant execute on function public.lexaa_wallet_login(text,text) to authenticated;
