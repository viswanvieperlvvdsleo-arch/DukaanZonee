import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'media_storage_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => AppPage(children: [
        PageTitle(title, subtitle),
        const SizedBox(height: 18),
        const SignalCard(title: 'Profile', body: 'Name, phone, block, and role information.', icon: Icons.person),
        const SignalCard(title: 'Notifications', body: 'Stock, order, and platform alert preferences.', icon: Icons.notifications),
        const SignalCard(title: 'Security', body: 'Password, OTP and admin access rules.', icon: Icons.lock),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => push(context, const MediaStorageSettingsPage()),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: shadowSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storage_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Storage Management', style: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Manage media files — images, videos, voice & docs', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
          ),
        ),
      ]);
}

