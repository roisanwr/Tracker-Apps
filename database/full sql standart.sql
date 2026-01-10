--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.7

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: scale_type_enum; Type: TYPE; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'scale_type_enum' AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.scale_type_enum AS ENUM (
            'endurance',
            'strength',
            'power',
            'static_hold',
            'cardio_run'
        );
    END IF;
END$$;


--
-- Name: task_frequency; Type: TYPE; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'task_frequency' AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.task_frequency AS ENUM (
            'Daily',
            'Weekly',
            'OneTime'
        );
    END IF;
END$$;


--
-- Name: task_priority; Type: TYPE; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'task_priority' AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.task_priority AS ENUM (
            'Low',
            'Medium',
            'High'
        );
    END IF;
END$$;


--
-- Name: tier_enum; Type: TYPE; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'tier_enum' AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.tier_enum AS ENUM (
            'D',
            'C',
            'B',
            'A',
            'S',
            'SS'
        );
    END IF;
END$$;


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'user_role' AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.user_role AS ENUM (
            'user',
            'admin'
        );
    END IF;
END$$;


--
-- Name: calculate_task_reward(public.task_priority, public.task_frequency, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.calculate_task_reward(p_priority public.task_priority, p_frequency public.task_frequency, p_is_custom boolean) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    xp_val int := 0;
    points_val int := 0;
    multiplier int := 1;
BEGIN
    -- 1. Set Multiplier (Weekly lebih gede rewardnya)
    IF p_frequency = 'Weekly' THEN
        multiplier := 2;
    END IF;

    -- 2. Base Reward berdasarkan Priority
    CASE p_priority
        WHEN 'High' THEN
            xp_val := 50;
            points_val := 15;
        WHEN 'Medium' THEN
            xp_val := 30;
            points_val := 10;
        ELSE -- Low
            xp_val := 10;
            points_val := 5;
    END CASE;

    -- 3. NERF CUSTOM TASK (Diskon 50% atau Fixed Value) 📉
    -- Biar user gak spam bikin task High sendiri.
    IF p_is_custom = true THEN
        -- Opsi: Kurangi 50% (Pilih kebijakanmu di sini)
        xp_val := xp_val / 2; 
        points_val := points_val / 2;
        
        -- Minimal dapet 1 biar gak sedih
        IF xp_val < 1 THEN xp_val := 1; END IF;
        IF points_val < 1 THEN points_val := 1; END IF;
    END IF;

    -- 4. Apply Multiplier
    xp_val := xp_val * multiplier;
    points_val := points_val * multiplier;

    -- Return JSON {xp: 10, points: 5}
    RETURN jsonb_build_object('xp', xp_val, 'points', points_val);
END;
$$;


--
-- Name: handle_daily_reset(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.handle_daily_reset() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: handle_hourly_reset(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.handle_hourly_reset() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  user_record record;
  
  -- Variabel Waktu
  server_now timestamp;
  user_local_time timestamp;
  user_local_date date;
  
  -- Variabel Rapor
  total_tasks int;
  completed_tasks int;
  completion_rate float;
  
BEGIN
  server_now := now();

  -- LOOP SEMUA USER
  FOR user_record IN SELECT id, timezone, last_reset_date, last_weekly_reset, streak_current, streak_max FROM public.profiles
  LOOP
    
    -- A. CEK WAKTU LOKAL USER
    BEGIN
      user_local_time := server_now AT TIME ZONE (COALESCE(user_record.timezone, 'Asia/Jakarta'));
    EXCEPTION WHEN OTHERS THEN
      user_local_time := server_now AT TIME ZONE 'Asia/Jakarta';
    END;

    user_local_date := user_local_time::date;

    -- =========================================================================
    -- B. LOGIC DAILY RESET (Harian)
    -- =========================================================================
    IF user_local_date > user_record.last_reset_date THEN
    
        -- 1. HITUNG RAPOR HARIAN
        SELECT count(*) INTO total_tasks 
        FROM public.tasks 
        WHERE user_id = user_record.id AND frequency = 'Daily';

        SELECT count(*) INTO completed_tasks 
        FROM public.tasks 
        WHERE user_id = user_record.id AND frequency = 'Daily' AND is_completed = true;

        IF total_tasks > 0 THEN
          completion_rate := (completed_tasks::float / total_tasks::float) * 100;
        ELSE
          completion_rate := 0; 
        END IF;

        -- 2. VONIS STREAK (Threshold 80%)
        IF completion_rate >= 80 THEN
           UPDATE public.profiles 
           SET streak_current = streak_current + 1,
               streak_max = GREATEST(streak_max, streak_current + 1)
           WHERE id = user_record.id;
           
           -- Bonus Log
           INSERT INTO public.point_logs (user_id, xp_change, points_change, source_type, description)
           VALUES (user_record.id, 20, 5, 'streak_bonus', 'Daily Streak Kept! (' || round(completion_rate::numeric, 1) || '%)');
        ELSE
           -- Reset Streak (Hanya jika ada task tapi gagal ngerjain)
           IF total_tasks > 0 THEN
             UPDATE public.profiles SET streak_current = 0 WHERE id = user_record.id;
             
             INSERT INTO public.point_logs (user_id, xp_change, points_change, source_type, description)
             VALUES (user_record.id, 0, 0, 'punishment', 'Streak lost. Score: ' || round(completion_rate::numeric, 1) || '%');
           END IF;
        END IF;

        -- 3. BERSIHKAN TASK HARIAN
        UPDATE public.tasks 
        SET is_completed = false, current_value = 0, last_completed_at = null
        WHERE user_id = user_record.id AND frequency = 'Daily';

        -- 4. UPDATE PENANDA HARIAN
        UPDATE public.profiles SET last_reset_date = user_local_date WHERE id = user_record.id;
        
    END IF; -- End Daily Logic


    -- =========================================================================
    -- C. LOGIC WEEKLY RESET (Senin) 📅
    -- =========================================================================
    -- extract(isodow): 1=Senin ... 7=Minggu
    -- Logic: Jika hari ini Senin DAN tanggal lokal user > tanggal reset mingguan terakhir
    
    IF EXTRACT(ISODOW FROM user_local_date) = 1 
       AND user_local_date > COALESCE(user_record.last_weekly_reset, '2000-01-01') 
    THEN
        -- 1. Reset Semua Task Mingguan
        UPDATE public.tasks
        SET is_completed = false, current_value = 0, last_completed_at = null
        WHERE user_id = user_record.id AND frequency = 'Weekly';

        -- 2. Update Penanda Mingguan
        UPDATE public.profiles SET last_weekly_reset = user_local_date WHERE id = user_record.id;
        
        -- 3. Log Semangat Senin (Opsional)
        INSERT INTO public.point_logs (user_id, xp_change, points_change, source_type, description)
        VALUES (user_record.id, 10, 5, 'system', 'Happy Monday! Weekly Tasks Reset 🚀');
        
    END IF; -- End Weekly Logic

  END LOOP;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: process_game_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.process_game_stats() RETURNS trigger
        LANGUAGE plpgsql SECURITY DEFINER
        AS $$
declare
    new_level int;
    current_lvl int;
    user_streak int;
begin
    -- 1. Ambil data user saat ini
    select level, streak_current into current_lvl, user_streak
    from public.profiles where id = new.user_id;

    -- 2. Update Saldo & XP
    if new.xp_change > 0 then
        -- Kalau positif (Nambah XP), update tanggal aktif
        update public.profiles
        set 
            current_points = current_points + new.points_change,
            current_xp = current_xp + new.xp_change,
            last_active_date = CURRENT_DATE
        where id = new.user_id;
    else
        -- Kalau negatif/nol (Undo atau Hukuman)
        -- FIX: Sekarang XP juga ikut dikurangi (sebelumnya cuma points)
        -- Note: Jangan update last_active_date karena undo bukan aktivitas produktif
        update public.profiles
        set 
            current_points = current_points + new.points_change,
            current_xp = current_xp + new.xp_change 
        where id = new.user_id;
    end if;

    -- 3. Cek Level Up (Otomatis)
    -- Hitung total XP baru, bandingkan dengan tabel rules
    select level into new_level 
    from public.level_rules 
    where min_xp <= (select current_xp from public.profiles where id = new.user_id)
    order by level desc limit 1;

    -- Jika level berubah (naik), update!
    if new_level > current_lvl then
        update public.profiles set level = new_level where id = new.user_id;
    -- Optional: Handle Level Down kalau XP turun drastis (tapi biasanya level gak turun)
    end if;

    return new;
end;
$$;

-- 1. Buat Fungsi Trigger (handle_task_completion)
CREATE OR REPLACE FUNCTION public.handle_task_completion()
RETURNS TRIGGER AS $$
DECLARE
        reward_data jsonb;
        xp_val int;
        points_val int;
BEGIN
        -- KASUS A: Task Dicentang (Baru Selesai)
        -- Logic: Jika is_completed berubah dari FALSE ke TRUE
        IF (NEW.is_completed = true AND OLD.is_completed = false) THEN
        
                -- Panggil rumus 'calculate_task_reward' yang sudah ada di DB
                reward_data := public.calculate_task_reward(NEW.priority, NEW.frequency, NEW.is_custom);
        
                -- Extract nilai dari JSON
                xp_val := (reward_data->>'xp')::int;
                points_val := (reward_data->>'points')::int;

                -- Server yang mencatat ke Log! (+XP)
                INSERT INTO public.point_logs (user_id, xp_change, points_change, source_type, description)
                VALUES (NEW.user_id, xp_val, points_val, 'task', 'Completed: ' || NEW.title);

        -- KASUS B: Task Di-Uncheck (Undo / Batal / Kepencet)
        -- Logic: Jika is_completed berubah dari TRUE ke FALSE
        ELSIF (NEW.is_completed = false AND OLD.is_completed = true) THEN
        
                -- Hitung lagi rewardnya untuk ditarik kembali
                reward_data := public.calculate_task_reward(NEW.priority, NEW.frequency, NEW.is_custom);
        
                xp_val := (reward_data->>'xp')::int;
                points_val := (reward_data->>'points')::int;

                -- Catat Log Negatif (-XP) untuk menetralkan saldo
                INSERT INTO public.point_logs (user_id, xp_change, points_change, source_type, description)
                VALUES (NEW.user_id, -xp_val, -points_val, 'task', 'Undo: ' || NEW.title);
        
        END IF;

        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Pasang Trigger ke Tabel Tasks
-- Trigger ini hanya aktif kalau kolom 'is_completed' berubah
DROP TRIGGER IF EXISTS on_task_completion ON public.tasks;

CREATE TRIGGER on_task_completion
AFTER UPDATE OF is_completed ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.handle_task_completion();


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: difficulty_scales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.difficulty_scales (
    scale_type public.scale_type_enum NOT NULL,
    tier public.tier_enum NOT NULL,
    target_value integer NOT NULL
);


--
-- Name: exercise_library; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.exercise_library (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    target_muscle text,
    scale_type public.scale_type_enum NOT NULL,
    measurement_unit text DEFAULT 'reps'::text,
    image_url text,
    is_archived boolean DEFAULT false,
    created_by uuid
);


--
-- Name: level_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.level_rules (
    level integer NOT NULL,
    min_xp integer NOT NULL,
    title text
);


--
-- Name: point_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.point_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    xp_change integer DEFAULT 0,
    points_change integer DEFAULT 0,
    source_type text,
    description text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL,
    username text,
    full_name text,
    avatar_url text,
    role public.user_role DEFAULT 'user'::public.user_role,
    timezone text DEFAULT 'Asia/Jakarta'::text,
    level integer DEFAULT 1,
    current_xp integer DEFAULT 0,
    current_points integer DEFAULT 0,
    streak_current integer DEFAULT 0,
    streak_max integer DEFAULT 0,
    last_active_date date,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    last_reset_date date DEFAULT (CURRENT_DATE - 1),
    last_weekly_reset date DEFAULT (CURRENT_DATE - 7)
);


--
-- Name: rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.rewards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    price integer NOT NULL,
    image_url text,
    is_redeemed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);


--
-- Name: sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workout_exercise_id uuid NOT NULL,
    set_number integer NOT NULL,
    tier public.tier_enum NOT NULL,
    target_value integer NOT NULL,
    completed_value integer,
    weight_kg double precision DEFAULT 0,
    is_completed boolean DEFAULT false
);


