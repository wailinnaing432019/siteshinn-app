-- SiteShinn (စိုက်ရှင်း) Version 2 — Supabase PostgreSQL Schema & RLS
-- Run this entire script once in Supabase Dashboard -> SQL Editor.

create extension if not exists "pgcrypto";

-- 1. User Profiles (synced automatically from auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  email text,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, email, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, 'User'), '@', 1)
    ),
    new.email,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(nullif(public.profiles.display_name, ''), excluded.display_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. Accounts (Group Split & Personal Wallet)
create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  currency_code text not null default 'MMK',
  account_type text not null default 'group' check (account_type in ('group', 'personal')),
  opening_balance double precision not null default 0,
  invite_code text unique,
  created_at timestamptz not null default now()
);

-- 3. Group Members (linked optionally to a Supabase auth user_id)
create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_members_unique_user_per_account
  on public.members(account_id, user_id)
  where user_id is not null;

-- 4. Settlement Cycles
create table if not exists public.cycles (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  title text not null default '',
  start_date timestamptz not null default now(),
  end_date timestamptz,
  is_settled boolean not null default false
);

-- 5. Expenses & Personal Income/Expense Transactions
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  cycle_id uuid not null references public.cycles(id) on delete cascade,
  paid_by_member_id uuid references public.members(id) on delete set null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  tx_type text not null default 'expense' check (tx_type in ('expense', 'income')),
  title text not null,
  category text not null,
  amount double precision not null,
  expense_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- 6. Expense Splits
create table if not exists public.expense_splits (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  share_amount double precision not null
);

-- 7. Settled Transfers
create table if not exists public.settlement_transfers (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.cycles(id) on delete cascade,
  from_member_id uuid not null references public.members(id) on delete cascade,
  to_member_id uuid not null references public.members(id) on delete cascade,
  amount double precision not null,
  is_paid boolean not null default false,
  paid_at timestamptz
);

-- Indexes
create index if not exists idx_members_account on public.members(account_id);
create index if not exists idx_members_user on public.members(user_id);
create index if not exists idx_cycles_account on public.cycles(account_id, is_settled);
create index if not exists idx_expenses_cycle on public.expenses(cycle_id, expense_date desc);
create index if not exists idx_splits_expense on public.expense_splits(expense_id);

-- Security Definer Helper (prevents RLS recursion between accounts & members)
create or replace function public.is_account_member(p_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.accounts a
    where a.id = p_account_id and a.owner_id = auth.uid()
  )
  or exists (
    select 1 from public.members m
    where m.account_id = p_account_id and m.user_id = auth.uid()
  );
$$;

-- Enable RLS on all domain tables
alter table public.accounts enable row level security;
alter table public.members enable row level security;
alter table public.cycles enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlement_transfers enable row level security;

-- Accounts Policies
drop policy if exists "Members can view accounts" on public.accounts;
create policy "Members can view accounts"
  on public.accounts for select
  using (public.is_account_member(id));

drop policy if exists "Users can create own accounts" on public.accounts;
create policy "Users can create own accounts"
  on public.accounts for insert
  with check (auth.uid() = owner_id);

drop policy if exists "Members can update accounts" on public.accounts;
create policy "Members can update accounts"
  on public.accounts for update
  using (public.is_account_member(id));

drop policy if exists "Owners can delete accounts" on public.accounts;
create policy "Owners can delete accounts"
  on public.accounts for delete
  using (auth.uid() = owner_id);

-- Members Policies
drop policy if exists "Account members can view members" on public.members;
create policy "Account members can view members"
  on public.members for select
  using (public.is_account_member(account_id));

drop policy if exists "Account members can manage members" on public.members;
create policy "Account members can manage members"
  on public.members for all
  using (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

-- Cycles Policies
drop policy if exists "Account members can access cycles" on public.cycles;
create policy "Account members can access cycles"
  on public.cycles for all
  using (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

-- Expenses Policies
drop policy if exists "Account members can access expenses" on public.expenses;
create policy "Account members can access expenses"
  on public.expenses for all
  using (public.is_account_member(account_id))
  with check (public.is_account_member(account_id));

-- Expense Splits Policies
drop policy if exists "Account members can access splits" on public.expense_splits;
create policy "Account members can access splits"
  on public.expense_splits for all
  using (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id and public.is_account_member(e.account_id)
    )
  )
  with check (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id and public.is_account_member(e.account_id)
    )
  );

-- Settlement Transfers Policies
drop policy if exists "Account members can access transfers" on public.settlement_transfers;
create policy "Account members can access transfers"
  on public.settlement_transfers for all
  using (
    exists (
      select 1 from public.cycles c
      where c.id = cycle_id and public.is_account_member(c.account_id)
    )
  )
  with check (
    exists (
      select 1 from public.cycles c
      where c.id = cycle_id and public.is_account_member(c.account_id)
    )
  );

-- RPC: Preview group name and unclaimed member slots before joining
create or replace function public.preview_group_by_invite_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account public.accounts%rowtype;
  v_unclaimed jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_account
  from public.accounts
  where upper(invite_code) = upper(trim(p_code))
    and account_type = 'group'
  limit 1;

  if v_account.id is null then
    return null;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name) order by m.created_at),
    '[]'::jsonb
  )
  into v_unclaimed
  from public.members m
  where m.account_id = v_account.id
    and m.user_id is null
    and m.is_active = true;

  return jsonb_build_object(
    'account_id', v_account.id,
    'name', v_account.name,
    'currency_code', v_account.currency_code,
    'unclaimed_members', v_unclaimed
  );
end;
$$;

-- RPC: Join a group by invite code (either claim an existing member or add new)
create or replace function public.join_group_by_invite_code(
  p_code text,
  p_member_id uuid default null,
  p_display_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_account_id uuid;
  v_existing_member_id uuid;
  v_fallback_name text;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select id into v_account_id
  from public.accounts
  where upper(invite_code) = upper(trim(p_code))
    and account_type = 'group'
  limit 1;

  if v_account_id is null then
    raise exception 'Invalid invite code';
  end if;

  -- Already a member of this group
  select id into v_existing_member_id
  from public.members
  where account_id = v_account_id and user_id = v_uid
  limit 1;

  if v_existing_member_id is not null then
    return v_account_id;
  end if;

  -- Claim an unclaimed member slot if specified
  if p_member_id is not null then
    update public.members
    set user_id = v_uid
    where id = p_member_id
      and account_id = v_account_id
      and user_id is null;

    if found then
      return v_account_id;
    end if;
  end if;

  select coalesce(nullif(trim(p_display_name), ''), p.display_name, 'Member')
  into v_fallback_name
  from public.profiles p
  where p.id = v_uid;

  insert into public.members (account_id, user_id, name, is_active)
  values (v_account_id, v_uid, coalesce(v_fallback_name, 'Member'), true);

  return v_account_id;
end;
$$;

-- Table, Sequence & RPC Privileges for authenticated users (RLS enforces row-level access)
grant usage on schema public to authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on
  public.accounts,
  public.members,
  public.cycles,
  public.expenses,
  public.expense_splits,
  public.settlement_transfers
to authenticated;

grant usage, select on all sequences in schema public to authenticated;

grant execute on function public.is_account_member(uuid) to authenticated;
grant execute on function public.preview_group_by_invite_code(text) to authenticated;
grant execute on function public.join_group_by_invite_code(text, uuid, text) to authenticated;

-- Enable Realtime for instant multi-device updates (safe to re-run)
do $$
declare
  t text;
begin
  foreach t in array array[
    'accounts',
    'members',
    'cycles',
    'expenses',
    'expense_splits',
    'settlement_transfers'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;
