import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerRevenuePage extends StatelessWidget {
  const SellerRevenuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle('Ledger Intelligence', 'Analyze your financial growth & trends.'),
        const SizedBox(height: 32),
        
        const Kicker('GROWTH VELOCITY'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: neonGlow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This Week', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 4),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹24,500', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('+14% vs last week', style: TextStyle(color: success, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Simulated Area Chart
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var h in [20, 35, 25, 50, 40, 70, 60])
                    Container(
                      width: 30,
                      height: h.toDouble(),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [primary, Color(0xFF3B82F6)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mon', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text('Sun', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        const Kicker('AI FORECAST & INTELLIGENCE'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.purple, size: 32),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Warning: Bananas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('Based on local demand, you will run out of bananas in 2 days. Consider restocking.', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        const Kicker('SKU INTELLIGENCE (TOP SELLERS)'),
        const SizedBox(height: 12),
        _buildSkuRow(context, '1', 'Noise Cancelling Earbuds', '₹12,499', 'High Margin'),
        const SizedBox(height: 12),
        _buildSkuRow(context, '2', 'Fresh Organic Bananas', '₹60', 'High Volume'),
      ],
    );
  }

  Widget _buildSkuRow(BuildContext context, String rank, String name, String rev, String tag) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          Text('#$rank', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(tag, style: const TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Text(rev, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}
