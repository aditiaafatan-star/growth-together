

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true); -- semua anggota yang login boleh lihat nama satu sama lain (buat atribusi "by Fatan")

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Auto-bikin baris profiles begitu ada user baru daftar (dari form Register)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)), new.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------
-- 2) TABEL: plants
-- Cuma 2 baris (Bougainvillea & Portulaca), status "current" di-update tiap ada growth_updates baru
-- ---------------------------------------------------------------------
create table if not exists public.plants (
  id text primary key, -- 'kertas' | 'krokot'
  name text not null,
  local_name text not null,
  description text,
  team text not null,
  current_stage text not null default 'seed',
  current_condition text not null default 'healthy',
  last_checked timestamptz,
  created_at timestamptz not null default now()
);

alter table public.plants enable row level security;

drop policy if exists "plants_select_all" on public.plants;
create policy "plants_select_all"
  on public.plants for select
  to anon, authenticated
  using (true); -- data tanaman boleh dilihat publik, gak perlu login

-- Catatan: sengaja TIDAK ada policy UPDATE untuk plants dari role authenticated.
-- Kolom current_stage/current_condition/last_checked cuma boleh berubah lewat
-- trigger sync_plant_status (security definer) di bawah, bukan langsung dari user.

-- Seed 2 tanamannya (aman dijalankan ulang — gak akan duplikat)
insert into public.plants (id, name, local_name, description, team)
values
  ('kertas', 'Bougainvillea', 'Bunga Kertas', 'Batang berkayu berduri dengan bract tipis menyerupai kertas.', 'Hafidh Jaim T.S · Feliza Nuril A. · Firzansyah Alsy R.'),
  ('krokot', 'Portulaca', 'Bunga Krokot', 'Tanaman sukulen menjalar rendah, bunga mekar tiap pagi.', 'Fatan Aditiansyah · Ghazy Alfi M. · Fadhil Muhammad A.')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 3) TABEL: growth_updates
-- Ini yang diisi tiap kali ada anggota nambah update monitoring
-- ---------------------------------------------------------------------
create table if not exists public.growth_updates (
  id uuid primary key default gen_random_uuid(),
  plant_id text not null references public.plants(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade, -- ke profiles (bukan auth.users) biar join buat nama "by ..." kedetek otomatis
  date date not null default current_date,
  stage text not null check (stage in ('seed','sprout','growing','mature','bloom')),
  condition text not null check (condition in ('healthy','attention','recovering','critical')),
  activity text not null,
  notes text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists growth_updates_plant_id_idx on public.growth_updates (plant_id);
create index if not exists growth_updates_created_at_idx on public.growth_updates (created_at desc);

alter table public.growth_updates enable row level security;

drop policy if exists "growth_updates_select_authenticated" on public.growth_updates;
create policy "growth_updates_select_authenticated"
  on public.growth_updates for select
  to authenticated
  using (true); -- semua anggota yang login boleh baca semua update

drop policy if exists "growth_updates_insert_own" on public.growth_updates;
create policy "growth_updates_insert_own"
  on public.growth_updates for insert
  to authenticated
  with check (auth.uid() = user_id); -- cuma bisa nambah update atas nama sendiri

drop policy if exists "growth_updates_update_own" on public.growth_updates;
create policy "growth_updates_update_own"
  on public.growth_updates for update
  to authenticated
  using (auth.uid() = user_id); -- cuma bisa edit update milik sendiri

drop policy if exists "growth_updates_delete_own" on public.growth_updates;
create policy "growth_updates_delete_own"
  on public.growth_updates for delete
  to authenticated
  using (auth.uid() = user_id); -- cuma bisa hapus update milik sendiri

-- Auto-update kolom updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists growth_updates_set_updated_at on public.growth_updates;
create trigger growth_updates_set_updated_at
  before update on public.growth_updates
  for each row execute procedure public.set_updated_at();

-- Auto-sync plants.current_stage / current_condition / last_checked
-- tiap kali ada growth_updates baru masuk (INSERT)
create or replace function public.sync_plant_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.plants
  set current_stage = new.stage,
      current_condition = new.condition,
      last_checked = new.created_at
  where id = new.plant_id;
  return new;
end;
$$;

drop trigger if exists on_growth_update_sync_plant on public.growth_updates;
create trigger on_growth_update_sync_plant
  after insert on public.growth_updates
  for each row execute procedure public.sync_plant_status();

-- ---------------------------------------------------------------------
-- 4) REALTIME
-- Wajib — tanpa ini, event INSERT/UPDATE/DELETE gak akan ke-broadcast ke browser lain
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.growth_updates;
alter publication supabase_realtime add table public.plants;

-- ---------------------------------------------------------------------
-- 5) STORAGE (opsional, buat foto — siap dipakai kalau nanti fitur upload ditambahkan)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('plant-photos', 'plant-photos', true)
on conflict (id) do nothing;

drop policy if exists "plant_photos_read_public" on storage.objects;
create policy "plant_photos_read_public"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'plant-photos');

drop policy if exists "plant_photos_upload_authenticated" on storage.objects;
create policy "plant_photos_upload_authenticated"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'plant-photos');

-- =====================================================================
-- SELESAI. Cek: Table Editor harus nunjukin 3 tabel (profiles, plants,
-- growth_updates) dan plants harus udah keisi 2 baris (kertas, krokot).
-- =====================================================================
-- =====================================================================
-- GROWTH TOGETHER — Supabase setup
-- Jalankan seluruh file ini di: Supabase Dashboard → SQL Editor → New query → Run
-- Aman dijalankan ulang (pakai IF NOT EXISTS / DROP POLICY IF EXISTS di beberapa bagian)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) TABEL: profiles
-- Nyambung 1-ke-1 ke auth.users (Supabase yang urus password, kita cuma nyimpen nama)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  created_at timestamptz not null default now()
);