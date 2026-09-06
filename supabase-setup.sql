-- =====================================================
-- GROWTH TOGETHER — Supabase setup
-- =====================================================

-- =====================================================
-- 1) TABEL: profiles
-- =====================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  email text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);

create policy "profiles_update_own" on public.profiles
  for update to authenticated using (auth.uid() = id);

-- trigger: bikin baris profile otomatis pas ada yang register
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, email)
  values (new.id, new.raw_user_meta_data->>'name', new.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- =====================================================
-- 2) TABEL: plants (2 baris tetap: kertas & krokot)
-- =====================================================
create table if not exists public.plants (
  id text primary key,
  name text not null,
  local_name text,
  description text,
  team text,
  current_stage text,
  current_condition text,
  last_checked timestamptz,
  created_at timestamptz not null default now()
);

alter table public.plants enable row level security;

create policy "plants_select_authenticated" on public.plants
  for select to authenticated using (true);
-- sengaja TIDAK ada insert/update/delete policy untuk client -- cuma trigger sync_plant_status yang boleh nulis

insert into public.plants (id, name, local_name, team)
values
  ('kertas', 'Bougainvillea', 'Bunga Kertas', 'Hafidh Jaim T.S, Feliza Nuril A., Firzansyah Alsy R.'),
  ('krokot', 'Portulaca', 'Bunga Krokot', 'Fatan Aditiansyah, Ghazy Alfi M., Fadhil Muhammad A.')
on conflict (id) do nothing;

-- =====================================================
-- 3) TABEL: growth_updates (log monitoring)
-- =====================================================
create table if not exists public.growth_updates (
  id uuid primary key default gen_random_uuid(),
  plant_id text not null references public.plants(id),
  user_id uuid not null references public.profiles(id) on delete cascade,
  date date not null,
  stage text not null check (stage in ('seed','sprout','growing','mature','bloom')),
  condition text not null check (condition in ('healthy','attention','recovering','critical')),
  activity text not null,
  notes text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.growth_updates enable row level security;

create policy "growth_updates_select_authenticated" on public.growth_updates
  for select to authenticated using (true);
create policy "growth_updates_insert_own" on public.growth_updates
  for insert to authenticated with check (auth.uid() = user_id);
create policy "growth_updates_update_own" on public.growth_updates
  for update to authenticated using (auth.uid() = user_id);
create policy "growth_updates_delete_own" on public.growth_updates
  for delete to authenticated using (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_growth_updates_updated on public.growth_updates;
create trigger on_growth_updates_updated
  before update on public.growth_updates
  for each row execute procedure public.set_updated_at();

-- trigger: sync plants.current_stage/current_condition tiap ada growth_updates baru
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

-- =====================================================
-- 4) REALTIME
-- =====================================================
alter publication supabase_realtime add table public.growth_updates;
alter publication supabase_realtime add table public.plants;

-- =====================================================
-- 5) STORAGE: bucket plant-photos (opsional, buat foto)
-- =====================================================
insert into storage.buckets (id, name, public)
values ('plant-photos', 'plant-photos', true)
on conflict (id) do nothing;

create policy "plant_photos_public_read" on storage.objects
  for select using (bucket_id = 'plant-photos');
create policy "plant_photos_authenticated_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'plant-photos');


-- =====================================================================
-- =====================================================================
-- FASE 3 MIGRATION — Gamifikasi (XP, Level, Streak, Missions, Leaderboard)
-- =====================================================================
-- CATATAN PENTING: bagian ini BELUM dijalankan ke database production.
-- Jalankan seluruh blok di bawah ini lewat Supabase SQL Editor kalian sendiri.
-- app.html & index.html sudah diupdate untuk memakai kolom/tabel/view ini secara
-- DEFENSIF -- kalau migrasi ini belum dijalankan, fitur gamifikasi di kedua file
-- itu akan diam-diam tidak tampil (gak error/crash), dan fitur monitoring utama
-- (tambah update, lihat status tanaman, journal) tetap berjalan normal seperti biasa.
-- =====================================================================

