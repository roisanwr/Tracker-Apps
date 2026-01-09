import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/auth/data/auth_repository.dart';
import 'package:workout_tracker/features/auth/presentation/register_page.dart';
// ✅ UPDATE 1: Mengambil arah tujuan yang BENAR dari File 2 (Dashboard)
import 'package:workout_tracker/features/dashboard/presentation/home_page.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthRepository _authRepository = AuthRepository();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ✅ STATE BARU: Untuk mengatur visibilitas password
  bool _obscurePassword = true;
  bool _isLoading = false;

  // ✅ UPDATE 2: Menggunakan LOGIC PINTER dari File 2
  // Kita ganti nama fungsinya jadi _signIn biar match sama UI di bawah, tapi isinya Logic File 2
  Future<void> _signIn() async {
    // A. Validasi Input (Dari File 2)
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identity (Email) & Passcode wajib diisi, Agent!'),
          backgroundColor: AppTheme.neonPink,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // B. Eksekusi Login
      await _authRepository.login(
        _emailController.text.trim(), // Email di-trim
        _passwordController.text, // Password JANGAN di-trim
      );

      if (mounted) {
        // C. Navigasi Anti-Balik (pushAndRemoveUntil dari File 2)
        // Ini memastikan user gak bisa 'Back' ke halaman login setelah masuk
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false, // Hapus jejak history sebelumnya
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.neonPink,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System Failure: $e'),
            backgroundColor: AppTheme.neonPink,
          ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ---------------------------------------------------------
    // BAGIAN UI (TAMPILAN) - UPDATED
    // ---------------------------------------------------------
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Logo / Header Futuristik
              const Icon(
                Icons.bolt_outlined,
                size: 100,
                color: AppTheme.neonBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                'SYSTEM LOGIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Access your neural training data',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 48),

              // 2. Input Email
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Identity (Email)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Input Password (DENGAN ICON MATA)
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword, // Menggunakan variable state
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Passcode',
                  prefixIcon: const Icon(Icons.lock_outline),
                  // ✅ UPDATE 3: Menambahkan Icon Mata
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
              const SizedBox(height: 32),

              // 4. Tombol Aksi (LEBIH RAPI & KONTRAS)
              _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.neonBlue))
                  : ElevatedButton(
                      onPressed: _signIn,
                      // ✅ UPDATE 4: Styling Tombol yang Lebih Bersih & Tegas
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            AppTheme.neonBlue, // Warna Solid biar Jelas
                        foregroundColor:
                            Colors.black, // Text Hitam biar kontras dgn Neon
                        elevation: 5, // Sedikit bayangan biar muncul
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'LOGIN TO SYSTEM',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 16,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              // 5. Link Register
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterPage()),
                  );
                },
                child: RichText(
                  text: const TextSpan(
                    text: "New User? ",
                    style: TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: "Create Identity",
                        style: TextStyle(
                          color: AppTheme.neonBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
