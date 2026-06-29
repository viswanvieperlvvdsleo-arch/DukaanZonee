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
        title: const Text(
          'Active Handshakes',
          style: TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const Kicker('READY FOR PICKUP'),
          const SizedBox(height: 16),
          _buildEmptyState(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Column(
        children: [
          Icon(Icons.qr_code_2, size: 64, color: muted.withOpacity(0.45)),
          const SizedBox(height: 14),
          const Text(
            'No active payment handshakes yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paid checkout tokens will appear here from backend payment sessions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