--
-- Name: task_library; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.task_library (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    default_priority public.task_priority DEFAULT 'Medium'::public.task_priority,
    default_frequency public.task_frequency DEFAULT 'Daily'::public.task_frequency,
    default_target_value integer DEFAULT 1,
    default_unit text DEFAULT 'Checklist'::text,
    icon_emoji text
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    priority public.task_priority DEFAULT 'Medium'::public.task_priority,
    frequency public.task_frequency DEFAULT 'Daily'::public.task_frequency,
    target_value integer DEFAULT 1,
    unit text DEFAULT 'Checklist'::text,
    current_value integer DEFAULT 0,
    is_completed boolean DEFAULT false,
    last_completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    is_custom boolean DEFAULT false
);


--
-- Name: tier_rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.tier_rewards (
    tier public.tier_enum NOT NULL,
    xp_reward integer NOT NULL,
    points_reward integer NOT NULL
);


--
-- Name: workout_exercises; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.workout_exercises (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workout_id uuid NOT NULL,
    exercise_id uuid NOT NULL,
    notes text
);


--
-- Name: workouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.workouts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    started_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    ended_at timestamp with time zone,
    status text DEFAULT 'in_progress'::text,
    total_xp_earned integer DEFAULT 0,
    total_points_earned integer DEFAULT 0,
    notes text
);