-- 6) Extend profiles dengan kolom gamifikasi
alter table public.profiles
  add column if not exists xp integer not null default 0,
  add column if not exists current_streak integer not null default 0,
  add column if not exists longest_streak integer not null default 0,
  add column if not exists last_activity_date date,
  add column if not exists onboarded_at timestamptz;

-- 7) Ledger XP -- satu-satunya tabel baru yang dibutuhkan
create table if not exists public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  source text not null check (source in ('update_base','observation','photo','streak_bonus')),
  amount integer not null,
  related_update_id uuid references public.growth_updates(id) on delete set null,
  event_date date not null,
  created_at timestamptz not null default now(),
  unique (user_id, source, event_date)
);

alter table public.xp_events enable row level security;
create policy "xp_events_select_authenticated" on public.xp_events
  for select to authenticated using (true);
-- sengaja TIDAK ada insert/update/delete policy untuk client -- cuma trigger di bawah yang boleh nulis

-- 8) Trigger pemberi XP + hitung streak, jalan otomatis tiap ada growth_updates baru
create or replace function public.award_xp_for_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_today date := (new.created_at)::date;
  v_prev_date date;
  v_prev_streak int;
  v_new_streak int;
begin
  insert into public.xp_events (user_id, source, amount, related_update_id, event_date)
  values (new.user_id, 'update_base', 10, new.id, v_today)
  on conflict (user_id, source, event_date) do nothing;

  if new.notes is not null and length(trim(new.notes)) > 0 then
    insert into public.xp_events (user_id, source, amount, related_update_id, event_date)
    values (new.user_id, 'observation', 5, new.id, v_today)
    on conflict (user_id, source, event_date) do nothing;
  end if;

  if new.photo_url is not null then
    insert into public.xp_events (user_id, source, amount, related_update_id, event_date)
    values (new.user_id, 'photo', 15, new.id, v_today)
    on conflict (user_id, source, event_date) do nothing;
  end if;

  select last_activity_date, current_streak into v_prev_date, v_prev_streak
  from public.profiles where id = new.user_id;

  if v_prev_date = v_today then
    v_new_streak := v_prev_streak;
  elsif v_prev_date = v_today - 1 then
    v_new_streak := v_prev_streak + 1;
    insert into public.xp_events (user_id, source, amount, related_update_id, event_date)
    values (new.user_id, 'streak_bonus', 5, new.id, v_today)
    on conflict (user_id, source, event_date) do nothing;
  else
    v_new_streak := 1;
  end if;

  update public.profiles
  set xp = (select coalesce(sum(amount),0) from public.xp_events where user_id = new.user_id),
      current_streak = v_new_streak,
      longest_streak = greatest(longest_streak, v_new_streak),
      last_activity_date = v_today
  where id = new.user_id;

  return new;
end;
$$;

drop trigger if exists on_growth_update_award_xp on public.growth_updates;
create trigger on_growth_update_award_xp
  after insert on public.growth_updates
  for each row execute procedure public.award_xp_for_update();

-- 9) Leaderboard -- view saja, bukan tabel baru
create or replace view public.leaderboard as
select id, name, xp, current_streak,
       row_number() over (order by xp desc, name asc) as rank
from public.profiles;

-- =====================================================================
-- CATATAN KEAMANAN: kolom xp/current_streak/longest_streak/last_activity_date
-- di atas SENGAJA tidak dibatasi lewat RLS terpisah untuk versi awal ini --
-- policy profiles_update_own yang sudah ada (poin 1) masih izinin user update
-- baris profil sendiri. Untuk keamanan penuh (mencegah user mengubah xp-nya
-- sendiri lewat browser console), bisa ditambahkan trigger proteksi kolom
-- terpisah nanti -- didiskusikan dulu sebelum diterapkan, supaya tidak
-- menambah kompleksitas yang belum tentu dibutuhkan untuk kelompok kecil ini.
-- =====================================================================
