import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class BuyerHistoryPage extends StatelessWidget {
  final String productName;
  const BuyerHistoryPage({super.key, required this.productName});

  @override
  Widget build(BuildContext context) {
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
        _buildEmptyState(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: muted, size: 34),
          SizedBox(height: 12),
          Text(
            'Buyer history will appear here after backend payments are completed for this item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
