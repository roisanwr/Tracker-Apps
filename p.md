lib/
├── 🧱 core/                     (HAL-HAL UMUM/PONDASI)
│   ├── constants/               # API Keys, String statis (misal: Text judul app)
│   ├── theme/                   # AppTheme, Warna, Font
│   ├── services/                # SupabaseClient (Biar main.dart bersih)
│   └── widgets/                 # Tombol/Card yang dipakai di banyak tempat
│
├── 📦 features/                 (FITUR UTAMA)
│   │
│   ├── 🔐 auth/                 # Login & Register
│   │   ├── data/                # AuthRepository (Urusan ke Supabase)
│   │   └── presentation/        # LoginPage, RegisterPage
│   │
│   ├── 🏠 dashboard/            # Halaman Depan
│   │   └── presentation/        # DashboardView, HomeNav (BottomBar)
│   │
│   ├── 🎮 gamification/         # (REFACTOR DARI SHOP) - RPG & Ekonomi
│   │   ├── data/                # ShopRepository (Beli barang, Fetch reward)
│   │   └── presentation/        # ShopView, LevelUpDialog
│   │
│   │── 🏋️ workout/             # (REFACTOR DARI TRACKER) - Latihan Fisik
│   │    ├── data/                # WorkoutRepository (Log latihan, List gerakan)
│   │    └── presentation/        # ActiveWorkoutPage, WorkoutHistoryPage
│   │
│   └── 🏋️ tasl/             # (REFACTOR DARI TRACKER) - Latihan Fisik
│       ├── data/                # WorkoutRepository (Log latihan, List gerakan)
│       └── presentation/        # ActiveWorkoutPage, WorkoutHistoryPage
│
│
├── app.dart                     # Isinya MaterialApp & Routing
└── main.dart                    # Entry point (Cuma inisialisasi awal)