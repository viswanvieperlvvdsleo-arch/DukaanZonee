import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminShopsPage extends StatefulWidget {
  const AdminShopsPage({super.key});

  @override
  State<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends State<AdminShopsPage> {
  String _query = '';
  bool _isLoading = true;
  String? _error;
  List<AdminSellerEntry> _sellers = const [];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await apiClient.getJson('/api/admin/accounts');
      if (!mounted) return;
      setState(() {
        _sellers = (data['sellers'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => _mapSeller(Map<String, dynamic>.from(raw)))
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

  AdminSellerEntry _mapSeller(Map<String, dynamic> data) {
    final revenueCents = data['revenueCents'] as int? ?? 0;
    final restrictedUntil = DateTime.tryParse(
      data['restrictedUntil']?.toString() ?? '',
    );
    return AdminSellerEntry(
      id: data['id']?.toString() ?? '',
      shopId: data['shopId']?.toString() ?? '',
      shopName: data['shopName']?.toString() ?? 'Shop',
      owner: data['owner']?.toString() ?? 'Seller',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Local shop',
      status: data['status']?.toString() ?? 'Active',
      revenue: _formatRupees(revenueCents),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      avatarUrl: data['avatarUrl']?.toString(),
      isOnline: data['isOnline'] == true,
      restrictedUntil: restrictedUntil,
    );
  }

  List<AdminSellerEntry> get _filteredSellers {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sellers;
    return _sellers.where((seller) {
      return seller.shopName.toLowerCase().contains(q) ||
          seller.owner.toLowerCase().contains(q) ||
          seller.email.toLowerCase().contains(q) ||
          seller.phone.toLowerCase().contains(q) ||
          seller.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _restrictSeller(AdminSellerEntry seller, int days) async {
    await apiClient.patchJson('/api/admin/accounts/${seller.id}/restriction', {
      'days': days,
      'reason': days == 0 ? '' : 'Restricted by admin shop audit',
    });
    await _loadShops();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(days == 0
            ? '${seller.shopName} reinstated.'
            : '${seller.shopName} restricted for $days days.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restricted = _filteredSellers
        .where((seller) => seller.restrictedUntil != null)
        .toList();
    final active = _filteredSellers
        .where((seller) => seller.restrictedUntil == null)
        .toList();

    return AppPage(
      children: [
        const PageTitle('Merchant Hub', 'Manage live seller shops from the backend.'),
        const SizedBox(height: 32),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search shops by name, owner, email, phone, or category...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadShops,
            ),
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading) const LinearProgressIndicator(),
        if (_error != null) _buildErrorCard(),
        if (!_isLoading && _filteredSellers.isEmpty)
          _buildEmptyCard('No backend shops found yet.'),
        if (restricted.isNotEmpty) ...[
          const Kicker('RESTRICTED MERCHANTS'),
          const SizedBox(height: 12),
          ...restricted.map((seller) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildShopCard(seller),
              )),
          const SizedBox(height: 16),
        ],
        if (active.isNotEmpty) ...[
          const Kicker('ACTIVE MERCHANTS'),
          const SizedBox(height: 12),
          ...active.map((seller) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildShopCard(seller),
              )),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
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
          Expanded(child: Text('Could not load shops. $_error')),
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
      child: Text(text, style: const TextStyle(color: muted, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildShopCard(AdminSellerEntry seller) {
    final isRestricted = seller.restrictedUntil != null;
    final statusColor = isRestricted
        ? Colors.redAccent
        : seller.status == 'Closed'
            ? Colors.orange
            : success;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(seller),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.shopName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [seller.owner, seller.category, seller.email]
                          .where((value) => value.trim().isNotEmpty)
                          .join(' - '),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${seller.revenue} seller net - ${seller.phone.isEmpty ? 'No phone' : seller.phone}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isRestricted ? 'Restricted' : seller.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isRestricted)
                ElevatedButton(
                  onPressed: () => _restrictSeller(seller, 0),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  child: const Text('Reinstate'),
                )
              else ...[
                OutlinedButton(
                  onPressed: () => _restrictSeller(seller, 7),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  child: const Text('Restrict 7d'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => push(context, AdminSellerProfilePage(seller: seller)),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  child: const Text('Audit'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(AdminSellerEntry seller) {
    if (seller.avatarUrl != null && seller.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(seller.avatarUrl!),
        backgroundColor: primary.withOpacity(0.1),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.store, color: primary),
    );
  }

  String _formatRupees(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }
}
