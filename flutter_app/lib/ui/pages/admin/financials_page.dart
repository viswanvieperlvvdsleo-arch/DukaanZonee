import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'seller_financial_details_page.dart';

class SellerFinancialAccount {
  SellerFinancialAccount({
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    required this.totalReceived,
    required this.transactions,
    required this.paymentReady,
    required this.gatewayProvider,
  });
  final String shopId;
  final String shopName;
  final String ownerName;
  final double totalReceived;
  final List<FinancialTx> transactions;
  final bool paymentReady;
  final String gatewayProvider;
}

class FinancialTx {
  FinancialTx({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.type,
  });
  final String id;
  final DateTime date;
  final double amount;
  final FinancialTxCategory category;
  final FinancialTxType type;
}

enum FinancialTxCategory { promotion, payoutDeduction, refund, platformFee }

enum FinancialTxType { credit, debit }

extension FinancialTxCategoryX on FinancialTxCategory {
  String get label {
    switch (this) {
      case FinancialTxCategory.promotion:
        return 'Promotion Ad Slot';
      case FinancialTxCategory.payoutDeduction:
        return 'Seller Net Payment';
      case FinancialTxCategory.refund:
        return 'Dispute Refund';
      case FinancialTxCategory.platformFee:
        return 'Platform Commission';
    }
  }

  IconData get icon {
    switch (this) {
      case FinancialTxCategory.promotion:
        return Icons.campaign_outlined;
      case FinancialTxCategory.payoutDeduction:
        return Icons.payments_outlined;
      case FinancialTxCategory.refund:
        return Icons.reply_outlined;
      case FinancialTxCategory.platformFee:
        return Icons.account_balance_outlined;
    }
  }

  Color get color {
    switch (this) {
      case FinancialTxCategory.promotion:
        return primary;
      case FinancialTxCategory.payoutDeduction:
        return success;
      case FinancialTxCategory.refund:
        return Colors.redAccent;
      case FinancialTxCategory.platformFee:
        return success;
    }
  }
}

class AdminFinancialsPage extends StatefulWidget {
  const AdminFinancialsPage({super.key});

  @override
  State<AdminFinancialsPage> createState() => _AdminFinancialsPageState();
}

class _AdminFinancialsPageState extends State<AdminFinancialsPage> {
  String _globalSearch = '';
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _overview = const {};
  List<SellerFinancialAccount> _accounts = const [];
  StreamSubscription<LiveEvent>? _liveSub;

