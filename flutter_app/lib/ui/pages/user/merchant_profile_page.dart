import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({
    super.key,
    required this.shopName,
    this.shopId,
    this.role = Role.user,
  });

  final String shopName;
  final String? shopId;
  final Role role;

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  late Future<List<Product>> _productsFuture;
  late Future<Shop?> _shopFuture;
  final TextEditingController _searchCtrl = TextEditingController();
  Shop? _shop;
  bool _isFollowing = false;
  bool _isFollowBusy = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _productsFuture = discoveryService.searchProducts(widget.shopName);
    _shopFuture = _loadShop();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Shop?> _loadShop() async {
    if ((widget.shopId ?? '').trim().isNotEmpty) {
      final shop = await shopProfileService.getShop(widget.shopId!);
      _applyShop(shop);
      return shop;
    }

    final products = await _productsFuture;
    final matching = products.where((p) => p.shop == widget.shopName).toList();
    if (matching.isEmpty || matching.first.shopId == null) return null;

    try {
      final shop = await shopProfileService.getShop(matching.first.shopId!);
      _applyShop(shop);
      return shop;
    } catch (_) {
      final shop = _shopFromProduct(matching.first);
      _applyShop(shop);
      return shop;
    }
  }

  void _applyShop(Shop shop) {
    _shop = shop;
    _isFollowing = shop.isFollowing;
  }

  Shop _shopFromProduct(Product product) {
    return Shop(
      product.shop,
      product.shopBlock ?? '',
      product.shopCategory ?? 'Local shop',
      product.shopRating.toStringAsFixed(1),
      '${product.shopFollowerCount}',
      const LatLng(0, 0),
      id: product.shopId,
      address: product.shopAddress,
      paymentQrPayload: product.paymentQrPayload,
      upiId: product.upiId,
      avatarUrl: product.shopAvatarUrl,
      mapUrl: product.shopMapUrl,
      followerCount: product.shopFollowerCount,
      ratingValue: product.shopRating,
      isFollowing: product.isFollowingShop,
    );
  }

  Future<void> _toggleFollow() async {
    final shopId = _shop?.id;
    if (shopId == null || _isFollowBusy) return;

    setState(() => _isFollowBusy = true);
    try {
      final updated = _isFollowing
          ? await shopProfileService.unfollowShop(shopId)
          : await shopProfileService.followShop(shopId);
      if (!mounted) return;
      setState(() {
        _shop = updated;
        _isFollowing = updated.isFollowing;
        _shopFuture = Future.value(updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowing
                ? 'You are now following ${updated.name}'
                : 'Unfollowed ${updated.name}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isFollowBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _productsFuture = discoveryService.searchProducts(widget.shopName);
            _shopFuture = _loadShop();
          });
          await Future.wait([_productsFuture, _shopFuture]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
          children: [
            FutureBuilder<Shop?>(
              future: _shopFuture,
              builder: (context, snapshot) {
                final shop = _shop ?? snapshot.data;
                return _ShopHeader(
                  shopName: shop?.name ?? widget.shopName,
                  avatarUrl: shop?.avatarUrl,
                  followerCount: shop?.followerCount ?? 0,
                  rating: shop?.ratingValue ?? 0,
                  address: shop?.address,
                  isFollowing: _isFollowing,
                  isFollowBusy: _isFollowBusy,
                  onFollow: _toggleFollow,
                  onChat: shop == null
                      ? null
                      : () => push(
                          context,
                          ShopPaymentChatPage(shop: shop, color: primary),
                        ),
                  onLocation: () => openShopLocation(
                    context,
                    shopName: shop?.name ?? widget.shopName,
                    mapUrl: shop?.mapUrl,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const SectionHeader('Digital Shelf', ''),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: shadowSm,
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: primary, size: 20),
                  hintText: 'Search within this shelf...',
                  border: InputBorder.none,
                  hintStyle: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear, color: muted, size: 18),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const _ShelfMessage(
                    icon: Icons.cloud_off_outlined,
                    text: 'Could not load this shop shelf.',
                  );
                }

                final lowerQuery = _query.toLowerCase();
                final products = (snapshot.data ?? const <Product>[])
                    .where((p) => p.shop == widget.shopName)
                    .where((p) => p.name.toLowerCase().contains(lowerQuery))
                    .toList();

                if (products.isEmpty) {
                  return const _ShelfMessage(
                    icon: Icons.search_off_outlined,
                    text: 'No products found matching your search.',
                  );
                }

                return _ShelfProductGrid(products: products, role: widget.role);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.shopName,
    required this.avatarUrl,
    required this.followerCount,
    required this.rating,
    required this.address,
    required this.isFollowing,
    required this.isFollowBusy,
    required this.onFollow,
    required this.onChat,
    required this.onLocation,
  });

  final String shopName;
  final String? avatarUrl;
  final int followerCount;
  final double rating;
  final String? address;
  final bool isFollowing;
  final bool isFollowBusy;
  final VoidCallback onFollow;
  final VoidCallback? onChat;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: .08),
            border: Border.all(color: primary.withValues(alpha: .18), width: 2),
          ),
          child: ClipOval(
            child: ProductImageView(
              imageUrl: avatarUrl,
              fallbackIcon: Icons.storefront,
              fallbackIconSize: 52,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          shopName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatFollowers(followerCount)} Followers • ${rating > 0 ? rating.toStringAsFixed(1) : 'No'} Rating',
          style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            (address ?? '').isEmpty ? 'Sourcing fresh food daily.' : address!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isFollowBusy ? null : onFollow,
                icon: isFollowBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isFollowing ? Icons.check : Icons.add, size: 18),
                label: Text(
                  isFollowing ? 'Following' : 'Follow Shop',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? success : primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: isFollowing ? 0 : 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RoundActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: onChat ?? () {},
              tooltip: 'Chat with shop',
            ),
            const SizedBox(width: 12),
            _RoundActionButton(
              icon: Icons.location_on_outlined,
              onTap: onLocation,
              tooltip: 'Open shop location',
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TapScale(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: shadowSm,
          ),
          child: Icon(icon, color: primary, size: 24),
        ),
      ),
    );
  }
}

