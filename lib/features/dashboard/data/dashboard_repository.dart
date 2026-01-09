import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final SupabaseClient _supabase;

  // Constructor menerima client, kalau kosong pakai instance default
  DashboardRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Mengambil data Profile & Stats User dari Supabase
  /// Menggabungkan data dari tabel 'profiles' dan logika gamifikasi dasar
  Future<Map<String, dynamic>> fetchUserStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Ambil data profil dari tabel 'profiles' berdasarkan user_id
      final response =
          await _supabase.from('profiles').select().eq('id', user.id).single();

      // 2. Mapping data dari database ke format yang dipakai UI
      // Kalau kolom di DB null, kita kasih default value biar gak error
      return {
        'username': response['username'] ?? 'Unknown Agent',
        'level': response['level'] ?? 1,
        'current_xp': response['current_xp'] ?? 0,
        'max_xp': response['max_xp'] ??
            1000, // Logic max xp bisa dibikin dinamis nanti
        'class':
            response['character_class'] ?? 'Rookie', // Misal ada kolom class
        'avatar_url': response['avatar_url'],
      };
    } catch (e) {
      // Return default data jika gagal fetch (misal user baru belum ada row di profiles)
      return {
        'username': 'Agent',
        'level': 1,
        'current_xp': 0,
        'max_xp': 1000,
        'class': 'Trainee',
      };
    }
  }

  /// Mengambil data Atribut Fisik (Strength, Agility, dll)
  /// Ini biasanya disimpan di kolom JSONB atau tabel terpisah 'user_attributes'
  Future<Map<String, double>> fetchPhysicalAttributes() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return _defaultAttributes();

      // CONTOH: Mengambil dari tabel 'profiles' kolom 'attributes' (asumsi JSON)
      // Sesuaikan 'attributes' dengan nama kolom asli di DB-mu jika beda
      final response = await _supabase
          .from('profiles')
          .select('attributes')
          .eq('id', user.id)
          .single();

      if (response['attributes'] != null) {
        final Map<String, dynamic> data = response['attributes'];
        return {
          'Strength': (data['strength'] ?? 0).toDouble(),
          'Endurance': (data['endurance'] ?? 0).toDouble(),
          'Agility': (data['agility'] ?? 0).toDouble(),
          'Intelligence': (data['intelligence'] ?? 0).toDouble(),
          'Luck': (data['luck'] ?? 0).toDouble(),
        };
      }

      return _defaultAttributes();
    } catch (e) {
      return _defaultAttributes();
    }
  }

  Map<String, double> _defaultAttributes() {
    return {
      'Strength': 10,
      'Endurance': 10,
      'Agility': 10,
      'Intelligence': 10,
      'Luck': 5,
    };
  }
}
