import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';

class ShopView extends StatefulWidget {
  const ShopView({super.key});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  // 📡 STREAM: Ambil daftar Reward User
  Stream<List<Map<String, dynamic>>> _getRewardsStream() {
    return Supabase.instance.client
        .from('rewards')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('price', ascending: true); // Urutkan dari yang termurah
  }

  // 📡 STREAM: Ambil Saldo Poin User (Real-time)
  Stream<int> _getUserPointsStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId)
        .map((data) =>
            data.isNotEmpty ? data.first['current_points'] as int : 0);
  }

  // 🛍️ ACTION: Beli Reward (Redeem)
  Future<void> _redeemReward(
      Map<String, dynamic> reward, int currentBalance) async {
    final int price = reward['price'];
    final String title = reward['title'];

    if (currentBalance < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Not enough points! Grinding lagi yuk! 💪"),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Konfirmasi Pembelian
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Confirm Purchase",
            style: TextStyle(color: Colors.white)),
        content: Text("Spend $price CP for '$title'?",
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Buy", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Kurangi Poin di Profile & Catat Log (Trigger SQL akan handle update profile, tapi biar aman kita insert log aja)
      // Ingat: Trigger 'process_game_stats' kita di SQL akan otomatis update saldo profile kalau ada insert di point_logs!

      await Supabase.instance.client.from('point_logs').insert({
        'user_id': _userId,
        'xp_change': 0, // Belanja gak nambah XP
        'points_change': -price, // Kurangi poin (negatif)
        'source_type': 'shop',
        'description': 'Redeemed: $title',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Enjoy your $title! 🎉"),
              backgroundColor: AppTheme.secondaryColor),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ➕ ACTION: Tambah Item Baru ke Toko
  void _showAddRewardDialog() {
    final titleController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Create New Reward",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Reward Name (e.g. Pizza)",
                  labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Price (CP)",
                  labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (titleController.text.isEmpty || priceController.text.isEmpty)
                return;

              final title = titleController.text;
              final price = int.tryParse(priceController.text) ?? 0;

              if (price <= 0) return;

              Navigator.pop(ctx);

              await Supabase.instance.client.from('rewards').insert({
                'user_id': _userId,
                'title': title,
                'price': price,
                'image_url': '🎁', // Default emoji icon
              });
            },
            child: const Text("Create", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // 🗑️ ACTION: Hapus Item Toko
  void _deleteReward(String id) async {
    await Supabase.instance.client.from('rewards').delete().eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 1. HEADER DOMPET (WALLET)
          StreamBuilder<int>(
            stream: _getUserPointsStream(),
            builder: (context, snapshot) {
              final int balance = snapshot.data ?? 0;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1E1E),
                      Colors.black.withOpacity(0.0)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    const Text("AVAILABLE CREDITS",
                        style: TextStyle(
                            color: Colors.grey,
                            letterSpacing: 2,
                            fontSize: 10)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "$balance",
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 48,
                              fontWeight: FontWeight.bold),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0, left: 4),
                          child: Text("CP",
                              style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. RAK BARANG (GRID VIEW)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getRewardsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor));
                }

                final rewards = snapshot.data ?? [];

                if (rewards.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text("Shop is Empty",
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        const Text("Create rewards to motivate yourself!",
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _showAddRewardDialog,
                          icon: const Icon(Icons.add,
                              color: AppTheme.primaryColor),
                          label: const Text("Add First Item",
                              style: TextStyle(color: AppTheme.primaryColor)),
                        )
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 Kolom
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8, // Rasio kartu (agak tinggi)
                  ),
                  itemCount: rewards.length,
                  itemBuilder: (context, index) {
                    return _buildRewardCard(rewards[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // FAB Add Reward
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRewardDialog,
        backgroundColor: const Color(0xFFFFD700), // Emas
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    return StreamBuilder<int>(
      // Kita butuh balance lagi di sini buat ngecek (Enable/Disable tombol beli)
      stream: _getUserPointsStream(),
      builder: (context, snapshot) {
        final int balance = snapshot.data ?? 0;
        final int price = reward['price'];
        final bool canAfford = balance >= price;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canAfford
                  ? const Color(0xFFFFD700).withOpacity(0.3)
                  : Colors.white10,
              width: canAfford ? 1.5 : 1,
            ),
            boxShadow: canAfford
                ? [
                    BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon / Emoji
              const Expanded(
                child: Center(
                  child: Text("🎁", style: TextStyle(fontSize: 48)),
                ),
              ),

              // Title & Price
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  children: [
                    Text(
                      reward['title'],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$price CP",
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Button Area
              GestureDetector(
                onTap: canAfford ? () => _redeemReward(reward, balance) : null,
                onLongPress: () {
                  // Hapus item jika ditahan lama
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: const Text("Delete Reward?",
                                style: TextStyle(color: Colors.white)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel")),
                              TextButton(
                                  onPressed: () {
                                    _deleteReward(reward['id']);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        canAfford ? const Color(0xFFFFD700) : Colors.grey[800],
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                  child: Text(
                    canAfford ? "REDEEM" : "LOCKED",
                    style: TextStyle(
                      color: canAfford ? Colors.black : Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
