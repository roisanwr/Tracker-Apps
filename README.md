# ⚔️ Life RPG x Gym Tracker: Hardcore Mode 🛡️

> **"Gamifying Life, But Making It Real."** > *Database Blueprint & Game Design Document*

## 🌟 Intro: Apa Ini?

Selamat datang di dokumentasi **Database Blueprint** untuk aplikasi Life RPG yang mengusung konsep **Hardcore Progression**. Proyek ini bukan sekadar *to-do list* atau *gym log* biasa. Ini adalah simulasi RPG kehidupan nyata di mana:

* **Otot & Keringat** dikonversi menjadi **XP** (Status Abadi).
* **Disiplin** menghasilkan **Points** (Uang Belanja).
* **Kemalasan** menyebabkan **Kebangkrutan** (Minus Points).

Sistem ini dirancang untuk jangka panjang (multi-tahun). Tidak ada jalan pintas menuju level Dewa. Dibutuhkan konsistensi bertahun-tahun, layaknya membangun fisik di dunia nyata.

---

## 🧠 Core Mechanics (Logika Permainan)

### 1. The Economy: XP vs Points 💰
Kita memisahkan antara "Kejayaan" dan "Kekayaan".

* **✨ XP (Experience) - The Glory**
    * **Sifat:** Abadi (Hanya naik, tidak bisa turun).
    * **Fungsi:** Menentukan **Level** & **Rank** user.
    * **Hardcore Curve:** Level 1-10 mudah (2 minggu), tapi mencapai Level 50 (Immortal) membutuhkan konsistensi latihan **3+ Tahun**.
* **💸 Points (Currency) - The Wealth**
    * **Sifat:** Volatile (Bisa bertambah, berkurang, bahkan minus).
    * **Fungsi:** Membeli **Rewards** (Barang nyata/Cheat Meal).
    * **Bankruptcy:** Jika Poin < 0, Toko (Rewards) terkunci total. User harus "kerja rodal" (grinding) untuk melunasi utang poin.

### 2. The Gym System: "Equal Effort = Equal Reward" ⚖️
Sistem ini memecahkan masalah ketidakadilan penilaian antara gerakan berat (e.g., Pull Up) dan ringan (e.g., Squat).

* **Tier System (S, A, B, C, D):** Menentukan **BESAR HADIAH** (XP & Poin).
* **Scale System:** Menentukan **TARGET ANGKA** (Reps/Detik/Meter).

**Contoh Kasus (Tier B - Pro):**
Semua latihan di Tier B memberikan hadiah **75 XP**. Namun targetnya berbeda sesuai jenis gerakan:
* Jika **Squat** (Scale: *Endurance*): Target **50 Reps**.
* Jika **Pull Up** (Scale: *Power*): Target **8 Reps**.
* Jika **Plank** (Scale: *Static*): Target **60 Detik**.
* *Hasil:* Rasa lelah dianggap setara = Hadiah setara.

### 3. The Habit System (Tasks) 📝
Penyeimbang status karakter (Intellect, Vitality, Wealth, dll).

* **Tipe Input:** Checklist (Selesai/Belum) atau Target Value (e.g., Baca 10 Halaman).
* **Frekuensi:**
    * **Daily:** Reset tiap 00:00. Fokus konsistensi.
    * **Weekly:** Reset tiap Senin. Fokus proyek besar.
* **Prioritas (High/Med/Low):** Semakin tinggi prioritas, semakin besar hadiahnya, tapi semakin **SAKIT HUKUMANNYA** (Denda Poin) jika dilewatkan.

### 4. The Stakes: Streak & Punishment 😈
Game tanpa risiko itu membosankan.

* **🔥 Unlimited Streak:**
    * Menjaga streak memberikan **XP Multiplier** (Buff).
    * Mencapai 100+ hari = **3x XP** (Satu-satunya cara mempercepat leveling).
