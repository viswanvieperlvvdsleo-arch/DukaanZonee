import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

enum DisputeParty { user, seller }

extension DisputeCategoryIcon on String {
  IconData get disputeIcon {
    if (contains('Missing')) return Icons.inventory_2_outlined;
    if (contains('Quality')) return Icons.star_half_outlined;
    if (contains('Late')) return Icons.access_time_outlined;
    if (contains('Payment')) return Icons.payment_outlined;
    if (contains('Fraud')) return Icons.security_outlined;
    if (contains('Wrong')) return Icons.swap_horiz_outlined;
    if (contains('Shop')) return Icons.storefront_outlined;
    return Icons.gavel_outlined;
  }
}

class AdminDisputesPage extends StatefulWidget {
  const AdminDisputesPage({super.key});

  @override
  State<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends State<AdminDisputesPage> {
  DisputeParty? _filterParty;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _disputes = const [];

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final suffix = _filterParty == null ? '' : '?party=${_filterParty!.name}';
      final data = await apiClient.getJson('/api/admin/disputes$suffix');
      if (!mounted) return;
      setState(() {
        _disputes = (data['disputes'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setStatus(Map<String, dynamic> dispute, String status) async {
    await apiClient.patchJson('/api/admin/disputes/${dispute['id']}/status', {
      'status': status,
    });
    await _loadDisputes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Case ${dispute['id']} marked $status.')),
    );
  }

  Future<void> _deleteDispute(Map<String, dynamic> dispute) async {
    final id = dispute['id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete dispute?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'This removes the dispute from the admin queue.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await apiClient.deleteJson('/api/admin/disputes/$id');
    if (!mounted) return;
    setState(() {
      _disputes = _disputes.where((item) => item['id']?.toString() != id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispute deleted.'), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(Object? value) {
    final dt = DateTime.tryParse(value?.toString() ?? '');
    if (dt == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final userCount = _disputes.where((d) => d['reporterRole'] == 'user').length;
    final sellerCount = _disputes.where((d) => d['reporterRole'] == 'seller').length;
    final openCount = _disputes.where((d) => d['status'] == 'open').length;
    final ackCount = _disputes.where((d) => d['status'] == 'acknowledged').length;
    final resolvedCount = _disputes.where((d) => d['status'] == 'resolved').length;

    return AppPage(
      children: [
        const PageTitle('Dispute Center', 'Reports and mediation from backend tickets.'),
        const SizedBox(height: 32),
        const Kicker('FILTER BY PARTY'),
        const SizedBox(height: 12),
        _buildFilterBar(),
        const SizedBox(height: 28),
        const Kicker('CATEGORY OVERVIEW'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStat(context, '$openCount', 'Open Cases', primary),
            const SizedBox(width: 12),
            _buildStat(context, '$ackCount', 'Acknowledged', muted),
            const SizedBox(width: 12),
            _buildStat(context, '$resolvedCount', 'Resolved', success),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStat(context, '$userCount', 'From Users', primary),
            const SizedBox(width: 12),
            _buildStat(context, '$sellerCount', 'From Sellers', success),
            const SizedBox(width: 12),
            _buildStat(context, '${_disputes.length}', 'Total Reports', muted),
          ],
        ),
        const SizedBox(height: 28),
        const Kicker('DISPUTE REPORTS'),
        const SizedBox(height: 12),
        if (_error != null) _buildErrorCard(),
        if (_isLoading) const LinearProgressIndicator(),
        if (!_isLoading && _disputes.isEmpty)
          _buildEmptyCard('No backend disputes found for this filter.')
        else
          ..._disputes.map(_buildDisputeCard),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          _buildFilterChip('All', null, Icons.public_outlined),
          const SizedBox(width: 4),
          _buildFilterChip('Users', DisputeParty.user, Icons.person_outline),
          const SizedBox(width: 4),
          _buildFilterChip('Sellers', DisputeParty.seller, Icons.storefront_outlined),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, DisputeParty? party, IconData icon) {
    final isSelected = _filterParty == party;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _filterParty = party);
          _loadDisputes();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : muted, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : muted,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color.withOpacity(0.75), fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    final status = dispute['status']?.toString() ?? 'open';
    final category = dispute['category']?.toString() ?? 'Dispute';
    final reporter = Map<String, dynamic>.from(dispute['reporter'] as Map? ?? {});
    final reporterRole = dispute['reporterRole']?.toString() ?? 'user';
    final isFromUser = reporterRole == 'user';
    final statusColor = switch (status) {
      'resolved' => success,
      'acknowledged' => Colors.orange,
      _ => primary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.25)),
        boxShadow: shadowSm,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(category.disputeIcon, color: statusColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: statusColor)),
                      Text(dispute['id']?.toString() ?? '', style: const TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: muted),
                  onSelected: (value) {
                    if (value == 'delete') _deleteDispute(dispute);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isFromUser ? primary : success).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFromUser ? Icons.person_outline : Icons.storefront_outlined,
                            size: 13,
                            color: isFromUser ? primary : success,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isFromUser ? 'User' : 'Seller',
                            style: TextStyle(
                              color: isFromUser ? primary : success,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reporter['name']?.toString() ?? 'Deleted account',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  dispute['description']?.toString() ?? '',
                  style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600, height: 1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  'Filed: ${_formatDate(dispute['createdAt'])}',
                  style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (status != 'resolved') ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (status == 'open') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _setStatus(dispute, 'acknowledged'),
                            icon: const Icon(Icons.notifications_active_outlined, size: 16),
                            label: const Text('Acknowledge'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _setStatus(dispute, 'resolved'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Resolve'),
                          style: ElevatedButton.styleFrom(backgroundColor: success, foregroundColor: Colors.white),
                        ),
                      ),
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
          Expanded(child: Text('Could not load disputes. $_error')),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: success.withOpacity(0.8)),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: success, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
