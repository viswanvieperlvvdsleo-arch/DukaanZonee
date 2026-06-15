import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.role});
  final Role role;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late Future<List<Product>> _suggestionsFuture;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = discoveryService.searchProducts('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    if (query.trim().isEmpty) return;
    push(context, SearchResultsPage(query: query.trim(), role: widget.role));
  }

  void _goBack() {
    globalActiveTabOverride.value = 0;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.role == Role.admin
        ? 'Search shops, users, listings...'
        : widget.role == Role.seller
        ? 'Search products or order IDs...'
        : 'Search milk, bread, earbuds...';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (val) => setState(() => _query = val),
            onSubmitted: _submitSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: primary),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: muted),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        body: widget.role == Role.seller
            ? AppPage(
                children: [
                  const Kicker('B2B COLLABORATION PARTNERS'),
                  const SizedBox(height: 14),
                  for (final product in catalogProducts)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: shadowSm,
                      ),
                      child: ListTile(
                        onTap: () {
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
                        leading: CircleAvatar(
                          backgroundColor: product.tint,
                          child: Icon(product.icon, color: ink),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Partner: ${product.shop}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.directions_outlined,
                                color: primary,
                              ),
                              onPressed: () {
                                globalMapState.value = MapState(
                                  mode: MapMode.routing,
                                  destinationName: product.shop,
                                );
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: primary,
                              ),
                              onPressed: () {
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
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : FutureBuilder<List<Product>>(
                future: _suggestionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const PageSkeleton();
                  }

                  final products = snapshot.data ?? const <Product>[];
                  final tokens = products
                      .map((product) => product.badge)
                      .where((label) => label.trim().isNotEmpty)
                      .toSet()
                      .take(6)
                      .toList();

                  return AppPage(
                    children: [
                      const Kicker('TRENDING NEAR YOU'),
                      const SizedBox(height: 14),
                      if (snapshot.hasError)
                        _buildSearchMessage(
                          Icons.cloud_off_outlined,
                          'Backend unavailable',
                          'Search will work after the local server is running.',
                        )
                      else if (products.isEmpty)
                        _buildSearchMessage(
                          Icons.search_off_outlined,
                          'No live shelf items yet',
                          'Seller products will appear here after upload.',
                        )
                      else
                        for (final product in products.take(4))
                          InkWell(
                            onTap: () => push(
                              context,
                              ProductDetailPage(product: product),
                            ),
                            child: CompactProductTile(product: product),
                          ),
                      const SizedBox(height: 24),
                      const Kicker('QUICK SEARCH'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final token in tokens)
                            _buildClickableToken(token),
                          if (tokens.isEmpty) _buildClickableToken('Milk'),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSearchMessage(IconData icon, String title, String subtitle) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: muted),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildClickableToken(String label) {
    return InkWell(
      onTap: () {
        _searchController.text = label;
        _submitSearch(label);
      },
      borderRadius: BorderRadius.circular(16),
      child: SearchToken(label),
    );
  }
}
