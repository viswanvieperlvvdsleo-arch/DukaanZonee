import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerMapPage extends StatefulWidget {
  const SellerMapPage({super.key});

  @override
  State<SellerMapPage> createState() => _SellerMapPageState();
}

class _SellerMapPageState extends State<SellerMapPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  // Mock list of local neighborhood shops for B2B collaboration
  final List<Map<String, dynamic>> _neighborhoodShops = [
    {
      'name': 'Gupta Organic Mart',
      'owner': 'Sunil Gupta',
      'distance': '350m away',
      'specialty': 'Organic Veggies & Cereals',
      'lat': 28.6149,
      'lng': 77.2099,
      'rating': '4.9',
      'stockLevel': 'High Surplus',
      'featuredProduct': 'Fuji Apples',
    },
    {
      'name': 'Verma Grocery Depot',
      'owner': 'Rakesh Verma',
      'distance': '600m away',
      'specialty': 'Dairy & Packaged Goods',
      'lat': 28.6155,
      'lng': 77.2115,
      'rating': '4.7',
      'stockLevel': 'Balanced',
      'featuredProduct': 'Organic Milk',
    },
    {
      'name': 'Sharma Supermarket',
      'owner': 'Amit Sharma',
      'distance': '850m away',
      'specialty': 'Daily Staples & Fruits',
      'lat': 28.6135,
      'lng': 77.2085,
      'rating': '4.6',
      'stockLevel': 'Surplus Eggs & Wheat',
      'featuredProduct': 'Grade-A Bananas',
    },
  ];

  Map<String, dynamic>? _selectedShop;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onShopTap(Map<String, dynamic> shop) async {
    setState(() {
      _selectedShop = shop;
    });

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(shop['lat'], shop['lng']),
          zoom: 16.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter shops based on search query (by shop name, specialty, or featured product)
    final filteredShops = _neighborhoodShops.where((shop) {
      final name = shop['name'].toString().toLowerCase();
      final specialty = shop['specialty'].toString().toLowerCase();
      final product = shop['featuredProduct'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || specialty.contains(query) || product.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. Google Map Background
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.6145, 77.2102),
                zoom: 15.0,
              ),
              mapType: MapType.normal,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
              markers: _neighborhoodShops.map((shop) {
                final isSelected = _selectedShop != null && _selectedShop!['name'] == shop['name'];
                return Marker(
                  markerId: MarkerId(shop['name']),
                  position: LatLng(shop['lat'], shop['lng']),
                  infoWindow: InfoWindow(title: shop['name'], snippet: shop['specialty']),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    isSelected ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRed,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedShop = shop;
                    });
                  },
                );
              }).toSet(),
            ),
          ),

          // 2. Premium Top Floating Search Overlay
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                        // Auto highlight the first match if available
                        if (val.isNotEmpty && filteredShops.isNotEmpty) {
                          _onShopTap(filteredShops.first);
                        }
                      },
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search, color: primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedShop = null;
                                  });
                                },
                                child: const Icon(Icons.clear, color: muted),
                              )
                            : null,
                        hintText: 'Search other shops or products nearby...',
                        border: InputBorder.none,
                        hintStyle: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  // Show Quick Search suggestion pills
                  if (_searchQuery.isEmpty)
                    Container(
                      height: 48,
                      margin: const EdgeInsets.only(top: 12),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildQuickPill('Apples', Icons.apple),
                          _buildQuickPill('Gupta Mart', Icons.store),
                          _buildQuickPill('Milk', Icons.local_cafe),
                          _buildQuickPill('Sharma Shop', Icons.storefront),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Bottom Shop Details/Browse Sheet Overlay
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedShop != null)
                  _buildFeaturedShopCard(context, _selectedShop!)
                else if (filteredShops.isNotEmpty)
                  _buildScrollableShopsRow(filteredShops)
                else
                  _buildNoResultsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: () {
          setState(() {
            _searchQuery = label;
            _searchController.text = label;
          });
          final matches = _neighborhoodShops.where((shop) {
            return shop['name'].toString().toLowerCase().contains(label.toLowerCase()) ||
                shop['featuredProduct'].toString().toLowerCase().contains(label.toLowerCase());
          }).toList();
          if (matches.isNotEmpty) {
            _onShopTap(matches.first);
          }
        },
        avatar: Icon(icon, size: 14, color: primary),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 12)),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }

  Widget _buildScrollableShopsRow(List<Map<String, dynamic>> shops) {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: shops.length,
        itemBuilder: (context, index) {
          final shop = shops[index];
          return GestureDetector(
            onTap: () => _onShopTap(shop),
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primary.withOpacity(0.1),
                    radius: 20,
                    child: const Icon(Icons.storefront, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          shop['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop['specialty'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop['distance'],
                          style: const TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedShopCard(BuildContext context, Map<String, dynamic> shop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: primary.withOpacity(0.12),
                radius: 26,
                child: const Icon(Icons.store, color: primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop['name'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                shop['rating'],
                                style: const TextStyle(color: success, fontWeight: FontWeight.w900, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Specialty: ${shop['specialty']}',
                      style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shop['stockLevel'],
                            style: const TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          shop['distance'],
                          style: const TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate directly to public Merchant Profile
                    push(context, MerchantProfilePage(shopName: shop['name']));
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Browse Shelf'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Quick Action: Borrow or negotiate stock
                    push(
                      context,
                      B2BChatRoomPage(
                        merchant: {
                          'name': shop['name'],
                          'owner': shop['owner'],
                          'specialty': shop['specialty'],
                          'avatarColor': Colors.deepPurple,
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('Collab P2P'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.search_off_outlined, color: muted, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No neighboring stores match your query.',
                  style: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Try searching for Apples, Milk, or Gupta.',
                  style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