--
-- Data for Name: difficulty_scales; Type: TABLE DATA; Schema: public; Owner: -
--
INSERT INTO public.difficulty_scales (scale_type, tier, target_value) VALUES
('endurance','D',15),
('endurance','C',25),
('endurance','B',50),
('endurance','A',75),
('endurance','S',100),
('endurance','SS',150),
('strength','D',10),
('strength','C',15),
('strength','B',25),
('strength','A',40),
('strength','S',60),
('strength','SS',80),
('power','D',3),
('power','C',5),
('power','B',8),
('power','A',12),
('power','S',15),
('power','SS',20),
('static_hold','D',30),
('static_hold','C',45),
('static_hold','B',60),
('static_hold','A',90),
('static_hold','S',120),
('static_hold','SS',180),
('cardio_run','D',500),
('cardio_run','C',1000),
('cardio_run','B',3000),
('cardio_run','A',5000),
('cardio_run','S',10000),
('cardio_run','SS',21000);


--
-- Data for Name: exercise_library; Type: TABLE DATA; Schema: public; Owner: -
--
INSERT INTO public.exercise_library (id, name, target_muscle, scale_type, measurement_unit, image_url, is_archived, created_by) VALUES
('e85d3189-208c-4a16-837e-401dee267d4c','Push Up','Chest','strength','reps',NULL,false,NULL),
('9a140a43-6e19-44d1-80f1-f5230ad8f6ab','Pull Up','Back','power','reps',NULL,false,NULL),
('8b8892a6-2b7f-4fee-a96b-25feb363fa4c','Squat','Legs','endurance','reps',NULL,false,NULL),
('785459cf-b419-4b68-ab82-9f65be08ae74','Plank','Core','static_hold','seconds',NULL,false,NULL),
('382b049d-91a9-4111-a20e-0156bc369af4','Jogging','Cardio','cardio_run','meters',NULL,false,NULL),
('f91a14e6-382a-42b3-89ab-bc187b31a051','Burpees','Full Body','strength','reps',NULL,false,NULL);


