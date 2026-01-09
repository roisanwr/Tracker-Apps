import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/auth/data/auth_repository.dart'; // ✅ Import Repository
import 'package:workout_tracker/core/theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ✅ Panggil Repository
  final AuthRepository _authRepository = AuthRepository();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _signUp() async {
    // 1. Validasi Input (TETAP)
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Protocol Missing: Email & Password required'),
          backgroundColor: AppTheme.neonPink,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Passcode Mismatch'),
          backgroundColor: AppTheme.neonPink,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Tembak via Repository ✅
      await _authRepository.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        // 3. Matikan Sesi (Logout) via Repository ✅
        await _authRepository.logout();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity Created. System requires manual login.'),
            backgroundColor: AppTheme.neonBlue,
            duration: Duration(seconds: 4),
          ),
        );

        // 4. Tendang balik ke halaman Login
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: AppTheme.neonPink),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Critical Error: $e'),
              backgroundColor: AppTheme.neonPink),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Identity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Fingerprint (TETAP)
              const Icon(Icons.fingerprint,
                  size: 80, color: AppTheme.neonYellow),
              const SizedBox(height: 24),
              const Text(
                'REGISTRATION PROTOCOL',
                style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.neonBlue,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Input Email (TETAP)
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 16),

              // Input Password (with visibility toggle)
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Create Passcode',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password (with visibility toggle)
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm Passcode',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Daftar (TETAP)
              _isLoading
                  ? const CircularProgressIndicator(color: AppTheme.neonBlue)
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonYellow,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          'REGISTRATION TO GAME',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
