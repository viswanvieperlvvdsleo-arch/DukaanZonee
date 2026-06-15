import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key, required this.query, required this.role});
  final String query;
  final Role role;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late Future<List<Product>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = discoveryService.searchProducts(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: MainHeader(
        role: widget.role,
        onExit: () => Navigator.of(context).maybePop(),
      ),
      body: FutureBuilder<List<Product>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PageSkeleton();
          }

          if (snapshot.hasError) {
            return _buildEmptyState(
              Icons.cloud_off_rounded,
              'Could not search',
              'Check that the DukaanZone backend is running.',
            );
          }

          final results = snapshot.data ?? const <Product>[];
          return results.isEmpty
              ? _buildEmptyState(
                  Icons.search_off_rounded,
                  'No matches found',
                  'Try a product, shop, category, block, or address.',
                )
              : _buildResultsList(results);
        },
      ),
      floatingActionButton: widget.role == Role.user
          ? GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: widget.role == Role.user
          ? NavigationBar(
              selectedIndex: 0,
              height: 72,
              onDestinationSelected: (i) => Navigator.of(context).maybePop(),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_scanner, color: Colors.transparent),
                  label: 'Scan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: muted.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(List<Product> results) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search Results',
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '"${widget.query}"',
                  style: const TextStyle(
                    color: primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }
        return _SearchResultCard(
          product: results[index - 1],
          role: widget.role,
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.product, required this.role});
  final Product product;
  final Role role;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: role == Role.seller
              ? () {
                  push(
                    context,
                    B2BChatRoomPage(
                      merchant: {
                        'name': product.shop,
                        'owner': 'Shop Owner',
                        'specialty': 'Wholesale Supply',
                        'avatarColor': Colors.blue,
                      },
                    ),
                  );
                }
              : () => push(context, ProductDetailPage(product: product)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: product.tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ProductImageView(
                            imageUrl: product.imageUrl,
                            fallbackIcon: product.icon,
                            fallbackIconSize: 52,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        top: 4,
                        child: GlassRoundIcon(
                          icon: Icons.location_on,
                          size: 24,
                          iconSize: 12,
                          iconColor: primary,
                          onTap: () {
                            globalMapState.value = MapState(
                              mode: MapMode.routing,
                              destinationName: product.shop,
                            );
                            if (role == Role.seller) {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            }
                          },
                        ),
                      ),
                      if (role == Role.seller)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GlassRoundIcon(
                            icon: Icons.storefront_outlined,
                            size: 24,
                            iconSize: 12,
                            iconColor: primary,
                            onTap: () {
                              push(
                                context,
                                MerchantProfilePage(shopName: product.shop),
                              );
                            },
                          ),
                        )
                      else
                        Positioned(
                          right: 4,
                          top: 4,
                          child: FavoriteButton(
                            product: product,
                            size: 24,
                            iconSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (product.badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.badge.toUpperCase(),
                            style: const TextStyle(
                              color: primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 12, color: muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.shop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.stock,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              product.price,
                              style: const TextStyle(
                                color: success,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (role == Role.seller)
                            SizedBox(
                              height: 36,
                              width: 80,
                              child: GradientButton(
                                'Chat',
                                Icons.chat_bubble_outline_rounded,
                                () {
                                  push(
                                    context,
                                    B2BChatRoomPage(
                                      merchant: {
                                        'name': product.shop,
                                        'owner': 'Shop Owner',
                                        'specialty': 'Wholesale Supply',
                                        'avatarColor': Colors.blue,
                                      },
                                    ),
                                  );
                                },
                                compact: true,
                              ),
                            )
                          else
                            SizedBox(
                              height: 36,
                              width: 80,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
