import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class BuyerHistoryPage extends StatelessWidget {
  final String productName;
  const BuyerHistoryPage({super.key, required this.productName});

  @override
  Widget build(BuildContext context) {
    // Mock data for buyers
    final List<Map<String, String>> buyers = [
      {'name': 'Aryan Malhotra', 'count': '5 times', 'last': '2 hours ago'},
      {'name': 'Priya Singh', 'count': '3 times', 'last': 'Yesterday'},
      {'name': 'Rahul Verma', 'count': '12 times', 'last': '3 days ago'},
      {'name': 'Sanya Khan', 'count': '2 times', 'last': '1 week ago'},
    ];

    return AppPage(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(child: PageTitle('Buyer History', productName)),
          ],
        ),
        const SizedBox(height: 32),

        const Kicker('LOYAL NEIGHBORS'),
        const SizedBox(height: 12),
        
        ...buyers.map((buyer) => _buildBuyerCard(buyer)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildBuyerCard(Map<String, String> buyer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text(buyer['name']![0], style: const TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 18))),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(buyer['name']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(productName, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(buyer['count']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ink)),
              Text('Last: ${buyer['last']}', style: const TextStyle(color: success, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
