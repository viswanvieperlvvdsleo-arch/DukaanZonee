import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminUserEntry {
  const AdminUserEntry({
    this.id = '',
    required this.name,
    required this.email,
    this.phone = '',
    this.block = 'Live account',
    this.trust = 100,
    this.spend = 'Rs 0',
    this.isFlagged = false,
    this.profilePic,
    this.isOnline = false,
    this.restrictedUntil,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String block;
  final String spend;
  final int trust;
  final bool isFlagged;
  final String? profilePic;
  final bool isOnline;
  final DateTime? restrictedUntil;
}

class AdminSellerEntry {
  const AdminSellerEntry({
    this.id = '',
    this.shopId = '',
    required this.shopName,
    required this.owner,
    this.email = '',
    this.phone = '',
    this.category = 'Local shop',
    this.status = 'Active',
    this.rating = 0,
    this.revenue = 'Rs 0',
    this.avatarUrl,
    this.isOnline = false,
    this.restrictedUntil,
  });

  final String id;
  final String shopId;
  final String shopName;
  final String owner;
  final String email;
  final String phone;
  final String category;
  final String status;
  final String revenue;
  final double rating;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? restrictedUntil;
}

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isLoading = true;
  String? _error;
  List<AdminUserEntry> _users = const [];
  List<AdminSellerEntry> _sellers = const [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAccounts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await apiClient.getJson('/api/admin/accounts');
      if (!mounted) return;
      setState(() {
        _users = (data['users'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => _mapUser(Map<String, dynamic>.from(raw)))
            .toList();
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

  AdminUserEntry _mapUser(Map<String, dynamic> data) {
    final spendCents = data['spendCents'] as int? ?? 0;
    final restrictedUntil = DateTime.tryParse(
      data['restrictedUntil']?.toString() ?? '',
    );
    return AdminUserEntry(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'User',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      block: data['chatCount'] == null ? 'No chats yet' : '${data['chatCount']} chats',
      spend: _formatRupees(spendCents),
      trust: restrictedUntil != null ? 35 : 100,
      isFlagged: restrictedUntil != null,
      profilePic: data['profilePic']?.toString(),
      isOnline: data['isOnline'] == true,
      restrictedUntil: restrictedUntil,
    );
  }

  AdminSellerEntry _mapSeller(Map<String, dynamic> data) {
    final revenueCents = data['revenueCents'] as int? ?? 0;
    return AdminSellerEntry(
      id: data['id']?.toString() ?? '',
      shopId: data['shopId']?.toString() ?? '',
      shopName: data['shopName']?.toString() ?? 'Shop',
      owner: data['owner']?.toString() ?? 'Seller',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Local shop',
      status: data['status']?.toString() ?? 'Active',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      revenue: _formatRupees(revenueCents),
      avatarUrl: data['avatarUrl']?.toString(),
      isOnline: data['isOnline'] == true,
      restrictedUntil: DateTime.tryParse(
        data['restrictedUntil']?.toString() ?? '',
      ),
    );
  }

  String _formatRupees(int cents) {
    final rupees = cents / 100;
    return 'Rs ${rupees.toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }

  List<AdminUserEntry> get _filteredUsers {
    if (_query.isEmpty) return _users;
    return _users
        .where(
          (user) =>
              user.name.toLowerCase().contains(_query) ||
              user.email.toLowerCase().contains(_query) ||
              user.phone.toLowerCase().contains(_query),
        )
        .toList();
  }

  List<AdminSellerEntry> get _filteredSellers {
    if (_query.isEmpty) return _sellers;
    return _sellers
        .where(
          (seller) =>
              seller.shopName.toLowerCase().contains(_query) ||
              seller.owner.toLowerCase().contains(_query) ||
              seller.email.toLowerCase().contains(_query) ||
              seller.phone.toLowerCase().contains(_query),
        )
        .toList();
  }

  Future<void> _deleteAccount({
    required String id,
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await apiClient.deleteJson('/api/admin/accounts/$id');
    await _loadAccounts();
  }

  Future<void> _restrictAccount(String id, int days) async {
    await apiClient.patchJson('/api/admin/accounts/$id/restriction', {
      'days': days,
      'reason': days == 0 ? '' : 'Restricted by admin moderation',
    });
    await _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppPage(
      children: [
        const PageTitle('Accounts', 'Manage users, sellers, chats, and restrictions.'),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: shadowSm,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone, or shop...',
              hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.search, color: muted),
              suffixIcon: _query.isEmpty
                  ? IconButton(
                      icon: const Icon(Icons.refresh, color: muted),
                      onPressed: _loadAccounts,
                    )
                  : IconButton(
                      icon: const Icon(Icons.close, color: muted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorPadding: const EdgeInsets.all(5),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            tabs: [
              Tab(text: 'Users (${_filteredUsers.length})'),
              Tab(text: 'Sellers (${_filteredSellers.length})'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          const PageSkeleton(cardCount: 3)
        else if (_error != null)
          _AdminEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load admin accounts',
            subtitle: _error!,
            actionLabel: 'Retry',
            onAction: _loadAccounts,
          )
        else
          SizedBox(
            height: 820,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _UsersList(
                  users: _filteredUsers,
                  onDeleteUser: (user) => _deleteAccount(
                    id: user.id,
                    title: 'Delete User Account',
                    message: 'Delete ${user.name}? The admin history remains auditable.',
                  ),
                  onRestrictUser: (user, days) => _restrictAccount(user.id, days),
                ),
                _SellersList(
                  sellers: _filteredSellers,
                  onDeleteSeller: (seller) => _deleteAccount(
                    id: seller.id,
                    title: 'Delete Seller Account',
                    message: 'Delete ${seller.shopName}? The admin history remains auditable.',
                  ),
                  onRestrictSeller: (seller, days) =>
                      _restrictAccount(seller.id, days),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({
    required this.users,
    required this.onDeleteUser,
    required this.onRestrictUser,
  });

  final List<AdminUserEntry> users;
  final ValueChanged<AdminUserEntry> onDeleteUser;
  final void Function(AdminUserEntry user, int days) onRestrictUser;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _AdminEmptyState(
        icon: Icons.person_search_outlined,
        title: 'No users found',
        subtitle: 'Accounts will appear here after users register.',
      );
    }
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _UserCard(
        user: users[index],
        onDelete: () => onDeleteUser(users[index]),
        onRestrict: (days) => onRestrictUser(users[index], days),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onDelete,
    required this.onRestrict,
  });

  final AdminUserEntry user;
  final VoidCallback onDelete;
  final ValueChanged<int> onRestrict;

  @override
  Widget build(BuildContext context) {
    return _AdminAccountCard(
      title: user.name,
      subtitle: '${user.email}${user.phone.isEmpty ? '' : ' - ${user.phone}'}',
      metric: user.spend,
      status: user.restrictedUntil == null ? 'Active' : 'Restricted',
      avatarUrl: user.profilePic,
      fallbackIcon: Icons.person,
      isOnline: user.isOnline,
      onTap: () => push(context, AdminUserProfilePage(user: user)),
      onDelete: onDelete,
      onRestrict: onRestrict,
    );
  }
}

class _SellersList extends StatelessWidget {
  const _SellersList({
    required this.sellers,
    required this.onDeleteSeller,
    required this.onRestrictSeller,
  });

  final List<AdminSellerEntry> sellers;
  final ValueChanged<AdminSellerEntry> onDeleteSeller;
  final void Function(AdminSellerEntry seller, int days) onRestrictSeller;

  @override
  Widget build(BuildContext context) {
    if (sellers.isEmpty) {
      return const _AdminEmptyState(
        icon: Icons.storefront_outlined,
        title: 'No sellers found',
        subtitle: 'Seller accounts will appear here after shop registration.',
      );
    }
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sellers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _SellerCard(
        seller: sellers[index],
        onDelete: () => onDeleteSeller(sellers[index]),
        onRestrict: (days) => onRestrictSeller(sellers[index], days),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.seller,
    required this.onDelete,
    required this.onRestrict,
  });

  final AdminSellerEntry seller;
  final VoidCallback onDelete;
  final ValueChanged<int> onRestrict;

  @override
  Widget build(BuildContext context) {
    return _AdminAccountCard(
      title: seller.shopName,
      subtitle: '${seller.owner} - ${seller.category}',
      metric: seller.revenue,
      status: seller.status,
      avatarUrl: seller.avatarUrl,
      fallbackIcon: Icons.storefront,
      isOnline: seller.isOnline,
      onTap: () => push(context, AdminSellerProfilePage(seller: seller)),
      onDelete: onDelete,
      onRestrict: onRestrict,
    );
  }
}

class _AdminAccountCard extends StatelessWidget {
  const _AdminAccountCard({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.status,
    required this.fallbackIcon,
    required this.isOnline,
    required this.onTap,
    required this.onDelete,
    required this.onRestrict,
    this.avatarUrl,
  });

  final String title;
  final String subtitle;
  final String metric;
  final String status;
  final IconData fallbackIcon;
  final bool isOnline;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<int> onRestrict;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final isRestricted = status == 'Restricted';
    final statusColor = isRestricted ? Colors.orange : success;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withOpacity(0.22)),
        boxShadow: shadowSm,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: ClipOval(
                child: ProductImageView(
                  imageUrl: avatarUrl,
                  fallbackIcon: fallbackIcon,
                  fallbackColor: primary,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _AdminChip(label: status, color: statusColor),
                _AdminChip(label: metric, color: success),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') onDelete();
            if (value == 'restrict7') onRestrict(7);
            if (value == 'restrict30') onRestrict(30);
            if (value == 'clear') onRestrict(0);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'restrict7', child: Text('Restrict 7 days')),
            PopupMenuItem(value: 'restrict30', child: Text('Restrict 30 days')),
            PopupMenuItem(value: 'clear', child: Text('Clear restriction')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Text('Delete account')),
          ],
        ),
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  const _AdminChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: muted.withOpacity(0.45)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
