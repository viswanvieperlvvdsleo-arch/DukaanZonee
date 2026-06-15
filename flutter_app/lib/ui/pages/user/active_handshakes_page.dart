import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class ActiveHandshakesPage extends StatelessWidget {
  const ActiveHandshakesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text('Active Handshakes', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const Kicker('READY FOR PICKUP'),
          const SizedBox(height: 16),
          _buildTokenCard(context, 'Pooja General Store', 'Fresh Organic Bananas (Dozen)', '₹60.00', '10 mins ago'),
          const SizedBox(height: 16),
          _buildTokenCard(context, 'Tech Haven', 'Noise Cancelling Earbuds', '₹12,499.00', '2 hours ago'),
        ],
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context, String shop, String item, String price, String time) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(shop, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: primary)),
              Text(time, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Icon(Icons.qr_code_2, size: 120, color: ink),
                const SizedBox(height: 12),
                const Text('Show this code to the merchant', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
