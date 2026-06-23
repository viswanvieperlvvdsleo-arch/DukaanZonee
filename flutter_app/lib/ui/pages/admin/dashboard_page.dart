import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _activeCardIndex = 0;
  String _query = '';
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _overview = const {};
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _sellers = const [];
  StreamSubscription<LiveEvent>? _liveSub;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen((event) {
      if (event.type == 'payment.completed' ||
          event.type == 'notification.created') {
        _loadDashboard(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final overviewData = await apiClient.getJson('/api/admin/overview');
      final accountsData = await apiClient.getJson('/api/admin/accounts');
      if (!mounted) return;
      setState(() {
        _overview = Map<String, dynamic>.from(
          overviewData['overview'] as Map? ?? {},
        );
        _users = (accountsData['users'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _sellers = (accountsData['sellers'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        if (!silent) _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((user) {
      return _contains(user, ['name', 'email', 'phone'], q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSellers {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sellers;
    return _sellers.where((seller) {
      return _contains(
        seller,
        ['shopName', 'owner', 'email', 'phone', 'category', 'block'],
        q,
      );
    }).toList();
  }

  bool _contains(Map<String, dynamic> row, List<String> keys, String q) {
    return keys.any((key) => (row[key] ?? '').toString().toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle(
          'Ecosystem Overview',
          'Real-time snapshot from DukaanZone accounts, shops, and payments.',
        ),
        const SizedBox(height: 24),
        if (_error != null) _buildErrorCard(),
        if (_isLoading) const LinearProgressIndicator(),
        if (_isLoading) const SizedBox(height: 18),
        const Kicker('LIVE PLATFORM STATS'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            _buildStatCard(
              0,
              'Total Users',
              '${_overviewInt('user_count', fallback: _users.length)}',
              Icons.people_alt,
              primary,
            ),
            _buildStatCard(
              1,
              'Active Shops',
              '${_overviewInt('shop_count', fallback: _sellers.length)}',
              Icons.storefront,
              success,
            ),
            _buildStatCard(
              2,
              'Platform Rev',
              _formatRupeesCents(_overviewInt('commission_cents')),
              Icons.account_balance_wallet,
              primary,
            ),
            _buildStatCard(
              3,
              'Payments',
              '${_overviewInt('payment_count')}',
              Icons.receipt_long_outlined,
              success,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildMetricPanel(),
        const SizedBox(height: 32),
        _buildActivePanel(),
        const SizedBox(height: 32),
        const Kicker('MARKET DISTRIBUTION'),
        const SizedBox(height: 12),
        _buildCategoryDistribution(),
        const SizedBox(height: 32),
        const Kicker('LIVE PLATFORM PULSE'),
        const SizedBox(height: 12),
        _buildPulseItem(
          context,
          'Payments',
          '${_overviewInt('payment_count')} completed payments recorded.',
          Icons.receipt_long_outlined,
          success,
          onTap: () => globalActiveTabOverride.value = 2,
        ),
        _buildPulseItem(
          context,
          'Accounts',
          '${_users.length} users and ${_sellers.length} sellers are visible to admin.',
          Icons.manage_accounts_outlined,
          primary,
          onTap: () => globalActiveTabOverride.value = 6,
        ),
        _buildPulseItem(
          context,
          'Deleted Messages',
          '${_overviewInt('deleted_message_count')} deleted chat messages preserved for audit.',
          Icons.history_outlined,
          Colors.orange,
          onTap: () => globalActiveTabOverride.value = 6,
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load admin backend data. $_error',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: _loadDashboard, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    int index,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _activeCardIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeCardIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primary : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : shadowSm,
          border: Border.all(
            color: isSelected ? primary : muted.withOpacity(0.15),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : color, size: 28),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white70 : muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPanel() {
    final rows = switch (_activeCardIndex) {
      0 => [
          _metric('Users', _users.length, primary),
          _metric('Online', _users.where((u) => u['isOnline'] == true).length, success),
          _metric('Restricted', _users.where((u) => u['restrictedUntil'] != null).length, Colors.orange),
        ],
      1 => [
          _metric('Sellers', _sellers.length, success),
          _metric('Open Shops', _sellers.where((s) => s['isOpen'] != false).length, primary),
          _metric('Products', _overviewInt('product_count'), Colors.orange),
        ],
      2 => [
          _metric('Gross', _overviewInt('gross_cents'), primary, cents: true),
          _metric('Seller Net', _overviewInt('seller_net_cents'), success, cents: true),
          _metric('Commission', _overviewInt('commission_cents'), Colors.orange, cents: true),
        ],
      _ => [
          _metric('Payments', _overviewInt('payment_count'), success),
          _metric('Deleted Messages', _overviewInt('deleted_message_count'), Colors.orange),
          _metric('Products', _overviewInt('product_count'), primary),
        ],
    };
    final title = switch (_activeCardIndex) {
      0 => 'User Health',
      1 => 'Seller Health',
      2 => 'Payment Health',
      _ => 'Activity Health',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: muted.withOpacity(0.15)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              return Flex(
                direction: compact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows.map((row) {
                  return Flexible(
                    flex: compact ? 0 : 1,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: compact ? 0 : 12,
                        bottom: compact ? 12 : 0,
                      ),
                      child: _buildMetricTile(row),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _metric(
    String label,
    int value,
    Color color, {
    bool cents = false,
  }) {
    return {
      'label': label,
      'value': cents ? _formatRupeesCents(value) : '$value',
      'color': color,
    };
  }

  Widget _buildMetricTile(Map<String, dynamic> row) {
    final color = row['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['label'] as String,
            style: const TextStyle(color: muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            row['value'] as String,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePanel() {
    if (_activeCardIndex == 0) {
      return _buildAccountPanel(
        title: 'USER MANAGEMENT TERMINAL',
        hint: 'Search active user accounts...',
        rows: _filteredUsers,
        empty: 'No backend users found.',
        icon: Icons.person,
        titleKey: 'name',
        subtitle: (row) => [row['email'], row['phone']].where(_hasText).join(' - '),
        metric: (row) => _formatRupeesCents(row['spendCents'] as int? ?? 0),
      );
    }
    if (_activeCardIndex == 1) {
      return _buildAccountPanel(
        title: 'SELLER/SHOP MANAGEMENT TERMINAL',
        hint: 'Search seller/shop accounts...',
        rows: _filteredSellers,
        empty: 'No backend sellers found.',
        icon: Icons.storefront,
        titleKey: 'shopName',
        subtitle: (row) => [row['owner'], row['category'], row['block']].where(_hasText).join(' - '),
        metric: (row) => _formatRupeesCents(row['revenueCents'] as int? ?? 0),
      );
    }
    if (_activeCardIndex == 2) {
      return _buildRevenueSummaryCard();
    }
    return _buildActivitySummaryCard();
  }

  Widget _buildAccountPanel({
    required String title,
    required String hint,
    required List<Map<String, dynamic>> rows,
    required String empty,
    required IconData icon,
    required String titleKey,
    required String Function(Map<String, dynamic>) subtitle,
    required String Function(Map<String, dynamic>) metric,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: muted.withOpacity(0.15)),
            boxShadow: shadowSm,
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: muted),
                  hintText: hint,
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    empty,
                    style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                )
              else
                ...rows.take(8).map((row) {
                  final avatarUrl = (row['avatarUrl'] ?? row['profilePic'])?.toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: muted.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        _buildAvatar(icon, avatarUrl),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row[titleKey]?.toString() ?? 'Account',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle(row),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          metric(row),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: success),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(IconData fallbackIcon, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: primary.withOpacity(0.1),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: primary.withOpacity(0.12),
      child: Icon(fallbackIcon, color: primary),
    );
  }

  Widget _buildRevenueSummaryCard() {
    final gross = _overviewInt('gross_cents');
    final sellerNet = _overviewInt('seller_net_cents');
    final commission = _overviewInt('commission_cents');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('REVENUE SUMMARY'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: muted.withOpacity(0.15)),
            boxShadow: shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Payment Split',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildRevenueRow('Gross user payments', _formatRupeesCents(gross), primary),
              _buildRevenueRow('Seller net payable', _formatRupeesCents(sellerNet), success),
              _buildRevenueRow('DukaanZone commission', _formatRupeesCents(commission), Colors.orange),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PAYMENTS:',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: muted),
                  ),
                  Text(
                    '${_overviewInt('payment_count')}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: success),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueRow(String stream, String amount, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: dotColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(stream, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActivitySummaryCard() {
    final items = [
      ['Products', '${_overviewInt('product_count')}', Icons.inventory_2_outlined],
      ['Payments', '${_overviewInt('payment_count')}', Icons.payments_outlined],
      ['Deleted Messages', '${_overviewInt('deleted_message_count')}', Icons.delete_sweep_outlined],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('ACTIVITY SUMMARY'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: muted.withOpacity(0.15)),
            boxShadow: shadowSm,
          ),
          child: Column(
            children: items.map((item) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: primary.withOpacity(0.1),
                  child: Icon(item[2] as IconData, color: primary),
                ),
                title: Text(item[0] as String, style: const TextStyle(fontWeight: FontWeight.w900)),
                trailing: Text(item[1] as String, style: const TextStyle(fontWeight: FontWeight.w900)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDistribution() {
    final counts = <String, int>{};
    for (final seller in _sellers) {
      final category = (seller['category'] ?? 'Uncategorized').toString();
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: entries.isEmpty
          ? const Text('No seller categories found yet.', style: TextStyle(color: muted, fontWeight: FontWeight.w700))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 18),
                ...entries.map((entry) {
                  final total = _sellers.isEmpty ? 1 : _sellers.length;
                  final percent = entry.value / total;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${entry.value} shops', style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          color: success,
                          backgroundColor: muted.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildPulseItem(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: shadowSm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(description, style: const TextStyle(color: muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }

  bool _hasText(Object? value) => value != null && value.toString().trim().isNotEmpty;

  int _overviewInt(String key, {int fallback = 0}) {
    final raw = _overview[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  String _formatRupeesCents(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }
}