  @override
  void initState() {
    super.initState();
    _loadFinancials();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen((event) {
      if (event.type == 'payment.completed') {
        _loadFinancials(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFinancials({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final overviewData = await apiClient.getJson('/api/admin/overview');
      final accountsData = await apiClient.getJson('/api/admin/accounts');
      final paymentsData = await apiClient.getJson('/api/admin/payments');
      if (!mounted) return;
      final payments = (paymentsData['payments'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      final sellers = (accountsData['sellers'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (raw) =>
                _mapSellerFinancial(Map<String, dynamic>.from(raw), payments),
          )
          .toList();
      setState(() {
        _overview = Map<String, dynamic>.from(
          overviewData['overview'] as Map? ?? {},
        );
        _accounts = sellers;
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

  SellerFinancialAccount _mapSellerFinancial(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> payments,
  ) {
    final shopId = data['shopId']?.toString() ?? '';
    final profile = Map<String, dynamic>.from(
      data['paymentProfile'] as Map? ?? {},
    );
    final txs = payments
        .where((payment) {
          final shop = payment['shop'] as Map?;
          return shop?['id']?.toString() == shopId;
        })
        .map((payment) => _mapPaymentTx(payment))
        .toList();
    final revenueCents = data['revenueCents'] as int? ?? 0;
    return SellerFinancialAccount(
      shopId: shopId,
      shopName: data['shopName']?.toString() ?? 'Shop',
      ownerName: data['owner']?.toString() ?? 'Seller',
      totalReceived: revenueCents / 100,
      transactions: txs,
      paymentReady: profile['payoutReady'] == true,
      gatewayProvider: profile['gatewayProvider']?.toString() ?? 'mock_gateway',
    );
  }

  FinancialTx _mapPaymentTx(Map<String, dynamic> payment) {
    return FinancialTx(
      id:
          payment['gatewayReference']?.toString() ??
          payment['id']?.toString() ??
          'payment',
      date:
          DateTime.tryParse(payment['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      amount: ((payment['sellerNetCents'] as int? ?? 0) / 100),
      category: FinancialTxCategory.payoutDeduction,
      type: FinancialTxType.credit,
    );
  }

  List<SellerFinancialAccount> get _filteredAccounts {
    final q = _globalSearch.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts.where((account) {
      return account.shopName.toLowerCase().contains(q) ||
          account.ownerName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle(
          'Transaction Hub',
          'Backend payment totals, platform commission, and seller net revenue.',
        ),
        const SizedBox(height: 32),
        if (_error != null) _buildErrorCard(),
        if (_isLoading) const LinearProgressIndicator(),
        if (_isLoading) const SizedBox(height: 18),
        const Kicker('SETTLEMENT OVERVIEW'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            final cards = [
              _buildMiniCard(
                context,
                'Gross Payments',
                _formatRupeesCents(_overviewInt('gross_cents')),
                primary,
              ),
              _buildMiniCard(
                context,
                'Gateway Fee',
                _formatRupeesCents(_overviewInt('gateway_fee_cents')),
                Colors.redAccent,
              ),
              _buildMiniCard(
                context,
                'Seller Net',
                _formatRupeesCents(_overviewInt('seller_net_cents')),
                success,
              ),
              _buildMiniCard(
                context,
                'DukaanZone fee',
                _formatRupeesCents(_overviewInt('commission_cents')),
                Colors.orange,
              ),
            ];
            if (isNarrow) {
              final cardWidth = constraints.maxWidth < 420
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map((card) => SizedBox(width: cardWidth, child: card))
                    .toList(),
              );
            }
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        const Kicker('PAYMENT FLOW'),
        const SizedBox(height: 12),
        _buildPaymentFlowCard(),
        const SizedBox(height: 32),
        const Kicker('MERCHANT ACCOUNTS'),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _globalSearch = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: muted),
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh, color: muted),
              onPressed: _loadFinancials,
            ),
            hintText: 'Search merchant by shop name or owner...',
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_isLoading && _filteredAccounts.isEmpty)
          _buildEmptyCard('No backend seller revenue found yet.')
        else
          ..._filteredAccounts.map(_buildSellerFinancialCard),
        const SizedBox(height: 48),
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
            child: Text('Could not load financial backend data. $_error'),
          ),
          TextButton(onPressed: _loadFinancials, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPaymentFlowCard() {
    final gross = _overviewInt('gross_cents');
    final gateway = _overviewInt('gateway_fee_cents');
    final sellerNet = _overviewInt('seller_net_cents');
    final commission = _overviewInt('commission_cents');
    final maxValue = [
      gross,
      gateway,
      sellerNet,
      commission,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final rows = [
      ('Gross', gross, primary),
      ('Gateway Fee', gateway, Colors.redAccent),
      ('Seller Net', sellerNet, success),
      ('Commission', commission, Colors.orange),
    ];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: neonGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Payment Split',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_overviewInt('payment_count')} payments recorded',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          ...rows.map((row) {
            final value = row.$2;
            final width = value / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _formatRupeesCents(value),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: width.clamp(0.0, 1.0),
                    minHeight: 10,
                    color: row.$3,
                    backgroundColor: Colors.white.withOpacity(0.12),
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

  Widget _buildSellerFinancialCard(SellerFinancialAccount account) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerFinancialDetailsPage(account: account),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: muted.withOpacity(0.2), width: 2),
          boxShadow: shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront, color: success),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Owner: ${account.ownerName} - ${account.transactions.length} ledger rows',
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      _buildStatusPill(
                        account.paymentReady
                            ? 'Payment ready'
                            : 'Payment setup incomplete',
                        account.paymentReady ? success : Colors.orange,
                      ),
                      _buildStatusPill(account.gatewayProvider, primary),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${account.totalReceived.toStringAsFixed(account.totalReceived % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: success,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'seller net',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Text(
        text,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w800),
      ),
    );
  }

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
