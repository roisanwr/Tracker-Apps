-- Menambahkan kolom 'notes' ke tabel 'workouts'
ALTER TABLE public.workouts 
ADD COLUMN IF NOT EXISTS notes text;

-- 1. Tambah kolom 'created_by' untuk menandai pemilik latihan
ALTER TABLE public.exercise_library 
ADD COLUMN IF NOT EXISTS created_by uuid references auth.users(id);

-- 2. Hapus Policy lama yang terlalu bebas/terlalu ketat
DROP POLICY IF EXISTS "Public read exercises" ON public.exercise_library;
DROP POLICY IF EXISTS "Admin manage exercises" ON public.exercise_library;

-- 3. Policy BARU: SELECT (Lihat)
-- User boleh lihat latihan yang (Public/Admin punya) ATAU (Punya dia sendiri)
CREATE POLICY "Read exercises" ON public.exercise_library
FOR SELECT USING (
  created_by IS NULL OR created_by = auth.uid()
);

-- 4. Policy BARU: INSERT (Buat)
-- User boleh nambah latihan, TAPI kolom 'created_by' wajib diisi ID dia sendiri.
CREATE POLICY "User create custom exercises" ON public.exercise_library
FOR INSERT WITH CHECK (
  auth.uid() = created_by
);

-- 5. Policy BARU: DELETE (Hapus)
-- User cuma boleh hapus latihan buatannya sendiri.
CREATE POLICY "User delete own exercises" ON public.exercise_library
FOR DELETE USING (
  auth.uid() = created_by
);

-- (Admin tetap butuh akses penuh, biasanya via dashboard Supabase langsung jadi service_role, tapi kalau mau via app:)
-- Tambahkan policy khusus admin jika nanti kamu bikin dashboard admin di app ini.

-- Tambah kolom untuk mencatat kapan terakhir reset terjadi
alter table public.profiles 
add column if not exists last_daily_reset date;
