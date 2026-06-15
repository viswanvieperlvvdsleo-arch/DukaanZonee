import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminPromotionsPage extends StatefulWidget {
  const AdminPromotionsPage({super.key});

  @override
  State<AdminPromotionsPage> createState() => _AdminPromotionsPageState();
}

class _AdminPromotionsPageState extends State<AdminPromotionsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _promotions = const [];
  StreamSubscription<LiveEvent>? _liveSub;

  @override
  void initState() {
    super.initState();
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen((event) {
      if (event.type == 'promotion.created' ||
          event.type == 'promotion.status' ||
          event.type == 'promotion.metrics' ||
          event.type == 'notification.created') {
        _loadPromotions(silent: true);
      }
    });
    _loadPromotions();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPromotions({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await apiClient.getJson('/api/admin/promotions');
      if (!mounted) return;
      setState(() {
        _promotions = (data['promotions'] as List? ?? const [])
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

  Future<void> _setPromotionStatus(String id, String status) async {
    await apiClient.patchJson('/api/admin/promotions/$id/status', {
      'status': status,
    });
    await _loadPromotions();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Promotion marked as $status.')));
  }

  @override
  Widget build(BuildContext context) {
    final pending = _promotions.where((promo) => promo['status'] == 'pending');
    final live = _promotions.where((promo) {
      return promo['status'] == 'approved' && !_isExpired(promo['endsAt']);
    });
    final archived = _promotions.where((promo) {
      return promo['status'] == 'rejected' ||
          promo['status'] == 'expired' ||
          (promo['status'] == 'approved' && _isExpired(promo['endsAt']));
    });

    return AppPage(
      children: [
        const PageTitle(
          'Promotion Hub',
          'Approve seller-paid marketing slots from the backend.',
        ),
        const SizedBox(height: 24),
        if (_error != null) _buildErrorCard(),
        if (_isLoading) const LinearProgressIndicator(),
        if (_isLoading) const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _loadPromotions,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (!_isLoading && _promotions.isEmpty)
          _buildEmptyCard('No backend promotion requests yet.'),
        if (pending.isNotEmpty) ...[
          const Kicker('PENDING APPROVALS'),
          const SizedBox(height: 12),
          ...pending.map((promo) => _buildPromotionCard(promo, pending: true)),
          const SizedBox(height: 28),
        ],
        if (live.isNotEmpty) ...[
          const Kicker('ACTIVE LIVE SLOTS'),
          const SizedBox(height: 12),
          ...live.map(_buildPromotionCard),
          const SizedBox(height: 28),
        ],
        if (archived.isNotEmpty) ...[
          const Kicker('ARCHIVED PROMOS'),
          const SizedBox(height: 12),
          ...archived.map(_buildPromotionCard),
        ],
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
          Expanded(child: Text('Could not load promotions. $_error')),
        ],
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

  Widget _buildPromotionCard(
    Map<String, dynamic> promo, {
    bool pending = false,
  }) {
    final item = Map<String, dynamic>.from(promo['item'] as Map? ?? {});
    final shop = Map<String, dynamic>.from(promo['shop'] as Map? ?? {});
    final status = promo['status']?.toString() ?? 'pending';
    final statusColor = switch (status) {
      'approved' => success,
      'rejected' => Colors.redAccent,
      'refunded' => primary,
      'expired' => muted,
      _ => Colors.orange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
        border: Border.all(color: statusColor.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, statusColor]),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                _buildImage(item['imageUrl']?.toString()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? 'Product',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop['name']?.toString() ?? 'Shop',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(status, statusColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric(
                      Icons.calendar_today_outlined,
                      '${promo['durationDays'] ?? 0} days',
                    ),
                    _buildMetric(
                      Icons.visibility_outlined,
                      '${promo['impressions'] ?? 0} imp',
                    ),
                    _buildMetric(
                      Icons.touch_app_outlined,
                      '${promo['clicks'] ?? 0} clicks',
                    ),
                    _buildMetric(
                      Icons.account_balance_wallet_outlined,
                      _formatRupees(promo['amountCents'] as int? ?? 0),
                    ),
                  ],
                ),
                if (pending || status == 'approved') ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _setPromotionStatus(
                            promo['id'].toString(),
                            'rejected',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          child: Text(pending ? 'Reject' : 'Disapprove'),
                        ),
                      ),
                      if (pending) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _setPromotionStatus(
                              promo['id'].toString(),
                              'approved',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: success,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _setPromotionStatus(
                              promo['id'].toString(),
                              'refunded',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Pay Return'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    return Container(
      width: 54,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ProductImageView(
        imageUrl: imageUrl,
        fallbackIcon: Icons.campaign,
        fallbackIconSize: 24,
        fallbackColor: Colors.white,
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  bool _isExpired(Object? value) {
    final end = DateTime.tryParse(value?.toString() ?? '');
    return end != null && end.isBefore(DateTime.now());
  }

  String _formatRupees(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }
}
