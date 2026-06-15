import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  late Future<DiscoverySnapshot> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = discoveryService.getHome();
  }

  void _reload() {
    setState(() {
      _homeFuture = discoveryService.getHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiscoverySnapshot>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PageSkeleton();
        }

        if (snapshot.hasError) {
          return AppPage(
            maxWidth: 720,
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.cloud_off_outlined, size: 64, color: muted),
              const SizedBox(height: 18),
              const PageTitle(
                'Live shelf unavailable',
                'Could not reach the DukaanZone backend right now.',
              ),
              const SizedBox(height: 16),
              GradientButton('Retry', Icons.refresh, _reload),
            ],
          );
        }

        final data = snapshot.data!;
        final featured = data.featured;

        if (data.products.isEmpty) {
          return AppPage(
            maxWidth: 720,
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.storefront_outlined, size: 64, color: muted),
              const SizedBox(height: 18),
              const PageTitle(
                'No live shelf items yet',
                'Seller products added to the database will appear here.',
              ),
              const SizedBox(height: 16),
              GradientButton('Refresh', Icons.refresh, _reload),
            ],
          );
        }

        return AppPage(
          maxWidth: 1180,
          children: [
            if (featured.isNotEmpty) ...[
              const Kicker('SPONSORED LIVE PICKS'),
              const SizedBox(height: 14),
              PromotedProductCarousel(products: featured),
              const SizedBox(height: 26),
            ],
            const Kicker('LIVE NEIGHBORHOOD SHELF'),
            const SizedBox(height: 14),
            SectionHeader('Trending Now', '${data.products.length} live'),
            const SizedBox(height: 14),
            ProductCardGrid(products: data.products),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

class PromotedProductCarousel extends StatefulWidget {
  const PromotedProductCarousel({super.key, required this.products});

  final List<Product> products;

  @override
  State<PromotedProductCarousel> createState() =>
      _PromotedProductCarouselState();
}

class _PromotedProductCarouselState extends State<PromotedProductCarousel> {
  late final PageController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .92);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PromotedProductCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.length != widget.products.length) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.products.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final next = (_controller.page?.round() ?? 0) + 1;
      _controller.animateToPage(
        next % widget.products.length,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.products.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == widget.products.length - 1 ? 0 : 14,
            ),
            child: _PromotedProductSlide(product: widget.products[index]),
          );
        },
      ),
    );
  }
}

class _PromotedProductSlide extends StatelessWidget {
  const _PromotedProductSlide({required this.product});

  final Product product;

  void _trackClick() {
    final promotionId = product.promotionId;
    if (promotionId == null || promotionId.isEmpty) return;
    unawaited(discoveryService.trackPromotionClick(promotionId));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(34),
      onTap: () {
        _trackClick();
        push(context, ProductDetailPage(product: product));
      },
      child: Container(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(34),
          boxShadow: shadowLg,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF33465A), Color(0xFF0B0F17)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: ProductImageView(
                imageUrl: product.imageUrl,
                fallbackIcon: product.icon,
                fallbackColor: Colors.white.withOpacity(.52),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.12),
                      Colors.black.withOpacity(.78),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BadgeText('SPONSORED'),
                  const SizedBox(height: 12),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.price,
                    style: const TextStyle(
                      color: success,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sold by ${product.shop}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 124,
                      child: FrostedBuyButton(
                        onTap: () {
                          _trackClick();
                          openProductCheckout(context, product);
                        },
                      ),
                    ),
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
