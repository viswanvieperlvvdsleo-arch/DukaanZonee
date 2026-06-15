import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProductOverviewHeader(product: product),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: ink,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.price,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ShopAvatarButton(product: product),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(Icons.inventory_2_outlined, product.stock),
                      _InfoChip(Icons.category_outlined, product.badge),
                      if ((product.shopBlock ?? '').isNotEmpty)
                        _InfoChip(
                          Icons.location_city_outlined,
                          product.shopBlock!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader('Overview', ''),
                  const SizedBox(height: 12),
                  _OverviewCard(product: product),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          'Start self-checkout',
                          Icons.qr_code_scanner,
                          () => openProductCheckout(context, product),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader('Reviews', ''),
                  const SizedBox(height: 12),
                  _ReviewSummaryCard(product: product),
                  const SizedBox(height: 32),
                  _MoreFromShop(product: product),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductOverviewHeader extends StatelessWidget {
  const _ProductOverviewHeader({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 390,
      decoration: BoxDecoration(
        color: product.tint,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              child: ProductImageView(
                imageUrl: product.imageUrl,
                fallbackIcon: product.icon,
                fallbackIconSize: 150,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 48,
            child: GlassRoundIcon(
              icon: Icons.arrow_back,
              size: 40,
              iconSize: 20,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: 16,
            top: 104,
            child: GlassRoundIcon(
              icon: Icons.location_on,
              size: 40,
              iconSize: 20,
              iconColor: primary,
              onTap: () => openShopLocation(
                context,
                shopName: product.shop,
                mapUrl: product.shopMapUrl,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 48,
            child: FavoriteButton(product: product, size: 40, iconSize: 20),
          ),
        ],
      ),
    );
  }
}

class _ShopAvatarButton extends StatelessWidget {
  const _ShopAvatarButton({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => push(
        context,
        MerchantProfilePage(shopName: product.shop, shopId: product.shopId),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primary.withValues(alpha: .1),
            child: ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: ProductImageView(
                  imageUrl: product.shopAvatarUrl,
                  fallbackIcon: Icons.storefront,
                  fallbackIconSize: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 74,
            child: Text(
              product.shop,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: primary),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final description = product.description?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFF2F5)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description?.isNotEmpty == true
                ? description!
                : 'This product is live from ${product.shop}. Seller details, stock, and checkout are connected to the current shelf database.',
            style: const TextStyle(
              color: ink,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((product.shopAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.place_outlined, color: primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.shopAddress!,
                    style: const TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductReviewsResult>(
      future: reviewService.getProductReviews(product.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ReviewInfoCard(
            title: 'Reviews unavailable',
            subtitle: 'Check the backend server, then open reviews again.',
            onTap: () => push(context, ReviewsPage(product: product)),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data!;
        final firstReview = reviews.reviews.isNotEmpty
            ? reviews.reviews.first.comment
            : 'No reviews yet. Write the first real product review.';

        return _ReviewInfoCard(
          title: reviews.count == 0
              ? 'Write a review'
              : '${reviews.averageRating.toStringAsFixed(1)} rating from ${reviews.count} review${reviews.count == 1 ? '' : 's'}',
          subtitle: firstReview,
          onTap: () => push(context, ReviewsPage(product: product)),
        );
      },
    );
  }
}

class _ReviewInfoCard extends StatelessWidget {
  const _ReviewInfoCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
          border: Border.all(color: muted.withValues(alpha: .1)),
          boxShadow: shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.rate_review_outlined, color: primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: muted,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class _MoreFromShop extends StatelessWidget {
  const _MoreFromShop({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: discoveryService.searchProducts(product.shop),
      builder: (context, snapshot) {
        final products = (snapshot.data ?? const <Product>[])
            .where((item) => item.id != product.id && item.shop == product.shop)
            .toList();
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('More from this shop', 'View shop'),
            const SizedBox(height: 16),
            SizedBox(
              height: 290,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = products[index];
                  return PremiumProductCard(
                    product: item,
                    onTap: () =>
                        push(context, ProductDetailPage(product: item)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
