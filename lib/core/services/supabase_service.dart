import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Singleton pattern (biar cuma ada 1 koneksi di seluruh aplikasi)
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Getter buat client, biar kodingan lain tinggal panggil SupabaseService().client
  SupabaseClient get client => Supabase.instance.client;

  // Fungsi inisialisasi awal (dipanggil di main.dart)
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://xybczhxtbaegdmmasvcr.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5YmN6aHh0YmFlZ2RtbWFzdmNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0NDkyNjIsImV4cCI6MjA4MzAyNTI2Mn0.5FZ1_heSaRIw1lFajoGLSyvhZdPLzildknzfr2ZrR6A',
      // Tips: Nanti kalau mau pro, Key ini ditaruh di .env file, tapi hardcode dulu gpp
    );
  }

  // Helper buat ambil User ID yang sedang login
  String? get currentUserId => client.auth.currentUser?.id;

  // Helper buat cek apakah user sudah login
  bool get isAuthenticated => client.auth.currentUser != null;
}
