-- =============================================================================
-- ⚡ SPARKY'S ULTIMATE LIFE RPG DATABASE (MASTERPIECE EDITION V2) ⚡
-- =============================================================================
-- Fitur Baru: Multi-Timezone Support (Timelord Architecture)
-- Status: Ready for Production (MVP)

-- ⚠️ PERINGATAN KERAS: 
-- Script ini akan MENGHAPUS (DROP) semua tabel lama. 
-- Pastikan backup data jika ini bukan instalasi pertama.

-- =============================================================================
-- 1. BERSIH-BERSIH AREA KERJA (RESET TOTAL)
-- =============================================================================

drop table if exists public.sets cascade;
drop table if exists public.workout_exercises cascade;
drop table if exists public.workouts cascade;
drop table if exists public.exercise_library cascade;
drop table if exists public.point_logs cascade;
drop table if exists public.rewards cascade;
drop table if exists public.tasks cascade;
drop table if exists public.task_library cascade;
drop table if exists public.profiles cascade;
drop table if exists public.level_rules cascade;
drop table if exists public.difficulty_scales cascade;
drop table if exists public.tier_rewards cascade;

-- Hapus Custom Types (Enums) agar bersih
drop type if exists public.user_role;
drop type if exists public.tier_enum;
drop type if exists public.scale_type_enum;
drop type if exists public.task_priority;
drop type if exists public.task_frequency;

-- =============================================================================
-- 2. ENUMS & CONFIG (ATURAN MAIN GAME)
-- =============================================================================

-- Membuat Tipe Data Kustom (Dropdown Wajib)
create type public.user_role as enum ('user', 'admin');
create type public.tier_enum as enum ('D', 'C', 'B', 'A', 'S', 'SS');
create type public.scale_type_enum as enum ('endurance', 'strength', 'power', 'static_hold', 'cardio_run');
create type public.task_priority as enum ('Low', 'Medium', 'High');
create type public.task_frequency as enum ('Daily', 'Weekly', 'OneTime');

-- A. Tabel Level Rules (HARDCORE CURVE)
-- Menyimpan syarat XP untuk setiap level
create table public.level_rules (
  level int primary key,
  min_xp int not null,
  title text
);

-- B. Tabel Tier Rewards (GAJI)
-- Menyimpan berapa XP & Poin yang didapat per Tier
create table public.tier_rewards (
  tier public.tier_enum primary key,
  xp_reward int not null,
  points_reward int not null
);

-- C. Tabel Difficulty Scales (KONTRAK KERJA)
-- Menyimpan target angka (reps/detik/meter) berdasarkan Tier & Jenis Latihan
create table public.difficulty_scales (
  scale_type public.scale_type_enum not null,
  tier public.tier_enum not null,
  target_value int not null, 
  primary key (scale_type, tier)
);

-- =============================================================================
-- 3. PROFIL USER & RPG STATS (UPDATED 🕰️)
-- =============================================================================

create table public.profiles (
  id uuid not null references auth.users(id) on delete cascade primary key,
  username text,
  full_name text,
  avatar_url text,
  role public.user_role default 'user',
  
  -- [NEW FEATURE] Timezone Support
  -- Menyimpan zona waktu user agar reset harian adil.
  -- Default 'Asia/Jakarta' (WIB). Frontend bisa update ini nanti.
  timezone text default 'Asia/Jakarta',
  
  -- RPG Stats
  level int default 1,
  current_xp int default 0,     -- XP Total (Hanya Naik)
  current_points int default 0, -- Uang (Bisa Minus/Bangkrut)
  
  -- Streak System
  streak_current int default 0,
  streak_max int default 0,
  last_active_date date,        -- Penanda aktif harian (buat cek bolos)
  
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Audit Trail (Buku Besar Keuangan & XP)
-- PENTING: Semua perubahan saldo & XP HARUS lewat tabel ini
create table public.point_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  xp_change int default 0,
  points_change int default 0,
  source_type text, -- 'workout', 'task', 'punishment', 'shop', 'streak_bonus'
  description text, -- Contoh: "Squat Tier B", "Skip Task High", "Daily Penalty"
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- =============================================================================
-- 4. GYM SYSTEM (WORKOUT)
-- =============================================================================

-- Menu Latihan
create table public.exercise_library (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  target_muscle text, 
  scale_type public.scale_type_enum not null, -- endurance/strength/power...
  measurement_unit text default 'reps',       -- reps/seconds/meters
  image_url text,
  is_archived boolean default false
);

-- Header Sesi Latihan
create table public.workouts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  started_at timestamp with time zone default timezone('utc'::text, now()),
  ended_at timestamp with time zone,
  status text default 'in_progress', -- 'in_progress' atau 'completed'
  total_xp_earned int default 0,
  total_points_earned int default 0
);

