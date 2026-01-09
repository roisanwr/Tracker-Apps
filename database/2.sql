-- =============================================================================
-- ⚡ SPARKY'S ULTIMATE GLOBAL RESET SYSTEM ⚡
-- =============================================================================

-- 1. SIAPKAN KOLOM PENDUKUNG DI TABEL PROFILES 🛠️
-- Kita butuh tau timezone user dan kapan terakhir kali dia di-reset.
alter table public.profiles 
add column if not exists timezone text default 'Asia/Jakarta',
add column if not exists last_reset_date date default (CURRENT_DATE - 1);

-- 2. FUNCTION BARU: GLOBAL HOURLY RESET (THE SMART SWEEPER) 🌍👮‍♂️
-- Fungsi ini akan dijalankan setiap jam oleh Cron Job.
create or replace function public.handle_hourly_reset()
returns void as $$
declare
  user_record record;
  
  -- Variabel Waktu
  server_now timestamp;
  user_local_time timestamp;
  user_local_date date;
  
  -- Variabel Rapor (Streak)
  total_tasks int;
  completed_tasks int;
  completion_rate float;
  
begin
  server_now := now();

  -- LOOP SEMUA USER
  for user_record in select id, timezone, last_reset_date, streak_current, streak_max from public.profiles
  loop
    
    -- A. CEK WAKTU LOKAL USER 🕰️
    -- Konversi waktu server UTC ke Timezone User
    -- Jika timezone null/ngaco, fallback ke 'Asia/Jakarta'
    begin
      user_local_time := server_now at time zone (coalesce(user_record.timezone, 'Asia/Jakarta'));
    exception when others then
      user_local_time := server_now at time zone 'Asia/Jakarta';
    end;

    user_local_date := user_local_time::date;

    -- B. LOGIKA PINTAR: Apakah User ini sudah ganti hari DAN belum di-reset?
    -- Kita cek apakah tanggal lokal user LEBIH BESAR dari tanggal terakhir reset.
    if user_local_date > user_record.last_reset_date then
    
        -- === MULAI PROSES RESET UNTUK USER INI ===
        
        -- 1. HITUNG RAPOR HARIAN (Hardcore Mode 80%) 📊
        select count(*) into total_tasks 
        from public.tasks 
        where user_id = user_record.id 
        and frequency = 'Daily';

        select count(*) into completed_tasks 
        from public.tasks 
        where user_id = user_record.id 
        and frequency = 'Daily' 
        and is_completed = true;

        if total_tasks > 0 then
          completion_rate := (completed_tasks::float / total_tasks::float) * 100;
        else
          completion_rate := 0; 
        end if;

        -- 2. VONIS STREAK 🔥
        -- Syarat: Minimal 80% tugas selesai
        if completion_rate >= 80 then
           -- LULUS: Tambah Streak
           update public.profiles 
           set 
             streak_current = streak_current + 1,
             streak_max = greatest(streak_max, streak_current + 1)
           where id = user_record.id;
           
           -- Catat Log Bonus
           insert into public.point_logs (user_id, xp_change, points_change, source_type, description)
           values (user_record.id, 20, 5, 'streak_bonus', 'Streak maintained! (' || round(completion_rate::numeric, 1) || '%)');

        else
           -- GAGAL: Reset Streak (Kecuali kalau emang gak punya task sama sekali, kita ampuni)
           if total_tasks > 0 then
             update public.profiles set streak_current = 0 where id = user_record.id;
             
             -- Catat Log Hukuman
             insert into public.point_logs (user_id, xp_change, points_change, source_type, description)
             values (user_record.id, 0, 0, 'punishment', 'Streak lost. Only completed ' || round(completion_rate::numeric, 1) || '%');
           end if;
        end if;

        -- 3. RESET TUGAS HARIAN (Bersih-bersih) 🧹
        update public.tasks 
        set 
          is_completed = false, 
          current_value = 0,
          last_completed_at = null
        where user_id = user_record.id 
        and frequency = 'Daily';

        -- 4. TANDAI BAHWA HARI INI SUDAH DI-RESET ✅
        update public.profiles 
        set last_reset_date = user_local_date 
        where id = user_record.id;
        
    end if; -- End Check Ganti Hari

  end loop;
end;
$$ language plpgsql security definer;

-- 3. JADWALKAN CRON JOB (SETIAP JAM) ⏰
-- Hapus job lama biar gak bentrok
select cron.unschedule('daily-reset-job');

-- Buat Job Baru: Jalan Setiap Jam (Menit ke-0)
-- Syntax cron: '0 * * * *' artinya menit 0, setiap jam, setiap hari
select cron.schedule(
  'hourly-global-reset',
  '0 * * * *', 
  $$ select public.handle_hourly_reset() $$
);