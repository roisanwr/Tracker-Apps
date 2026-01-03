import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Login Function
  Future<AuthResponse> signIn({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      // Kita lempar errornya biar UI yang nentuin cara nampilinnya (Snackbar/Dialog)
      rethrow; 
    }
  }

  // Register Function
  Future<AuthResponse> signUp({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Logout Function (Bonus biar lengkap)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get Current User (Cek siapa yang login)
  User? get currentUser => _supabase.auth.currentUser;
}