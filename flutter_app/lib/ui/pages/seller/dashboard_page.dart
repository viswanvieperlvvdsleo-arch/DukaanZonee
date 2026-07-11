import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'seller_metric_analytics_page.dart';
import 'offline_scanner_page.dart';

class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({super.key});

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  bool _isOnline = true;
  late final PageController _aiPageController;
  int _currentAIIndex = 0;
  StreamSubscription<LiveEvent>? _liveSub;
  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _analyticsPayments = const [];
  List<Map<String, dynamic>> _topItems = const [];
  bool _dashboardLoading = true;

  @override
  void initState() {
    super.initState();
    _aiPageController = PageController();
    _loadDashboard();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen((event) {
      if (event.type == 'payment.completed') {
        _loadDashboard();
      }
    });
    _startAICarousel();
  }

  void _startAICarousel() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _topItems.length > 1) {
        setState(() {
          _currentAIIndex = (_currentAIIndex + 1) % _topItems.length;
          if (_aiPageController.hasClients) {
            _aiPageController.animateToPage(
              _currentAIIndex,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutCubic,
            );
          }
        });
        _startAICarousel();
      }
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _aiPageController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await sellerBackendService.getDashboardSummary();
      if (!mounted) return;
      final summary = Map<String, dynamic>.from(data['summary'] as Map);
      setState(() {
        _summary = summary;
        _recentPayments = (data['recentPayments'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _analyticsPayments = (data['analyticsPayments'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _topItems = (data['topItems'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _dashboardLoading = false;
      });
      globalSellerTodayRevenue.value = (_summaryInt('today_gross_cents') / 100)
          .toDouble();
    } catch (_) {
      if (mounted) setState(() => _dashboardLoading = false);
    }
  }

  Future<void> _openMetricDetail(
    BuildContext context,
    String title, {
    String? initialCustomerId,
  }) async {
    if (title == 'Low Stock') {
      await _openLowStockDetail(context);
      return;
    }
    if (!mounted) return;
    push(
      context,
      SellerMetricAnalyticsPage(
        title: title,
        payments: _analyticsPayments,
        initialCustomerId: initialCustomerId,
      ),
    );
  }

  Future<void> _openLowStockDetail(BuildContext context) async {
    try {
      final items = await sellerBackendService.getItems();
      final lowStockItems = items
          .where((item) {
            final alertEnabled = item['alertEnabled'] as bool? ?? true;
            final isAlerting = item['isAlerting'] as bool? ?? false;
            return alertEnabled && isAlerting;
          })
          .map((item) {
            final stock = item['stock'] as int? ?? 0;
            final threshold = item['threshold'] as int? ?? 0;
            return _MetricDetailRow(
              title: item['name']?.toString() ?? 'Shelf item',
              subtitle: 'Threshold $threshold',
              trailing: '$stock left',
              caption: item['category']?.toString().isNotEmpty == true
                  ? item['category']!.toString()
                  : 'Live shelf alert',
            );
          })
          .toList();

      if (!mounted) return;
      push(
        context,
        SellerMetricDetailPage(
          title: 'Low Stock',
          headlineValue: '${lowStockItems.length}',
          headlineNote: 'Items currently below your alert threshold',
          rows: lowStockItems,
          emptyLabel: 'Nice. No low stock items are alerting right now.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load low stock details: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => const OfflineScannerPage()),
        ),
        backgroundColor: primary,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'Offline Sale',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: AppPage(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: PageTitle(
                  'Command Center',
                  'Monitor your digital shelf and local operations.',
                ),
              ),
              _buildStatusToggle(),
            ],
          ),
          const SizedBox(height: 24),

          // 1. AI Insights (LLM/RAG Carousel)
          _buildAIInsightCarousel(),
          const SizedBox(height: 32),

          // 2. Financial Health (Profit/Loss/Revenue)
          const Kicker('FINANCIAL HEALTH'),
          const SizedBox(height: 12),
          _buildFinancialGrid(context),
          const SizedBox(height: 32),

          const Kicker('RECENT CHECKOUT PAYMENTS'),
          const SizedBox(height: 12),
          _buildRecentPayments(),
          const SizedBox(height: 32),

          // 3. Pending Handshakes
          const Kicker('PENDING HANDSHAKES'),
          const SizedBox(height: 12),
          _buildFulfillmentRadar(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isOnline ? success.withOpacity(0.1) : muted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _isOnline ? success.withOpacity(0.2) : muted.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isOnline ? success : muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'STORE ONLINE' : 'STORE OFFLINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _isOnline ? success : muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: _isOnline,
              onChanged: (v) => setState(() => _isOnline = v),
              activeColor: success,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightCarousel() {
    if (_dashboardLoading) {
      return Container(
        height: 172,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: shadowSm,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_topItems.isEmpty) {
      return Container(
        height: 172,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: primary.withOpacity(0.12)),
          boxShadow: shadowSm,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insights_outlined, color: primary),
            SizedBox(height: 14),
            Text(
              'No backend sales insight yet',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            SizedBox(height: 6),
            Text(
              'Your most-selling products will appear here after real checkout payments.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _aiPageController,
        itemCount: _topItems.length,
        itemBuilder: (context, index) {
          final insight = _topItems[index];
          final quantity = insight['quantity'] as int? ?? 0;
          final gross = insight['grossCents'] as int? ?? 0;
          final title = insight['name']?.toString() ?? 'Shelf item';
          return Padding(
            padding: const EdgeInsets.only(right: 0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.leaderboard_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'LIVE SALES INSIGHT',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: List.generate(
                          _topItems.length,
                          (i) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: i == index ? Colors.white : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$title is your top seller today.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$quantity sold - ${_formatRupeesCents(gross)} gross revenue from backend payments.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinancialGrid(BuildContext context) {
    final todayGross = _summaryInt('today_gross_cents');
    final todayNet = _summaryInt('today_seller_net_cents');
    final todayCommission = _summaryInt('today_commission_cents');
    final todayCount = _summaryInt('today_payment_count');
    final lowStock = _summaryInt('low_stock_count');
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildHealthCard(
          context,
          'Today Sales',
          _formatRupeesCents(todayGross),
          '$todayCount txns',
          true,
        ),
        _buildHealthCard(
          context,
          'Net To Seller',
          _formatRupeesCents(todayNet),
          'after commission',
          true,
        ),
        _buildHealthCard(
          context,
          'DukaanZone fee',
          _formatRupeesCents(todayCommission),
          'platform fee',
          true,
        ),
        _buildHealthCard(
          context,
          'Low Stock',
          '$lowStock',
          'live shelf alerts',
          lowStock == 0,
        ),
      ],
    );
    /*
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildHealthCard(context, 'Net Profit', '₹1,450', '+12%', true),
        _buildHealthCard(context, 'Est. Loss', '₹120', '-2%', false),
        ValueListenableBuilder<double>(
          valueListenable: globalSellerTodayRevenue,
          builder: (context, rev, _) {
            final formatted =
                '₹${rev.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
            return _buildHealthCard(
              context,
              'Today Rev',
              formatted,
              '+5%',
              true,
            );
          },
        ),
        _buildHealthCard(context, 'Margin', '34%', '+1.2%', true),
      ],
    );
    */
  }

  Widget _buildRecentPayments() {
    if (_dashboardLoading) {
      return Container(
        height: 118,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: shadowSm,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_recentPayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: shadowSm,
        ),
        child: const Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No checkout payments yet. Scan checkout test payments will appear here.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _recentPayments.take(5).map((payment) {
        final items = (payment['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) {
              final name = item['name']?.toString() ?? 'Item';
              final qty = item['quantity'] as int? ?? 1;
              return '$name x$qty';
            })
            .join(', ');
        final user = Map<String, dynamic>.from(payment['user'] as Map? ?? {});
        return InkWell(
          onTap: () => _openMetricDetail(
            context,
            'Today Sales',
            initialCustomerId: user['id']?.toString(),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: shadowSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.payments_outlined, color: success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name']?.toString() ?? 'Customer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items.isEmpty ? 'Direct payment' : items,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatRupeesCents(payment['grossCents'] as int? ?? 0),
                  style: const TextStyle(
                    color: success,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHealthCard(
    BuildContext context,
    String title,
    String value,
    String trend,
    bool isPositive,
  ) {
    return InkWell(
      onTap: () => _openMetricDetail(context, title),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? success : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                    color: isPositive ? success : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _summaryInt(String key) => _summary[key] as int? ?? 0;

  String _formatRupeesCents(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }

  Widget _buildFulfillmentRadar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: const Row(
        children: [
          Icon(Icons.handshake_outlined, color: muted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No pending backend handshakes yet.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String id,
    String name,
    String items,
    String amount,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.1)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Awaiting Verification',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            items,
            style: const TextStyle(
              color: muted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Handover Complete! Inventory updated.'),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Verify Handshake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SellerMetricDetailPage extends StatelessWidget {
  const SellerMetricDetailPage({
    super.key,
    required this.title,
    required this.headlineValue,
    required this.headlineNote,
    required this.rows,
    required this.emptyLabel,
  });

  final String title;
  final String headlineValue;
  final String headlineNote;
  final List<_MetricDetailRow> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PageTitle(
                title,
                'Live backend details for this seller metric.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('LIVE SNAPSHOT'),
              const SizedBox(height: 12),
              Text(
                headlineValue,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                headlineNote,
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Kicker('BREAKDOWN'),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: shadowSm,
            ),
            child: Text(
              emptyLabel,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w800),
            ),
          )
        else
          ...rows.map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: shadowSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.insights_rounded, color: primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.title,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row.subtitle,
                          style: const TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row.caption,
                          style: const TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    row.trailing,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricDetailRow {
  const _MetricDetailRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.caption,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final String caption;
}
