import 'package:flutter/material.dart';

class AppTheme {
  // Palet Warna Cyberpunk
  static const Color background = Color(0xFF050A0E); // Hitam Kebiruan
  static const Color surface = Color(0xFF151A21); // Abu gelap buat Card
  static const Color neonBlue = Color(0xFF00F0FF); // Cyan Neon utama
  static const Color neonPink = Color(0xFFFF003C); // Pink Neon (Error/Accent)
  static const Color neonYellow = Color(0xFFFCEE09); // Kuning Cyber
  static const Color textWhite = Color(0xFFFAFAFA);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: neonBlue,
      
      // Kustomisasi Input Text (Kotak isian)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: neonBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Default gak ada garis
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: surface), 
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonBlue, width: 2), // Pas diklik nyala
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonPink),
        ),
      ),

      // Kustomisasi Tombol
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonBlue,
          foregroundColor: Colors.black, // Teks tombol hitam biar kontras
          elevation: 10,
          shadowColor: neonBlue.withOpacity(0.5), // Efek glowing
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}