import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class TermsPrivacyPage extends StatelessWidget {
  const TermsPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text('Terms & Privacy', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Privacy at a Glance', 'We value your trust'),
            const SizedBox(height: 24),
            _buildPrivacyGrid(),
            const SizedBox(height: 48),
            const SectionHeader('Detailed Policies', 'The legal stuff'),
            const SizedBox(height: 16),
            _buildPolicyTile('Terms of Service', 'Rules for using DukaanZone'),
            _buildPolicyTile('Privacy Policy', 'How we handle your data'),
            _buildPolicyTile('Refund & Returns', 'Buyer protection policies'),
            _buildPolicyTile('Cookie Policy', 'Browser storage usage'),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyGrid() {
    return Column(
      children: [
        _PrivacyCard(Icons.security, 'Data Protection', 'Your data is encrypted and never sold to third parties.'),
        _PrivacyCard(Icons.location_off_outlined, 'Private Location', 'Location is only used to find nearby shops, never tracked in background.'),
        _PrivacyCard(Icons.payments_outlined, 'Secure Payments', 'Transactions are processed via RBI-compliant encrypted gateways.'),
      ],
    );
  }

  Widget _buildPolicyTile(String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: muted),
      onTap: () {},
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard(this.icon, this.title, this.desc);
  final IconData icon;
  final String title, desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: shadowSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
