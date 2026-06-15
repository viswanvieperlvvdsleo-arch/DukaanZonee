import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminSellerProfilePage extends StatefulWidget {
  const AdminSellerProfilePage({super.key, required this.seller});
  final AdminSellerEntry seller;

  @override
  State<AdminSellerProfilePage> createState() => _AdminSellerProfilePageState();
}

class _AdminSellerProfilePageState extends State<AdminSellerProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _chats = const [];
  List<Map<String, dynamic>> _searches = const [];
  List<Map<String, dynamic>> _payments = const [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await apiClient.getJson(
        '/api/admin/accounts/${widget.seller.id}/activity',
      );
      final shelf = await apiClient.getJson(
        '/api/admin/sellers/${widget.seller.id}/shelf',
      );
      if (!mounted) return;
      setState(() {
        _chats = (activity['chats'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _searches = (activity['searches'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _payments = (activity['payments'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _items = (shelf['items'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openChat(Map<String, dynamic> chat) async {
    final roomId = chat['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AdminChatSheet(roomId: roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userChats = _chats
        .where((chat) => chat['scope']?.toString() == 'shop_payment')
        .toList();
    final b2bChats = _chats
        .where((chat) => chat['scope']?.toString() == 'b2b')
        .toList();

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131926) : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.seller.shopName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _SellerHeader(seller: widget.seller),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              indicator: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: muted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900),
              tabs: const [
                Tab(text: 'Shelf'),
                Tab(text: 'User Chats'),
                Tab(text: 'B2B Chats'),
                Tab(text: 'History'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const PageSkeleton(cardCount: 5)
                : _error != null
                ? _AdminSellerEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load seller activity',
                    subtitle: _error!,
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _ShelfList(
                        items: _items,
                        onOpenFullShelf: () => push(
                          context,
                          AdminSellerShelfPage(seller: widget.seller),
                        ),
                      ),
                      _SellerChatAuditList(chats: userChats, onOpen: _openChat),
                      _SellerChatAuditList(chats: b2bChats, onOpen: _openChat),
                      _SellerHistoryList(
                        searches: _searches,
                        payments: _payments,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.seller});
  final AdminSellerEntry seller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: ClipOval(
                  child: ProductImageView(
                    imageUrl: seller.avatarUrl,
                    fallbackIcon: Icons.storefront_outlined,
                    fallbackColor: primary,
                  ),
                ),
              ),
              if (seller.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seller.owner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${seller.category} - ${seller.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _MiniPill(label: seller.status, color: success),
                    _MiniPill(label: seller.revenue, color: primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfList extends StatefulWidget {
  const _ShelfList({required this.items, required this.onOpenFullShelf});
  final List<Map<String, dynamic>> items;
  final VoidCallback onOpenFullShelf;

  @override
  State<_ShelfList> createState() => _ShelfListState();
}

class _ShelfListState extends State<_ShelfList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _AdminSellerEmpty(
        icon: Icons.inventory_2_outlined,
        title: 'No shelf items yet',
        subtitle: 'Seller products will appear here.',
        actionLabel: 'Open Shelf',
        onAction: widget.onOpenFullShelf,
      );
    }
    final filtered = widget.items.where((item) {
      final needle = _query.trim().toLowerCase();
      if (needle.isEmpty) return true;
      final text = [
        item['name'],
        item['category'],
        item['description'],
        item['stockQty'],
      ].whereType<Object>().join(' ').toLowerCase();
      return text.contains(needle);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SELLER DIGITAL SHELF',
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onOpenFullShelf,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open full view'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            boxShadow: shadowSm,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: primary),
              hintText: 'Search within seller shelf...',
              hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w700),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          const SizedBox(
            height: 260,
            child: _AdminSellerEmpty(
              icon: Icons.search_off_outlined,
              title: 'No matching shelf items',
              subtitle: 'Try a different product name or category.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 840
                  ? 4
                  : width >= 620
                  ? 3
                  : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) => _AdminShelfCard(
                  item: filtered[index],
                  onTap: widget.onOpenFullShelf,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _AdminShelfCard extends StatelessWidget {
  const _AdminShelfCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = item['stockQty'] as int? ?? 0;
    final active = item['isActive'] as bool? ?? true;
    final category = item['category']?.toString().trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      child: ProductImageView(
                        imageUrl: item['imageUrl']?.toString(),
                        fallbackIcon: Icons.shopping_bag_outlined,
                        fallbackColor: primary,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _MiniPill(
                      label: active ? 'ACTIVE' : 'HIDDEN',
                      color: active ? success : muted,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _MiniPill(label: '$stock left', color: primary),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']?.toString() ?? 'Shelf item',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _rupees(item['priceCents'] as int? ?? 0),
                      style: const TextStyle(
                        color: primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.notifications_active, size: 15),
                        label: const Text('SET STOCK ALERT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          category == null || category.isEmpty
                              ? Icons.category_outlined
                              : Icons.local_offer_outlined,
                          color: muted,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            category == null || category.isEmpty
                                ? 'No category'
                                : category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerChatAuditList extends StatelessWidget {
  const _SellerChatAuditList({required this.chats, required this.onOpen});
  final List<Map<String, dynamic>> chats;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return const _AdminSellerEmpty(
        icon: Icons.forum_outlined,
        title: 'No chats yet',
        subtitle: 'Conversations will appear here when this seller chats.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _AuditTile(
          icon: Icons.chat_bubble_outline,
          imageUrl: chat['avatarUrl']?.toString(),
          title: chat['title']?.toString() ?? 'Chat',
          subtitle:
              '${chat['lastMessage'] ?? 'Message'} - ${_adminSellerDate(chat['updatedAt'])}',
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => onOpen(chat),
        );
      },
    );
  }
}

class _SellerHistoryList extends StatelessWidget {
  const _SellerHistoryList({required this.searches, required this.payments});
  final List<Map<String, dynamic>> searches;
  final List<Map<String, dynamic>> payments;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ...payments.map((payment) => {
            'icon': Icons.account_balance_wallet_outlined,
            'title': _rupees(payment['grossCents'] as int? ?? 0),
            'subtitle':
                '${payment['status'] ?? 'payment'} - ${_adminSellerDate(payment['createdAt'])}',
          }),
      ...searches.map((search) => {
            'icon': Icons.search,
            'title': search['query']?.toString() ?? 'Search',
            'subtitle':
                '${search['surface'] ?? 'search'} - ${_adminSellerDate(search['createdAt'])}',
          }),
    ];
    if (rows.isEmpty) {
      return const _AdminSellerEmpty(
        icon: Icons.history_outlined,
        title: 'No seller history yet',
        subtitle: 'Payments and search history will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        return _AuditTile(
          icon: row['icon'] as IconData,
          title: row['title'].toString(),
          subtitle: row['subtitle'].toString(),
        );
      },
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: SizedBox(
        width: 42,
        height: 42,
        child: ClipOval(
          child: ProductImageView(
            imageUrl: imageUrl,
            fallbackIcon: icon,
            fallbackColor: primary,
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
      trailing: trailing,
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
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

class _AdminSellerEmpty extends StatelessWidget {
  const _AdminSellerEmpty({
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: muted.withOpacity(0.45), size: 46),
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
                icon: const Icon(Icons.open_in_new),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _rupees(int cents) {
  final rupees = cents / 100;
  return 'Rs ${rupees.toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
}

String _adminSellerDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Now';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
