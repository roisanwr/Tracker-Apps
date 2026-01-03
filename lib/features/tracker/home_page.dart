import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Tracker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Koneksi Supabase Berhasil!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print("Tombol ditekan"); 
              },
              child: const Text('Tes Koneksi'),
            ),
          ],
        ),
      ),
    );
  }
}