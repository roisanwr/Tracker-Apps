import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../../../../core/theme/app_theme.dart'; // Pastikan path ini benar sesuai file tema kamu

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signUp() async {
    // 1. Validasi Input
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
      // 2. Tembak ke Supabase
      await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        // 3. LOGIC PENTING: Matikan Sesi (Logout)
        // Biar user gak langsung masuk, tapi harus login manual
        await _authService.signOut();

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
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.neonPink),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Critical Error: $e'), backgroundColor: AppTheme.neonPink),
        );
      }
    }

    setState(() => _isLoading = false);
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
              // Icon Fingerprint biar keren
              const Icon(Icons.fingerprint, size: 80, color: AppTheme.neonYellow),
              const SizedBox(height: 24),
              const Text(
                'REGISTRATION PROTOCOL',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.neonBlue,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 32),
              
              // Input Email
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 16),
              
              // Input Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Create Passcode',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              
              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Confirm Passcode',
                  prefixIcon: Icon(Icons.verified_user_outlined), // Icon checklist
                ),
              ),
              const SizedBox(height: 32),
              
              // Tombol Daftar
              _isLoading
                  ? const CircularProgressIndicator(color: AppTheme.neonBlue)
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonYellow, // Kuning biar beda sama Login
                          foregroundColor: Colors.black, // Teks hitam
                        ),
                        child: const Text('INITIALIZE REGISTRATION'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}