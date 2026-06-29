import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle(
          'Listing Patrol',
          'Ensure inventory quality and safety globally.',
        ),
        const SizedBox(height: 32),
        const Kicker('LIVE LISTING MODERATION'),
        const SizedBox(height: 12),
        _buildEmptyState(
          context,
          'No backend listing reports yet. Product signals will appear here after reports or inventory alerts are created.',
          Icons.inventory_2_outlined,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Column(
        children: [
          Icon(icon, color: muted, size: 34),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