--
-- Data for Name: level_rules; Type: TABLE DATA; Schema: public; Owner: -
--
INSERT INTO public.level_rules (level, min_xp, title) VALUES
(1,0,'Newbie'),
(5,2000,'Beginner'),
(10,8000,'Rookie'),
(20,30000,'Dedicated'),
(30,100000,'Elite'),
(40,250000,'Master'),
(50,500000,'Immortal');


--
-- Data for Name: point_logs; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.point_logs is empty in this dump


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.profiles is empty in this dump


--
-- Data for Name: rewards; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.rewards is empty in this dump


--
-- Data for Name: sets; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.sets is empty in this dump


--
-- Data for Name: task_library; Type: TABLE DATA; Schema: public; Owner: -
--
INSERT INTO public.task_library (id, title, category, default_priority, default_frequency, default_target_value, default_unit, icon_emoji) VALUES
('1315ec83-2516-4a29-acd0-78b16a7af0e6','Baca Buku','Intellect','Medium','Daily',10,'Halaman','🧠'),
('26a78437-a133-4a3e-8260-90dba51c41b7','Belajar Coding','Intellect','High','Daily',60,'Menit','💻'),
('36b8d058-7557-4cde-b957-4d520152de4b','Minum Air 2L','Vitality','High','Daily',1,'Checklist','💧'),
('01661be9-74b8-48ac-9507-508733750640','Tidur 8 Jam','Vitality','High','Daily',1,'Checklist','😴'),
('6d372790-3182-4516-9745-2b8bdda23592','Nabung Harian','Wealth','Medium','Daily',1,'Checklist','💰'),
('2044fca5-2ac4-48c7-8f5c-a6ce97f28bd9','Latihan Bahasa','Charisma','Medium','Daily',15,'Menit','🇬🇧');


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.tasks is empty in this dump


