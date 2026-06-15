import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AnalyticsDetailPage extends StatefulWidget {
  final String title;
  const AnalyticsDetailPage({super.key, required this.title});

  @override
  State<AnalyticsDetailPage> createState() => _AnalyticsDetailPageState();
}

class _AnalyticsDetailPageState extends State<AnalyticsDetailPage> {
  String _selectedTimeframe = 'Today';
  int _selectedBarIndex = 5; // Default to Saturday

  // Mock data for different timeframes
  final Map<String, Map<String, dynamic>> _mockData = {
    'Today': {
      'total': '₹1,450',
      'bars': [20.0, 35.0, 25.0, 50.0, 40.0, 85.0, 60.0],
      'dayValues': ['₹240', '₹410', '₹300', '₹620', '₹480', '₹1,450', '₹720'],
      'items': [
        {'name': 'Organic Fuji Apples', 'sold': '12kg', 'rate': '₹60/kg', 'profit': '₹480', 'trend': '+5%'},
        {'name': 'Whole Grain Bread', 'sold': '8 units', 'rate': '₹45/u', 'profit': '₹160', 'trend': '+2%'},
      ]
    },
    'This Week': {
      'total': '₹8,400',
      'bars': [45.0, 60.0, 55.0, 80.0, 65.0, 95.0, 75.0],
      'dayValues': ['₹920', '₹1,200', '₹1,100', '₹1,600', '₹1,300', '₹1,900', '₹1,500'],
      'items': [
        {'name': 'Organic Fuji Apples', 'sold': '54kg', 'rate': '₹60/kg', 'profit': '₹2,160', 'trend': '+12%'},
        {'name': 'Pure Buffalo Milk', 'sold': '42L', 'rate': '₹70/L', 'profit': '₹840', 'trend': '+15%'},
        {'name': 'Farm Fresh Eggs', 'sold': '12 doz', 'rate': '₹90/d', 'profit': '₹360', 'trend': '+4%'},
      ]
    },
    'This Month': {
      'total': '₹32,000',
      'bars': [30.0, 45.0, 40.0, 70.0, 55.0, 90.0, 65.0],
      'dayValues': ['₹4k', '₹6k', '₹5.5k', '₹9k', '₹7k', '₹12k', '₹8k'],
      'items': [
        {'name': 'Organic Fuji Apples', 'sold': '210kg', 'rate': '₹60/kg', 'profit': '₹8,400', 'trend': '+22%'},
        {'name': 'Whole Grain Bread', 'sold': '145 units', 'rate': '₹45/u', 'profit': '₹2,900', 'trend': '+18%'},
        {'name': 'Premium Earbuds', 'sold': '12 units', 'rate': '₹2,499/u', 'profit': '₹6,000', 'trend': '+10%'},
      ]
    },
    'Lifetime': {
      'total': '₹4.2L',
      'bars': [60.0, 75.0, 65.0, 95.0, 80.0, 100.0, 85.0],
      'dayValues': ['₹40k', '₹55k', '₹45k', '₹75k', '₹60k', '₹85k', '₹70k'],
      'items': [
        {'name': 'Organic Fuji Apples', 'sold': '1.2k kg', 'rate': '₹60/kg', 'profit': '₹48k', 'trend': '+45%'},
        {'name': 'Pure Buffalo Milk', 'sold': '850L', 'rate': '₹70/L', 'profit': '₹17k', 'trend': '+38%'},
      ]
    },
  };

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final data = _mockData[_selectedTimeframe]!;
    final displayValue = data['dayValues'][_selectedBarIndex];

    return AppPage(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(child: PageTitle(widget.title, 'Detailed performance and item-wise breakdown.')),
          ],
        ),
        const SizedBox(height: 32),

        // 1. Growth Velocity Graph
        const Kicker('GROWTH VELOCITY'),
        const SizedBox(height: 12),
        _buildGrowthChart(context, displayValue, data['bars']),
        const SizedBox(height: 32),

        // 2. Timeframe Selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterPill('Today'),
              const SizedBox(width: 8),
              _buildFilterPill('This Week'),
              const SizedBox(width: 8),
              _buildFilterPill('This Month'),
              const SizedBox(width: 8),
              _buildFilterPill('Lifetime'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 3. Item-wise Breakdown
        const Kicker('ITEM-WISE PERFORMANCE'),
        const SizedBox(height: 12),
        _buildItemBreakdown(context, data['items']),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildGrowthChart(BuildContext context, String total, List<double> bars) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ink, ink.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: ink.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedTimeframe == 'Today' ? 'Daily Pulse' : 'Period Performance', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(total, key: ValueKey(total), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const Icon(Icons.auto_graph, color: success, size: 32),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < bars.length; i++)
                _buildBar(bars[i], ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i], index: i),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, String label, {required int index}) {
    final bool highlight = _selectedBarIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedBarIndex = index),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 24,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: highlight 
                  ? [success, success.withOpacity(0.6)] 
                  : [Colors.white24, Colors.white10],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: highlight ? Border.all(color: Colors.white.withOpacity(0.3), width: 1) : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: highlight ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String text) {
    final bool active = _selectedTimeframe == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeframe = text;
          _selectedBarIndex = 5; // Reset to a highlighted day on switch
          _expandedIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? ink : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? ink : primary.withOpacity(0.1)),
          boxShadow: active ? [BoxShadow(color: ink.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : shadowSm,
        ),
        child: Text(
          text,
          style: TextStyle(color: active ? Colors.white : muted, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildItemBreakdown(BuildContext context, List<dynamic> items) {
    return Column(
      children: List.generate(items.length, (index) => _buildItemCard(context, items[index], index)),
    );
  }


  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item, int index) {
    final bool isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isExpanded ? primary.withOpacity(0.2) : primary.withOpacity(0.05)),
        boxShadow: shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.shopping_bag_outlined, color: primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          Row(
                            children: [
                              Text('Sold: ${item['sold']}', style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(width: 4, height: 4, decoration: const BoxDecoration(color: muted, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('Rate: ${item['rate']}', style: const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(item['profit'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: success)),
                        Text(item['trend'], style: const TextStyle(color: success, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: muted.withOpacity(0.5)),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1, indent: 20, endIndent: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => push(context, const SellerInventoryPage()),
                          icon: const Icon(Icons.inventory_2_outlined, size: 16),
                          label: const Text('View Product', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: BorderSide(color: primary.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => push(context, BuyerHistoryPage(productName: item['name'])),
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('View History', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}




