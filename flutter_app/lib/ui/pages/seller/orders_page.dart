import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  int _selectedStatus = 0;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle(
          'Handshake Hub',
          'Manage backend checkout and payment handshakes.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildTab(0, 'Awaiting'),
              _buildTab(1, 'Ready'),
              _buildTab(2, 'Completed'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildEmptyOrderState(),
      ],
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _selectedStatus == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? Colors.white : muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrderState() {
    final title = _selectedStatus == 0
        ? 'No awaiting payment handshakes.'
        : _selectedStatus == 1
        ? 'No ready handshakes.'
        : 'No completed handshakes yet.';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: muted.withOpacity(0.45),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Backend checkout/payment sessions will appear here after users pay through DukaanZone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