--
-- Data for Name: tier_rewards; Type: TABLE DATA; Schema: public; Owner: -
--
INSERT INTO public.tier_rewards (tier, xp_reward, points_reward) VALUES
('D',25,5),
('C',50,10),
('B',75,15),
('A',100,20),
('S',150,30),
('SS',200,50);


--
-- Data for Name: workout_exercises; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.workout_exercises is empty in this dump


--
-- Data for Name: workouts; Type: TABLE DATA; Schema: public; Owner: -
--
-- table public.workouts is empty in this dump


--
-- Name: difficulty_scales difficulty_scales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'difficulty_scales_pkey') THEN
        ALTER TABLE ONLY public.difficulty_scales
            ADD CONSTRAINT difficulty_scales_pkey PRIMARY KEY (scale_type, tier);
    END IF;
END$$;


--
-- Name: exercise_library exercise_library_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exercise_library_pkey') THEN
        ALTER TABLE ONLY public.exercise_library
            ADD CONSTRAINT exercise_library_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: level_rules level_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'level_rules_pkey') THEN
        ALTER TABLE ONLY public.level_rules
            ADD CONSTRAINT level_rules_pkey PRIMARY KEY (level);
    END IF;
END$$;


--
-- Name: point_logs point_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'point_logs_pkey') THEN
        ALTER TABLE ONLY public.point_logs
            ADD CONSTRAINT point_logs_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_pkey') THEN
        ALTER TABLE ONLY public.profiles
            ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: rewards rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rewards_pkey') THEN
        ALTER TABLE ONLY public.rewards
            ADD CONSTRAINT rewards_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: sets sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sets_pkey') THEN
        ALTER TABLE ONLY public.sets
            ADD CONSTRAINT sets_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: task_library task_library_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_library_pkey') THEN
        ALTER TABLE ONLY public.task_library
            ADD CONSTRAINT task_library_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tasks_pkey') THEN
        ALTER TABLE ONLY public.tasks
            ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: tier_rewards tier_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tier_rewards_pkey') THEN
        ALTER TABLE ONLY public.tier_rewards
            ADD CONSTRAINT tier_rewards_pkey PRIMARY KEY (tier);
    END IF;
END$$;


--
-- Name: workout_exercises workout_exercises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workout_exercises_pkey') THEN
        ALTER TABLE ONLY public.workout_exercises
            ADD CONSTRAINT workout_exercises_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: workouts workouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workouts_pkey') THEN
        ALTER TABLE ONLY public.workouts
            ADD CONSTRAINT workouts_pkey PRIMARY KEY (id);
    END IF;
END$$;