-- Detail Sesi (Gerakan apa aja)
create table public.workout_exercises (
  id uuid default gen_random_uuid() primary key,
  workout_id uuid references public.workouts(id) on delete cascade not null,
  exercise_id uuid references public.exercise_library(id) not null,
  notes text
);

-- Detail Set (Log Inti)
create table public.sets (
  id uuid default gen_random_uuid() primary key,
  workout_exercise_id uuid references public.workout_exercises(id) on delete cascade not null,
  set_number int not null,
  
  -- Data Pilihan User (Snapshot)
  tier public.tier_enum not null, 
  target_value int not null,      -- Target otomatis dari DB saat itu
  
  -- Realisasi
  completed_value int,            -- User berhasil berapa?
  weight_kg float default 0,      -- Beban tambahan (opsional)
  is_completed boolean default false
);

-- =============================================================================
-- 5. TASK SYSTEM (HABITS)
-- =============================================================================

-- Library (Template Ide Tugas buatan Admin)
create table public.task_library (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  category text not null, -- Intellect, Vitality, dll
  default_priority public.task_priority default 'Medium',
  default_frequency public.task_frequency default 'Daily',
  default_target_value int default 1,
  default_unit text default 'Checklist', 
  icon_emoji text -- Emoji visual 🧠
);

