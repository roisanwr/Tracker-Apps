import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AuthRepository {
  // Kita ambil client dari SupabaseService yang sudah kita buat di Fase 1
  final SupabaseClient _supabase = SupabaseService().client;

  // 🔐 LOGIN
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw e.message; // Error dari Supabase (misal: Wrong Password)
    } catch (e) {
      throw 'Terjadi kesalahan sistem: $e';
    }
  }

  // 📝 REGISTER
  Future<AuthResponse> register(String email, String password) async {
    try {
      // CUKUP SIGN UP SAJA!
      // Trigger SQL 'handle_new_user' kamu otomatis membuat baris di tabel 'profiles'
      // dan memberikan modal awal (Level 1, Streak 0, dll). Enak kan?
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Gagal mendaftar: $e';
    }
  }

  // 🚪 LOGOUT
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // 🕵️‍♂️ CEK USER SAAT INI
  User? get currentUser => _supabase.auth.currentUser;

  // Cek apakah token masih valid
  bool get isAuthenticated => _supabase.auth.currentSession != null;
}