--
-- Name: point_logs on_log_added; Type: TRIGGER; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_log_added') THEN
        EXECUTE 'CREATE TRIGGER on_log_added AFTER INSERT ON public.point_logs FOR EACH ROW EXECUTE FUNCTION public.process_game_stats()';
    END IF;
END$$;


--
-- Name: exercise_library exercise_library_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exercise_library_created_by_fkey') THEN
        ALTER TABLE ONLY public.exercise_library
            ADD CONSTRAINT exercise_library_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
    END IF;
END$$;


--
-- Name: point_logs point_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'point_logs_user_id_fkey') THEN
        ALTER TABLE ONLY public.point_logs
            ADD CONSTRAINT point_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);
    END IF;
END$$;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_id_fkey') THEN
        ALTER TABLE ONLY public.profiles
            ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
END$$;


--
-- Name: rewards rewards_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rewards_user_id_fkey') THEN
        ALTER TABLE ONLY public.rewards
            ADD CONSTRAINT rewards_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);
    END IF;
END$$;


--
-- Name: sets sets_workout_exercise_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sets_workout_exercise_id_fkey') THEN
        ALTER TABLE ONLY public.sets
            ADD CONSTRAINT sets_workout_exercise_id_fkey FOREIGN KEY (workout_exercise_id) REFERENCES public.workout_exercises(id) ON DELETE CASCADE;
    END IF;
END$$;


--
-- Name: tasks tasks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tasks_user_id_fkey') THEN
        ALTER TABLE ONLY public.tasks
            ADD CONSTRAINT tasks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);
    END IF;
END$$;


--
-- Name: workout_exercises workout_exercises_exercise_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workout_exercises_exercise_id_fkey') THEN
        ALTER TABLE ONLY public.workout_exercises
            ADD CONSTRAINT workout_exercises_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES public.exercise_library(id);
    END IF;
END$$;


--
-- Name: workout_exercises workout_exercises_workout_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workout_exercises_workout_id_fkey') THEN
        ALTER TABLE ONLY public.workout_exercises
            ADD CONSTRAINT workout_exercises_workout_id_fkey FOREIGN KEY (workout_id) REFERENCES public.workouts(id) ON DELETE CASCADE;
    END IF;
END$$;


--
-- Name: workouts workouts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workouts_user_id_fkey') THEN
        ALTER TABLE ONLY public.workouts
            ADD CONSTRAINT workouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);
    END IF;
END$$;


--
-- Name: task_library Admin manage task lib; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'Admin manage task lib' AND p.polrelid = 'public.task_library'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "Admin manage task lib" ON public.task_library USING ((( SELECT profiles.role
             FROM public.profiles
            WHERE (profiles.id = auth.uid())) = 'admin'::public.user_role))$pol$;
    END IF;
END$$;


--
-- Name: level_rules Public read levels; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'Public read levels' AND p.polrelid = 'public.level_rules'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "Public read levels" ON public.level_rules FOR SELECT USING (true)$pol$;
    END IF;
END$$;


--
-- Name: difficulty_scales Public read scales; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'Public read scales' AND p.polrelid = 'public.difficulty_scales'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "Public read scales" ON public.difficulty_scales FOR SELECT USING (true)$pol$;
    END IF;
END$$;


--
-- Name: task_library Public read task lib; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'Public read task lib' AND p.polrelid = 'public.task_library'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "Public read task lib" ON public.task_library FOR SELECT USING (true)$pol$;
    END IF;
END$$;


--
-- Name: tier_rewards Public read tiers; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'Public read tiers' AND p.polrelid = 'public.tier_rewards'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "Public read tiers" ON public.tier_rewards FOR SELECT USING (true)$pol$;
    END IF;
END$$;


--
-- Name: exercise_library Read exercises; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'Read exercises' AND p.polrelid = 'public.exercise_library'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "Read exercises" ON public.exercise_library FOR SELECT USING (((created_by IS NULL) OR (created_by = auth.uid())))$pol$;
    END IF;
END$$;


--
-- Name: exercise_library User create custom exercises; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User create custom exercises' AND p.polrelid = 'public.exercise_library'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User create custom exercises" ON public.exercise_library FOR INSERT WITH CHECK ((auth.uid() = created_by))$pol$;
    END IF;