-- Tugas Aktif User
create table public.tasks (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  
  title text not null,
  category text not null,
  priority public.task_priority default 'Medium',
  frequency public.task_frequency default 'Daily',
  
  -- Target
  target_value int default 1,
  unit text default 'Checklist',
  
  -- Status Pengerjaan
  current_value int default 0, 
  is_completed boolean default false,
  last_completed_at timestamp with time zone,
  
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- =============================================================================
-- 6. SHOP (REWARDS)
-- =============================================================================

create table public.rewards (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  title text not null,
  price int not null,
  image_url text,
  is_redeemed boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- =============================================================================
-- 7. OTOMATISASI CERDAS (TRIGGERS & FUNCTIONS)
-- =============================================================================

-- A. Trigger: User Baru Register -> Buat Profile
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, full_name, role, timezone)
  values (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name', 
    'user',
    'Asia/Jakarta' -- Default WIB
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- B. Trigger: Ada Log Masuk -> Update Saldo & Cek Level Up
create or replace function public.process_game_stats()
returns trigger as $$
declare
  new_level int;
  current_lvl int;
  user_streak int;
begin
  -- 1. Ambil data user saat ini
  select level, streak_current into current_lvl, user_streak
  from public.profiles where id = new.user_id;

  -- 2. Update Saldo & XP
  -- Kita update last_active_date JIKA log ini memberikan XP positif (artinya user produktif)
  if new.xp_change > 0 then
    update public.profiles
    set 
      current_points = current_points + new.points_change,
      current_xp = current_xp + new.xp_change,
      last_active_date = CURRENT_DATE -- Server date OK untuk general activity stamp
    where id = new.user_id;
  else
    -- Kalau cuma pengurangan poin (hukuman), jangan update tanggal aktif
    update public.profiles
    set current_points = current_points + new.points_change
    where id = new.user_id;
  end if;

  -- 3. Cek Level Up (Otomatis)
  -- Hitung total XP baru, bandingkan dengan tabel rules
  select level into new_level 
  from public.level_rules 
  where min_xp <= (select current_xp from public.profiles where id = new.user_id)
  order by level desc limit 1;

  -- Jika level baru lebih tinggi, update!
  if new_level > current_lvl then
    update public.profiles set level = new_level where id = new.user_id;
  end if;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_log_added
  after insert on public.point_logs
  for each row execute procedure public.process_game_stats();


-- C. FUNCTION: PUNISHMENT & DAILY RESET (THE TIMELORD VERSION) 👮‍♂️🕰️
-- Fungsi ini akan dipanggil oleh CRON JOB
create or replace function public.handle_daily_reset()
returns void as $$
declare
  user_record record;
  task_record record;
  user_today date;
  user_yesterday date;
begin
  -- LOOP SEMUA USER
  for user_record in select id, last_active_date, streak_current, timezone from public.profiles
  loop
    
    -- 1. TENTUKAN WAKTU LOKAL USER
    -- Konversi waktu server (UTC) ke Timezone user
    user_today := (now() AT TIME ZONE coalesce(user_record.timezone, 'Asia/Jakarta'))::date;
    user_yesterday := user_today - 1;

    -- 2. CEK BOLOS (Full Skip Day)
    -- Jika terakhir aktif lebih lama dari kemarin (alias kemarin gak login)
    if user_record.last_active_date < user_yesterday then
       -- Reset Streak
       update public.profiles set streak_current = 0 where id = user_record.id;
       
       -- Denda Poin (Macro Punishment) -200
       insert into public.point_logs (user_id, xp_change, points_change, source_type, description)
       values (user_record.id, 0, -200, 'punishment', 'Full Skip Day Penalty 😭');
    
    -- Jika aktif kemarin (Streak Aman), tambahkan streak +1
    -- Logic: Hanya nambah kalau last_active == user_yesterday
    elsif user_record.last_active_date = user_yesterday then
       update public.profiles set streak_current = streak_current + 1 where id = user_record.id;
    end if;

    -- 3. CEK TUGAS TERTINGGAL (Micro Punishment)
    -- Cari tugas Daily yg High Priority & Belum Selesai
    for task_record in select title from public.tasks 
                       where user_id = user_record.id 
                       and priority = 'High' 
                       and frequency = 'Daily' 
                       and is_completed = false
    loop
       -- Denda -50 per task
       insert into public.point_logs (user_id, xp_change, points_change, source_type, description)
       values (user_record.id, 0, -50, 'punishment', 'Missed High Task: ' || task_record.title);
    end loop;
    
  end loop;

  -- 4. RESET STATUS TUGAS HARIAN
  -- Dilakukan secara global.
  -- Catatan: Idealnya ini dijalankan saat jam sepi (misal 04:00 WIB)
  update public.tasks 
  set is_completed = false, current_value = 0
  where frequency = 'Daily';

end;
$$ language plpgsql security definer;

-- =============================================================================
-- 8. SECURITY (RLS POLICIES)
-- =============================================================================
-- Mengaktifkan pengamanan data
alter table profiles enable row level security;
alter table point_logs enable row level security;
alter table exercise_library enable row level security;
alter table workouts enable row level security;
alter table workout_exercises enable row level security;
alter table sets enable row level security;
alter table task_library enable row level security;
alter table tasks enable row level security;
alter table rewards enable row level security;
alter table level_rules enable row level security;
alter table tier_rewards enable row level security;
alter table difficulty_scales enable row level security;

-- 1. Config Tables (User Cuma Boleh Baca)
create policy "Public read levels" on level_rules for select using (true);
create policy "Public read tiers" on tier_rewards for select using (true);
create policy "Public read scales" on difficulty_scales for select using (true);
create policy "Public read exercises" on exercise_library for select using (true);
create policy "Public read task lib" on task_library for select using (true);

-- 2. User Data (User cuma boleh akses punya sendiri)
create policy "User own profile" on profiles for select using (auth.uid() = id);
create policy "User own logs" on point_logs for select using (auth.uid() = user_id);
create policy "User own tasks" on tasks for all using (auth.uid() = user_id);
create policy "User own rewards" on rewards for all using (auth.uid() = user_id);
create policy "User own workouts" on workouts for all using (auth.uid() = user_id);

-- 3. Nested Policies (Untuk tabel anak)
create policy "User own we" on workout_exercises for all using (
  exists (select 1 from workouts where workouts.id = workout_exercises.workout_id and workouts.user_id = auth.uid())
);
create policy "User own sets" on sets for all using (
  exists (select 1 from workout_exercises join workouts on workouts.id = workout_exercises.workout_id where workout_exercises.id = sets.workout_exercise_id and workouts.user_id = auth.uid())
);

-- 4. Admin Privileges (Admin boleh edit Library)
create policy "Admin manage exercises" on exercise_library for all using (
  (select role from profiles where id = auth.uid()) = 'admin'
);
create policy "Admin manage task lib" on task_library for all using (
  (select role from profiles where id = auth.uid()) = 'admin'
);

-- Insert Policy untuk Log (Dibuka untuk MVP, nanti dikunci via Backend/RPC)
create policy "User insert logs" on point_logs for insert with check (auth.uid() = user_id);

-- =============================================================================
-- 9. SEED DATA (DATA AWAL BIAR DATABASE PINTAR)
-- =============================================================================

-- A. Level Rules (Hardcore: 3 Tahun Tamat)
insert into public.level_rules (level, min_xp, title) values 
(1, 0, 'Newbie'), (5, 2000, 'Beginner'), (10, 8000, 'Rookie'),          
(20, 30000, 'Dedicated'), (30, 100000, 'Elite'), (40, 250000, 'Master'), (50, 500000, 'Immortal');

-- B. Tier Rewards (Gaji Tetap)
insert into public.tier_rewards (tier, xp_reward, points_reward) values
('D', 25, 5), ('C', 50, 10), ('B', 75, 15), ('A', 100, 20), ('S', 150, 30), ('SS', 200, 50);

-- C. Difficulty Scales (Rumus Repetisi/Detik/Meter)
insert into public.difficulty_scales (scale_type, tier, target_value) values
-- Endurance (Rep Banyak)
('endurance', 'D', 15), ('endurance', 'C', 25), ('endurance', 'B', 50), ('endurance', 'A', 75), ('endurance', 'S', 100), ('endurance', 'SS', 150),
-- Strength (Rep Sedang)
('strength', 'D', 10), ('strength', 'C', 15), ('strength', 'B', 25), ('strength', 'A', 40), ('strength', 'S', 60), ('strength', 'SS', 80),
-- Power (Rep Dikit)
('power', 'D', 3), ('power', 'C', 5), ('power', 'B', 8), ('power', 'A', 12), ('power', 'S', 15), ('power', 'SS', 20),
-- Static (Detik)
('static_hold', 'D', 30), ('static_hold', 'C', 45), ('static_hold', 'B', 60), ('static_hold', 'A', 90), ('static_hold', 'S', 120), ('static_hold', 'SS', 180),
-- Cardio (Meter)
('cardio_run', 'D', 500), ('cardio_run', 'C', 1000), ('cardio_run', 'B', 3000), ('cardio_run', 'A', 5000), ('cardio_run', 'S', 10000), ('cardio_run', 'SS', 21000);

-- D. Exercise Library (Menu Awal)
insert into public.exercise_library (name, target_muscle, scale_type, measurement_unit) values
('Push Up', 'Chest', 'strength', 'reps'),
('Pull Up', 'Back', 'power', 'reps'),
('Squat', 'Legs', 'endurance', 'reps'),
('Plank', 'Core', 'static_hold', 'seconds'),
('Jogging', 'Cardio', 'cardio_run', 'meters'),
('Burpees', 'Full Body', 'strength', 'reps');

-- E. Task Library (Inspirasi Habits)
insert into public.task_library (title, category, default_priority, default_frequency, default_target_value, default_unit, icon_emoji) values
('Baca Buku', 'Intellect', 'Medium', 'Daily', 10, 'Halaman', '🧠'),
('Belajar Coding', 'Intellect', 'High', 'Daily', 60, 'Menit', '💻'),
('Minum Air 2L', 'Vitality', 'High', 'Daily', 1, 'Checklist', '💧'),
('Tidur 8 Jam', 'Vitality', 'High', 'Daily', 1, 'Checklist', '😴'),
('Nabung Harian', 'Wealth', 'Medium', 'Daily', 1, 'Checklist', '💰'),
('Latihan Bahasa', 'Charisma', 'Medium', 'Daily', 15, 'Menit', '🇬🇧');

-- =============================================================================
-- 10. (OPSIONAL) AKTIFKAN CRON JOB
-- =============================================================================
-- Jika extension pg_cron sudah aktif di Dashboard Supabase, hilangkan komen di bawah:

select cron.schedule(
  'daily-reset-job', -- Nama Job
  '0 21 * * *',      -- Jadwal (Jam 21:00 UTC = Jam 04:00 WIB)
  $$ select public.handle_daily_reset() $$ -- Perintah yang dijalankan
);