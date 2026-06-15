import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle('Listing Patrol', 'Ensure inventory quality and safety globally.'),
        const SizedBox(height: 32),

        const Kicker('FLAGGED LISTINGS (HIGH PRIORITY)'),
        const SizedBox(height: 12),
        _buildProductCard(context, 'Counterfeit Batteries', 'Tech Haven', 'Reported 12 times by neighbors.', true),

        const SizedBox(height: 32),
        const Kicker('HIGH VELOCITY LISTINGS'),
        const SizedBox(height: 12),
        _buildProductCard(context, 'Fresh Organic Bananas', 'Pooja General Store', 'Top seller in Block A.', false),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, String name, String shop, String note, bool flagged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: flagged ? Colors.redAccent.withOpacity(0.3) : primary.withOpacity(0.1)),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: flagged ? Colors.redAccent.withOpacity(0.1) : primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(flagged ? Icons.warning_amber : Icons.local_fire_department, color: flagged ? Colors.redAccent : Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text('By $shop', style: const TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          if (flagged)
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing Purged from network.'))),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Purge'),
            )
          else
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
              child: const Text('Audit'),
            ),
        ],
      ),
    );
  }
}
