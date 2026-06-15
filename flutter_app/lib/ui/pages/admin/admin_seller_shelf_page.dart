import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminSellerShelfPage extends StatefulWidget {
  const AdminSellerShelfPage({super.key, required this.seller});
  final AdminSellerEntry seller;

  @override
  State<AdminSellerShelfPage> createState() => _AdminSellerShelfPageState();
}

class _AdminSellerShelfPageState extends State<AdminSellerShelfPage> {
  bool _isLoading = true;
  List<_ShelfProduct> _products = [];

  @override
  void initState() {
    super.initState();
    _loadShelf();
    return;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _products = [
          _ShelfProduct('p1', 'Amul Butter 500g', '₹265', Icons.egg_alt, const Color(0xFFFFF3E0)),
          _ShelfProduct('p2', 'Tata Salt 1kg', '₹20', Icons.grain, const Color(0xFFE3F2FD)),
          _ShelfProduct('p3', 'Surf Excel 2kg', '₹310', Icons.local_laundry_service, const Color(0xFFE8F5E9)),
          _ShelfProduct('p4', 'Colgate Toothpaste', '₹119', Icons.clean_hands, const Color(0xFFF3E5F5)),
          _ShelfProduct('p5', 'Dettol Soap', '₹55', Icons.soap, const Color(0xFFE0F7FA)),
          _ShelfProduct('p6', 'Maggi Noodles', '₹28', Icons.ramen_dining, const Color(0xFFFFF8E1)),
        ];
        _isLoading = false;
      });
    });
  }

  Future<void> _loadShelf() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiClient.getJson(
        '/api/admin/sellers/${widget.seller.id}/shelf',
      );
      final products = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final priceCents = item['priceCents'] as int? ?? 0;
            return _ShelfProduct(
              item['id']?.toString() ?? '',
              item['name']?.toString() ?? 'Shelf item',
              'Rs ${(priceCents / 100).toStringAsFixed(priceCents % 100 == 0 ? 0 : 2)}',
              Icons.shopping_bag_outlined,
              const Color(0xFFE8F5E9),
            );
          })
          .toList();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendWarning(BuildContext context, _ShelfProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Send Warning', style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Text(
          'Send a warning to the seller about "${product.name}"?\n\nIf they do not comply, this account may be suspended.',
          style: const TextStyle(color: muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('⚠️  Warning sent for "${product.name}"'),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ));
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Warning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(BuildContext context, _ShelfProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Text(
          'Permanently delete "${product.name}" from this shelf?\n\nThis hides it immediately from all users.',
          style: const TextStyle(color: muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _products.removeWhere((p) => p.id == product.id));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('🗑️  "${product.name}" removed from shelf'),
                backgroundColor: Colors.redAccent.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ));
            },
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.seller;

    final statusColor = s.status == 'Active'
        ? success
        : s.status == 'Suspended'
            ? Colors.redAccent
            : Colors.orange;

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      body: CustomScrollView(
        slivers: [
          // ── Seller hero ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 196,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF131926) : Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : ink),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '${s.shopName}\'s Shelf',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17,
                  color: isDark ? Colors.white : ink),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary.withOpacity(0.14), primary.withOpacity(0.03)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.store, color: primary, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${s.owner} • ${s.category}',
                                  style: const TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 5),
                              Row(children: [
                                if (s.rating > 0) ...[
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 3),
                                  Text('${s.rating}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  const SizedBox(width: 10),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(s.status,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(s.revenue,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: success, fontSize: 16)),
                            const Text('Revenue',
                                style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Kicker row ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Kicker('SHELF PRODUCTS'),
                  const Spacer(),
                  if (!_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_products.length} items',
                        style: const TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Grid ─────────────────────────────────────────────────────────
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ProductGridSkeleton(count: 4),
              ),
            )
          else if (_products.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: muted),
                    SizedBox(height: 12),
                    Text('No products on shelf',
                        style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _AdminProductCard(
                    product: _products[i],
                    onWarn: () => _sendWarning(ctx, _products[i]),
                    onDelete: () => _deleteProduct(ctx, _products[i]),
                  ),
                  childCount: _products.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _AdminProductCard extends StatelessWidget {
  const _AdminProductCard({
    required this.product,
    required this.onWarn,
    required this.onDelete,
  });
  final _ShelfProduct product;
  final VoidCallback onWarn;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: product.tint,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Center(
                child: Icon(product.icon, size: 58, color: ink.withOpacity(0.42)),
              ),
            ),
          ),
          // Name + price
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, height: 1.2)),
                const SizedBox(height: 3),
                Text(product.price,
                    style: const TextStyle(color: success, fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
          ),
          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onWarn,
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                          SizedBox(width: 4),
                          Text('Warn', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
                          SizedBox(width: 4),
                          Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _ShelfProduct {
  const _ShelfProduct(this.id, this.name, this.price, this.icon, this.tint);
  final String id, name, price;
  final IconData icon;
  final Color tint;
}
