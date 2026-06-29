import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle(
          'Neighbor Directory',
          'Community moderation and identity verification.',
        ),
        const SizedBox(height: 32),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search neighbors by phone or email...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Kicker('BACKEND DIRECTORY'),
        const SizedBox(height: 12),
        _buildEmptyState(
          context,
          'Use Enterprise Control > Accounts for live user accounts.',
          Icons.people_alt_outlined,
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
        borderRadius: BorderRadius.circular(24),
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