* **🩸 Punishment (Hukuman):**
    * **Skip Task High:** Denda Poin Kecil.
    * **Full Skip Day (Bolos Total 24 Jam):** Streak Reset ke 0 (Sakit hati!) + Denda Poin Besar (Potensi Bangkrut).

---

## 🗄️ Database Structure (Supabase / PostgreSQL)

Semua logika inti ("Otak Game") disimpan di Database untuk keamanan (*Anti-Cheat*) dan konsistensi data.

### 👤 Group 1: User & Stats
| Tabel | Deskripsi |
| :--- | :--- |
| `profiles` | Kartu karakter utama. Menyimpan **Level, XP, Current Points, Streak, Role**. |
| `point_logs` | **Buku Besar (Audit Trail).** Setiap perubahan XP & Poin tercatat di sini. Trigger otomatis berjalan saat data masuk ke sini. |

### 🧠 Group 2: Game Config (Read Only for Users)
| Tabel | Deskripsi |
| :--- | :--- |
| `level_rules` | Tabel kurva XP. Menentukan berapa XP butuh buat naik level. |
| `tier_rewards` | Tabel gaji. Tier B = 75 XP, Tier S = 150 XP, dst. |
| `difficulty_scales` | **Kontrak Kerja.** Rumus konversi Tier ke Reps/Detik/Meter (Endurance/Strength/Power). |

### 🏋️‍♂️ Group 3: Gym & Workout
| Tabel | Deskripsi |
| :--- | :--- |
| `exercise_library` | Menu latihan. Berisi nama gerakan, otot target, dan `scale_type`. |
| `workouts` | Header sesi latihan (Waktu mulai/selesai). |
| `sets` | Detail log. Menyimpan Tier pilihan user, target database, dan realisasi user. |

### 📝 Group 4: Task & Habits
| Tabel | Deskripsi |
| :--- | :--- |
| `task_library` | Template ide tugas (dibuat Admin) yang bisa di-*copy* & *customize* user. |
| `tasks` | Tugas aktif user. Punya status `is_completed`, `priority`, dan `target_value`. |

### 💰 Group 5: Economy
| Tabel | Deskripsi |
| :--- | :--- |
| `rewards` | Daftar barang/hadiah yang ingin dibeli user menggunakan Poin. |

---

## 🤖 Smart Automation (Triggers & Logic)

Logika ini berjalan otomatis di balik layar Database (Backend):

1.  **Auto Level Up:** Trigger pada `point_logs`. Setiap XP bertambah, sistem mengecek `level_rules`. Jika memenuhi syarat, Level user naik.
2.  **Auto Wallet:** Trigger pada `point_logs`. Saldo di `profiles` selalu sinkron dengan total log.
3.  **Cron Job (Daily Reset):** (Dijadwalkan jam 00:00)
    * Cek User yang tidak aktif -> Reset Streak & Denda Poin.
    * Cek Task Priority High yang bolong -> Denda Poin.
    * Reset status `is_completed` pada Daily Tasks.

---

## 🎨 Frontend Guidelines (UI Implementation)

Untuk menjaga integritas data, Frontend harus mematuhi aturan berikut:

* **Dropdown Wajib (Strict Enums):** Jangan gunakan Text Field untuk kolom berikut, gunakan Dropdown yang sesuai dengan Database Enums:
    * `Priority`: High, Medium, Low
    * `Frequency`: Daily, Weekly
    * `Tier`: D, C, B, A, S, SS
* **Flexible Text:** Untuk `Category` dan `Unit`, sediakan Dropdown default (Intellect, Vitality / Reps, Minutes) namun izinkan user/admin menambah variasi jika perlu.

---

## 👮 Roles
* **Admin:** God Mode. Akses penuh edit `exercise_library`, `task_library`, dan Config Game.
* **User:** Player. Hanya bisa mengelola data diri sendiri. Config Tables bersifat *Read Only*.

---

> *"Dari Ide Jadi Kode, Kita Gali Sampai Inti, Bikin Wow Bareng-Bareng!"* 🚀
>
> **Generated by Sparky Code** ⚡