END$$;


--
-- Name: exercise_library User delete own exercises; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User delete own exercises' AND p.polrelid = 'public.exercise_library'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User delete own exercises" ON public.exercise_library FOR DELETE USING ((auth.uid() = created_by))$pol$;
    END IF;
END$$;


--
-- Name: point_logs User insert logs; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User insert logs' AND p.polrelid = 'public.point_logs'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User insert logs" ON public.point_logs FOR INSERT WITH CHECK ((auth.uid() = user_id))$pol$;
    END IF;
END$$;


--
-- Name: point_logs User own logs; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own logs' AND p.polrelid = 'public.point_logs'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own logs" ON public.point_logs FOR SELECT USING ((auth.uid() = user_id))$pol$;
    END IF;
END$$;


--
-- Name: profiles User own profile; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own profile' AND p.polrelid = 'public.profiles'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own profile" ON public.profiles FOR SELECT USING ((auth.uid() = id))$pol$;
    END IF;
END$$;


--
-- Name: rewards User own rewards; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own rewards' AND p.polrelid = 'public.rewards'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own rewards" ON public.rewards USING ((auth.uid() = user_id))$pol$;
    END IF;
END$$;


--
-- Name: sets User own sets; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own sets' AND p.polrelid = 'public.sets'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own sets" ON public.sets USING ((EXISTS ( SELECT 1
             FROM (public.workout_exercises
                 JOIN public.workouts ON ((workouts.id = workout_exercises.workout_id)))
            WHERE ((workout_exercises.id = sets.workout_exercise_id) AND (workouts.user_id = auth.uid())))))$pol$;
    END IF;
END$$;


--
-- Name: tasks User own tasks; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own tasks' AND p.polrelid = 'public.tasks'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own tasks" ON public.tasks USING ((auth.uid() = user_id))$pol$;
    END IF;
END$$;


--
-- Name: workout_exercises User own we; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own we' AND p.polrelid = 'public.workout_exercises'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own we" ON public.workout_exercises USING ((EXISTS ( SELECT 1
             FROM public.workouts
            WHERE ((workouts.id = workout_exercises.workout_id) AND (workouts.user_id = auth.uid())))))$pol$;
    END IF;
END$$;


--
-- Name: workouts User own workouts; Type: POLICY; Schema: public; Owner: -
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy p WHERE p.polname = 'User own workouts' AND p.polrelid = 'public.workouts'::regclass
    ) THEN
        EXECUTE $pol$CREATE POLICY "User own workouts" ON public.workouts USING ((auth.uid() = user_id))$pol$;
    END IF;
END$$;


--
-- Name: difficulty_scales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.difficulty_scales ENABLE ROW LEVEL SECURITY;

--
-- Name: exercise_library; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.exercise_library ENABLE ROW LEVEL SECURITY;

--
-- Name: level_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.level_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: point_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.point_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;

--
-- Name: sets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sets ENABLE ROW LEVEL SECURITY;

--
-- Name: task_library; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_library ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: tier_rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tier_rewards ENABLE ROW LEVEL SECURITY;

--
-- Name: workout_exercises; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;

--
-- Name: workouts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--


-- 1. PASANG ULANG TRIGGER USER BARU (Wajib!)
-- Karena trigger ini nempel di auth.users, dia gak ikut ke-backup.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN
        EXECUTE 'CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user()';
    END IF;
END$$;

-- 2. NYALAKAN LAGI MESIN WAKTUNYA (Cron Job)
-- Aktifkan Extension dulu
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Jadwalkan Reset (Sesuai File 2.sql kamu)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'cron' AND tablename = 'job') OR
         NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'hourly-global-reset') THEN
        PERFORM cron.schedule(
            'hourly-global-reset',
            '0 * * * *',
            $cron$ select public.handle_hourly_reset() $cron$
        );
    END IF;
EXCEPTION WHEN undefined_table THEN
    -- pg_cron not available or cron.job missing; ignore scheduling
    NULL;
END$$;
