import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle('Neighbor Directory', 'Community moderation and identity verification.'),
        const SizedBox(height: 32),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search neighbors by phone or email...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 32),

        const Kicker('HIGH TRUST NEIGHBORS'),
        const SizedBox(height: 12),
        _buildUserCard(context, 'Aryan Malhotra', 'aryan@example.com', 'Block A', 98, '₹12,450'),
        const SizedBox(height: 16),
        _buildUserCard(context, 'Priya Singh', 'priya@example.com', 'Block B', 85, '₹4,200'),
        
        const SizedBox(height: 32),
        const Kicker('FLAGGED ACCOUNTS'),
        const SizedBox(height: 12),
        _buildUserCard(context, 'Unknown User', 'anon@temp.com', 'Unverified', 12, '₹0', isFlagged: true),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, String name, String email, String block, int trust, String spend, {bool isFlagged = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isFlagged ? Colors.redAccent.withOpacity(0.3) : Colors.transparent),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: primary.withOpacity(0.1), child: const Icon(Icons.person, color: primary)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('$email • $block', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Lifetime Spend', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
                  Text(spend, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trust Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        Text('$trust/100', style: TextStyle(color: trust > 50 ? success : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: trust / 100,
                      backgroundColor: muted.withOpacity(0.1),
                      color: trust > 50 ? success : Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              IconButton(onPressed: () {}, icon: const Icon(Icons.history, color: primary)),
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFlagged ? 'Account Unbanned.' : 'Account Suspended.'))),
                icon: Icon(isFlagged ? Icons.lock_open : Icons.block, color: isFlagged ? success : Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
