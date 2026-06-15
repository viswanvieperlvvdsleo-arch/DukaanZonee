import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    {'q': 'How do I use a Pickup Token?', 'a': 'Show the QR code to the merchant at the shop. They will scan it to complete the transaction.', 'c': 'Scanner'},
    {'q': 'What happens if a handshake fails?', 'a': 'If the scan fails, the merchant can manually enter the 6-digit code listed below your QR token.', 'c': 'Scanner'},
    {'q': 'How do I cancel an order?', 'a': 'Orders can be cancelled before the merchant prepares them from your Active Handshakes page.', 'c': 'Orders'},
    {'q': 'Is my payment secure?', 'a': 'Yes, we use industry-standard encryption and RBI-compliant gateways.', 'c': 'Payments'},
    {'q': 'How to follow a shop?', 'a': 'Visit a merchant profile and click the "Follow" button to get restock alerts.', 'c': 'Features'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs.where((f) => 
      f['q']!.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      f['a']!.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text('Help Center', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How can we help?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search for articles...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            const Kicker('FREQUENTLY ASKED'),
            const SizedBox(height: 16),
            if (filteredFaqs.isEmpty) 
              const Center(child: Text('No results found.', style: TextStyle(color: muted)))
            else
              for (final faq in filteredFaqs) 
                _FaqTile(faq: faq),
            
            const SizedBox(height: 32),
            _buildContactSupport(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSupport() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.support_agent, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Still need help?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Our neighborhood experts are available 24/7.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => push(context, ReportIssuePage()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: primary),
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});
  final Map<String, String> faq;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: shadowSm),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(faq['q']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Text(faq['c']!, style: const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900)),
          childrenPadding: const EdgeInsets.all(16),
          expandedAlignment: Alignment.centerLeft,
          children: [
            Text(faq['a']!, style: const TextStyle(color: muted, height: 1.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