class _ShelfProductGrid extends StatelessWidget {
  const _ShelfProductGrid({required this.products, required this.role});

  final List<Product> products;
  final Role role;

  bool _isSaved(Product product) {
    return globalSavedGroups.value.any(
      (group) => group.items.containsKey(product.id),
    );
  }

  Future<void> _toggleSaved(BuildContext context, Product product) async {
    final groups = List<SavedGroup>.from(globalSavedGroups.value);
    final savedIndex = groups.indexWhere(
      (group) => group.items.containsKey(product.id),
    );

    if (savedIndex != -1) {
      final previous = List<SavedGroup>.from(groups);
      groups[savedIndex].items.remove(product.id);
      if (groups[savedIndex].items.isEmpty) {
        groups.removeAt(savedIndex);
      }
      globalSavedGroups.value = [...groups];
      try {
        await discoveryService.unsaveProduct(product.id);
      } catch (_) {
        globalSavedGroups.value = previous;
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} removed from saved items'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shopIndex = groups.indexWhere(
      (group) => group.shopName == product.shop,
    );
    if (shopIndex == -1) {
      groups.add(
        SavedGroup(
          id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
          name: '${product.shop} Picks',
          shopName: product.shop,
          items: {product.id: 1},
        ),
      );
    } else {
      groups[shopIndex].items[product.id] = 1;
    }
    globalSavedGroups.value = [...groups];
    try {
      await discoveryService.saveProduct(product.id);
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 18,
            childAspectRatio: constraints.maxWidth > 720 ? .58 : .43,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: role == Role.seller
                    ? null
                    : () => push(context, ProductDetailPage(product: product)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: ProductImageView(
                                  imageUrl: product.imageUrl,
                                  fallbackIcon: product.icon,
                                  fallbackIconSize: 92,
                                ),
                              ),
                            ),
                            if (role == Role.user)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: ValueListenableBuilder<List<SavedGroup>>(
                                  valueListenable: globalSavedGroups,
                                  builder: (context, _, __) {
                                    final saved = _isSaved(product);
                                    return TapScale(
                                      onTap: () {
                                        _toggleSaved(context, product);
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: shadowSm,
                                        ),
                                        child: Icon(
                                          saved
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: saved
                                              ? Colors.redAccent
                                              : primary,
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.04,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sold by ${product.shop}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.price,
                        style: const TextStyle(
                          color: success,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.stock,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (role == Role.user)
                            SizedBox(
                              height: 40,
                              width: 76,
                              child: GradientButton(
                                'Buy',
                                Icons.shopping_cart,
                                () => openProductCheckout(context, product),
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ShelfMessage extends StatelessWidget {
  const _ShelfMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: muted.withValues(alpha: .4)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatFollowers(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}m';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}
