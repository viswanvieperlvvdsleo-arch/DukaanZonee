import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  int _selectedStatus = 0; // 0: Awaiting, 1: Ready, 2: Completed

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle('Handshake Hub', 'Manage your daily fulfillment operations.'),
        const SizedBox(height: 24),
        
        // Status Toggles
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

        if (_selectedStatus == 0) ...[
          _buildOrderTicket(context, 'ORD-001', 'Aryan Malhotra', 'Fresh Organic Bananas (Dozen) x2', '₹120.00', true),
          const SizedBox(height: 16),
          _buildOrderTicket(context, 'ORD-002', 'Priya Singh', 'Premium Mixed Greens Collection', '₹120.00', true),
        ] else if (_selectedStatus == 1) ...[
          _buildOrderTicket(context, 'ORD-003', 'Rohan Sharma', 'Noise Cancelling Earbuds', '₹12,499.00', false),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: muted.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No completed orders today.', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        ]
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

  Widget _buildOrderTicket(BuildContext context, String id, String name, String items, String amount, bool isAwaiting) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAwaiting ? Colors.orange.withOpacity(0.2) : success.withOpacity(0.2)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: primary)),
              Text(isAwaiting ? 'Needs Packing' : 'Ready for Pickup', style: TextStyle(color: isAwaiting ? Colors.orange : success, fontWeight: FontWeight.w800, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(items, style: const TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              if (isAwaiting)
                ElevatedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Ready!'))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Mark Ready'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Handshake Verified!'))),
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Verify Token'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
