import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class UserSavedPage extends StatefulWidget {
  const UserSavedPage({super.key});

  @override
  State<UserSavedPage> createState() => _UserSavedPageState();
}

class _UserSavedPageState extends State<UserSavedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Product> _savedItems = const [];
  bool _loadingSaved = true;
  String? _savedError;
  bool _loadingGroups = true;
  String? _groupsError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSavedItems();
    _loadSavedGroups();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedItems() async {
    setState(() {
      _loadingSaved = true;
      _savedError = null;
    });
    try {
      final products = await discoveryService.getSavedProducts();
      if (!mounted) return;
      setState(() {
        _savedItems = products;
        _loadingSaved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSaved = false;
        _savedError = 'Could not load saved items.';
      });
    }
  }

  Future<void> _unsaveItem(Product product) async {
    final previous = _savedItems;
    setState(
      () => _savedItems = [
        for (final item in _savedItems)
          if (item.id != product.id) item,
      ],
    );
    try {
      await discoveryService.unsaveProduct(product.id);
    } catch (_) {
      if (mounted) {
        setState(() => _savedItems = previous);
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} removed from saved list.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSavedGroups() async {
    setState(() {
      _loadingGroups = true;
      _groupsError = null;
    });
    try {
      final groups = await savedGroupService.listGroups();
      globalSavedGroups.value = groups;
      if (!mounted) return;
      setState(() => _loadingGroups = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGroups = false;
        _groupsError = 'Could not load saved groups.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ─────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
              child: PageTitle(
                'Your Saved Favourites',
                'Neighbourhood picks, curated and waiting.',
              ),
            ),

            // ── Tab Bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '♥  Saved Items'),
                    Tab(text: '📦  Group Orders'),
                  ],
                ),
              ),
            ),

            // ── Tab Content ────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _SavedItemsTab(
                    savedItems: _savedItems,
                    loading: _loadingSaved,
                    error: _savedError,
                    onRetry: _loadSavedItems,
                    onUnsave: _unsaveItem,
                  ),
                  _GroupOrdersTab(
                    loading: _loadingGroups,
                    error: _groupsError,
                    onRetry: _loadSavedGroups,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TAB 1 — Individual Saved Items
// ─────────────────────────────────────────────────────────────
class _SavedItemsTab extends StatelessWidget {
  const _SavedItemsTab({
    required this.savedItems,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onUnsave,
  });
  final List<Product> savedItems;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final void Function(Product) onUnsave;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: muted),
              const SizedBox(height: 14),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (savedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 64,
                color: Color(0xFFE2E8F0),
              ),
              SizedBox(height: 16),
              Text(
                'No saved items yet.',
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      itemCount: savedItems.length,
      itemBuilder: (ctx, i) {
        final product = savedItems[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SavedItemCard(
            product: product,
            onUnsave: () => onUnsave(product),
            onAddToCart: () => push(ctx, CheckoutPage(product: product)),
            onTap: () => push(ctx, ProductDetailPage(product: product)),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TAB 2 — Group Orders
// ─────────────────────────────────────────────────────────────
class _GroupOrdersTab extends StatefulWidget {
  const _GroupOrdersTab({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<_GroupOrdersTab> createState() => _GroupOrdersTabState();
}

class _GroupOrdersTabState extends State<_GroupOrdersTab> {
  final Set<String> _expandedIds = {};

  // Local qty overrides per group: groupId → {productId → qty}
  final Map<String, Map<String, int>> _qtyOverrides = {};

  int _qtyFor(SavedGroup g, String productId) {
    return _qtyOverrides[g.id]?[productId] ?? g.items[productId] ?? 0;
  }

  Future<void> _adjustQty(SavedGroup g, String productId, int delta) async {
    final previous = Map<String, int>.from(g.items);
    setState(() {
      _qtyOverrides.putIfAbsent(g.id, () => Map<String, int>.from(g.items));
      final current = _qtyOverrides[g.id]![productId] ?? 0;
      final next = (current + delta).clamp(0, 99);
      if (next == 0) {
        _qtyOverrides[g.id]!.remove(productId);
      } else {
        _qtyOverrides[g.id]![productId] = next;
      }
    });
    HapticFeedback.selectionClick();
    final nextItems = Map<String, int>.from(_qtyOverrides[g.id] ?? g.items);
    if (nextItems.isEmpty) {
      await _deleteGroup(g);
      return;
    }
    try {
      final updated = await savedGroupService.updateGroup(g, items: nextItems);
      _replaceGroup(updated);
    } catch (_) {
      _qtyOverrides[g.id] = previous;
      if (mounted) setState(() {});
    }
  }

  Future<void> _removeItemFromGroup(SavedGroup g, String productId) async {
    final previousGroups = globalSavedGroups.value;
    final nextItems = Map<String, int>.from(_qtyOverrides[g.id] ?? g.items)
      ..remove(productId);
    _qtyOverrides[g.id] = nextItems;
    globalSavedGroups.value = [
      for (final group in previousGroups)
        if (group.id == g.id && nextItems.isNotEmpty)
          SavedGroup(
            id: g.id,
            name: g.name,
            shopName: g.shopName,
            shopId: g.shopId,
            createdAt: g.createdAt,
            items: nextItems,
            productDetails: g.productDetails,
          )
        else if (group.id != g.id)
          group,
    ];
    if (nextItems.isEmpty) {
      _expandedIds.remove(g.id);
    }
    try {
      if (nextItems.isEmpty) {
        await savedGroupService.deleteGroup(g.id);
      } else {
        final updated = await savedGroupService.updateGroup(
          g,
          items: nextItems,
        );
        _replaceGroup(updated);
      }
    } catch (_) {
      globalSavedGroups.value = previousGroups;
      _qtyOverrides.remove(g.id);
    }
  }

  Future<void> _deleteGroup(SavedGroup g) async {
    final previous = globalSavedGroups.value;
    final groups = List<SavedGroup>.from(globalSavedGroups.value)
      ..removeWhere((x) => x.id == g.id);
    globalSavedGroups.value = [...groups];
    _expandedIds.remove(g.id);
    _qtyOverrides.remove(g.id);
    setState(() {});
    try {
      await savedGroupService.deleteGroup(g.id);
    } catch (_) {
      globalSavedGroups.value = previous;
    }
  }

  void _replaceGroup(SavedGroup updated) {
    globalSavedGroups.value = [
      for (final group in globalSavedGroups.value)
        if (group.id == updated.id) updated else group,
    ];
    _qtyOverrides.remove(updated.id);
    if (mounted) setState(() {});
  }

  void _renameGroup(SavedGroup g) {
    final ctrl = TextEditingController(text: g.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Group',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) {
                final previous = globalSavedGroups.value;
                try {
                  final updated = await savedGroupService.updateGroup(
                    g,
                    name: n,
                  );
                  _replaceGroup(updated);
                } catch (_) {
                  globalSavedGroups.value = previous;
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _buyGroup(BuildContext ctx, SavedGroup g) {
    final overrides = _qtyOverrides[g.id] ?? Map<String, int>.from(g.items);
    final products = g.products;
    final firstProduct = products.isNotEmpty ? products.first : null;
    final shop = Shop(
      g.shopName,
      firstProduct?.shopBlock ?? '',
      firstProduct?.shopCategory ?? 'Local shop',
      ((firstProduct?.shopRating ?? 0) == 0
              ? 4.8
              : firstProduct?.shopRating ?? 4.8)
          .toStringAsFixed(1),
      '${firstProduct?.shopFollowerCount ?? 0}',
      const LatLng(0, 0),
      id: g.shopId ?? firstProduct?.shopId,
      address: firstProduct?.shopAddress,
      paymentQrPayload: firstProduct?.paymentQrPayload,
      upiId: firstProduct?.upiId,
      avatarUrl: firstProduct?.shopAvatarUrl,
      mapUrl: firstProduct?.shopMapUrl,
      followerCount: firstProduct?.shopFollowerCount ?? 0,
      ratingValue: firstProduct?.shopRating ?? 0,
      isFollowing: firstProduct?.isFollowingShop ?? false,
    );

    push(
      ctx,
      SmartScanCheckoutPage(
        shop: shop,
        color: primary,
        prefilledCart: overrides,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: muted),
              const SizedBox(height: 14),
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<List<SavedGroup>>(
      valueListenable: globalSavedGroups,
      builder: (ctx, groups, _) {
        if (groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Color(0xFFE2E8F0),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No group orders saved yet.',
                    style: TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add items in the shop checkout,\nthen tap the bookmark 🔖 to save.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          itemCount: groups.length,
          itemBuilder: (ctx, i) => _buildGroupCard(ctx, groups[i]),
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext ctx, SavedGroup g) {
    final isExpanded = _expandedIds.contains(g.id);
    // Always use app primary color — no random off-palette colors
    const color = primary;

    // Compute effective total from overrides
    double effectiveTotal = 0;
    final overrides = _qtyOverrides[g.id] ?? g.items;
    for (final entry in overrides.entries) {
      if (entry.value > 0) {
        final p =
            g.productDetails[entry.key] ??
            catalogProducts.firstWhere(
              (p) => p.id == entry.key,
              orElse: () => catalogProducts.first,
            );
        final raw = p.price.replaceAll(RegExp(r'[₹,]'), '');
        effectiveTotal += (double.tryParse(raw) ?? 0) * entry.value;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExpanded
              ? color.withValues(alpha: .3)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Group Header ──────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedIds.remove(g.id);
              } else {
                _expandedIds.add(g.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: .2),
                          color.withValues(alpha: .08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.shopping_bag_rounded,
                      color: color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.shopName,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${g.items.length} items',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${effectiveTotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Column(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 4),
                      // More options
                      GestureDetector(
                        onTap: () => _showGroupOptions(ctx, g),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Items ────────────────────────────────────
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ...g.items.keys.map((productId) {
              final prod =
                  g.productDetails[productId] ??
                  catalogProducts.firstWhere(
                    (p) => p.id == productId,
                    orElse: () => catalogProducts.first,
                  );
              final qty = _qtyFor(g, productId);
              return _buildGroupItemRow(g, prod, qty, color);
            }),
            const SizedBox(height: 8),

            // ── Buy Button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _buyGroup(ctx, g),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 20,
                  ),
                  label: Text(
                    'Buy Now  •  ₹${effectiveTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupItemRow(SavedGroup g, Product prod, int qty, Color color) {
    final rawPrice = prod.price.replaceAll(RegExp(r'[₹,]'), '');
    final unitPrice = double.tryParse(rawPrice) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: prod.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(prod.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Name + subtotal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  qty > 0
                      ? '${prod.price}  ×$qty = ₹${(unitPrice * qty).toStringAsFixed(0)}'
                      : prod.price,
                  style: TextStyle(
                    color: qty > 0 ? color : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // ─── Qty controls ───────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (qty > 0) ...[
                _SmallCtrlBtn(
                  icon: qty == 1 ? Icons.remove_rounded : Icons.remove_rounded,
                  color: muted, // ← palette muted, not orange
                  onTap: () => _adjustQty(g, prod.id, -1),
                ),
                SizedBox(
                  width: 28,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      '$qty',
                      key: ValueKey(qty),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
              _SmallCtrlBtn(
                icon: Icons.add_rounded,
                color: color,
                onTap: () => _adjustQty(g, prod.id, 1),
              ),
              const SizedBox(width: 4),
              // Remove item from saved group — heart icon ("unsave")
              GestureDetector(
                onTap: () => _removeItemFromGroup(g, prod.id),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2), // pale rose, palette-safe
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFCDD2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded, // "unsave" heart icon
                    color: Color(0xFFE57373), // soft rose, not glaring red
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGroupOptions(BuildContext ctx, SavedGroup g) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF4FF),
                child: Icon(Icons.edit_rounded, color: primary),
              ),
              title: const Text(
                'Rename Group',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _renameGroup(g);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red),
              ),
              title: const Text(
                'Delete Group',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteGroup(g);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${g.name}" deleted'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _SmallCtrlBtn extends StatelessWidget {
  const _SmallCtrlBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Individual Saved Item Card (unchanged design, same as before)
// ─────────────────────────────────────────────────────────────
class _SavedItemCard extends StatelessWidget {
  const _SavedItemCard({
    required this.product,
    required this.onUnsave,
    required this.onAddToCart,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onUnsave;
  final VoidCallback onAddToCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: shadowSm,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: product.tint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ProductImageView(
                    imageUrl: product.imageUrl,
                    fallbackIcon: product.icon,
                    fallbackIconSize: 40,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: ink,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product.price,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.shop,
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFFBBF24), size: 20),
                    SizedBox(width: 4),
                    Text(
                      '4.5/5',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: onUnsave,
                      icon: const Icon(Icons.favorite, color: Colors.redAccent),
                      tooltip: 'Unsave',
                    ),
                    IconButton(
                      onPressed: () {
                        globalMapState.value = MapState(
                          mode: MapMode.routing,
                          destinationName: product.shop,
                        );
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: const Icon(Icons.location_on, color: primary),
                      tooltip: 'Navigate to Shop',
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      width: 90,
                      child: GradientButton(
                        'Buy',
                        Icons.shopping_cart,
                        onAddToCart,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
