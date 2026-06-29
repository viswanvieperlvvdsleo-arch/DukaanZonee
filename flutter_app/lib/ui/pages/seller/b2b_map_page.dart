import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  final List<Map<String, dynamic>> _neighborhoodShops = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<LiveEvent>? _liveSub;
  Map<String, dynamic>? _selectedShop;

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _liveSub = liveSocketService.events.listen((event) {
      if (_shouldRefreshMap(event.type)) {
        _loadPartners(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPartners({String query = '', bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final encoded = Uri.encodeQueryComponent(query.trim());
      final suffix = encoded.isEmpty ? '' : '?q=$encoded';
      final data = await apiClient.getJson('/api/seller/b2b/partners$suffix');
      final partners = (data['partners'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => _partnerFromBackend(Map<String, dynamic>.from(raw)))
          .toList();
      if (!mounted) return;
      setState(() {
        _neighborhoodShops
          ..clear()
          ..addAll(partners);
        _loading = false;
        _error = null;
        if (_selectedShop != null &&
            !_neighborhoodShops.any((s) => s['shopId'] == _selectedShop!['shopId'])) {
          _selectedShop = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load live B2B shops.';
      });
    }
  }

  bool _shouldRefreshMap(String type) {
    final normalized = type.toLowerCase();
    return normalized.contains('shop') ||
        normalized.contains('shelf') ||
        normalized.contains('stock') ||
        normalized.contains('inventory') ||
        normalized.contains('payment') ||
        normalized.contains('promotion');
  }

  Map<String, dynamic> _partnerFromBackend(Map<String, dynamic> partner) {
    final name = partner['name']?.toString() ?? 'Shop';
    final category = partner['category']?.toString() ?? 'Local shop';
    final block = partner['block']?.toString() ?? '';
    final lat = _readDouble(partner['latitude']);
    final lng = _readDouble(partner['longitude']);
    final seed = name.hashCode.abs();
    final fallbackLat = 17.7292 + ((seed % 9) - 4) * 0.0016;
    final fallbackLng = 83.3150 + (((seed ~/ 9) % 9) - 4) * 0.0016;
    return {
      'shopId': partner['shopId']?.toString(),
      'sellerId': partner['sellerId']?.toString(),
      'name': name,
      'owner': partner['owner']?.toString() ?? name,
      'distance': lat == null || lng == null ? 'Location pending' : 'Live location',
      'specialty': block.isEmpty ? category : '$category - $block',
      'lat': lat ?? fallbackLat,
      'lng': lng ?? fallbackLng,
      'rating': '5.0',
      'stockLevel': partner['upiId']?.toString().isNotEmpty == true
          ? 'Payment ready'
          : 'Profile ready',
      'featuredProduct': category,
      'avatarUrl': partner['avatarUrl']?.toString(),
      'mapUrl': partner['mapUrl']?.toString(),
      'email': partner['email']?.toString() ?? '',
      'phone': partner['phone']?.toString() ?? '',
      'upiId': partner['upiId']?.toString() ?? '',
    };
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _onShopTap(Map<String, dynamic> shop) async {
    setState(() {
      _selectedShop = shop;
    });

    if (kIsWeb || !_mapController.isCompleted) return;
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
      final owner = shop['owner'].toString().toLowerCase();
      final specialty = shop['specialty'].toString().toLowerCase();
      final product = shop['featuredProduct'].toString().toLowerCase();
      final upiId = shop['upiId'].toString().toLowerCase();
      final phone = shop['phone'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          owner.contains(query) ||
          specialty.contains(query) ||
          product.contains(query) ||
          upiId.contains(query) ||
          phone.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. Google Map Background
          Positioned.fill(
            child: kIsWeb
                ? _buildWebPartnerMap(filteredShops)
                : GoogleMap(
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
                      if (!_mapController.isCompleted) {
                        _mapController.complete(controller);
                      }
                    },
                    markers: _neighborhoodShops.map((shop) {
                      final isSelected = _selectedShop != null &&
                          _selectedShop!['name'] == shop['name'];
                      return Marker(
                        markerId: MarkerId(
                          shop['shopId']?.toString() ?? shop['name'],
                        ),
                        position: LatLng(shop['lat'], shop['lng']),
                        infoWindow: InfoWindow(
                          title: shop['name'],
                          snippet: shop['specialty'],
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          isSelected
                              ? BitmapDescriptor.hueViolet
                              : BitmapDescriptor.hueRed,
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
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.68),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null)
            Positioned(
              top: 112,
              left: 20,
              right: 20,
              child: _buildStatusCard(_error!),
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
                          _buildQuickPill('Pharmacy', Icons.local_pharmacy),
                          _buildQuickPill('Grocery', Icons.storefront),
                          _buildQuickPill('Payment ready', Icons.payments_outlined),
                          _buildQuickPill('Block A', Icons.location_city),
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

  Widget _buildWebPartnerMap(List<Map<String, dynamic>> shops) {
    final visible = shops.take(8).toList();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SellerMapGridPainter())),
          ...List.generate(visible.length, (index) {
            final shop = visible[index];
            final left = 28.0 + (index % 2) * 178.0;
            final top = 126.0 + (index ~/ 2) * 112.0;
            final selected = _selectedShop?['shopId'] == shop['shopId'];
            return Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () => _onShopTap(shop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 164,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? primary : Colors.white,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront,
                            color: Colors.redAccent,
                            size: 21,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shop['name']?.toString() ?? 'Shop',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop['specialty']?.toString() ?? 'Local partner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop['distance']?.toString() ?? 'Live location',
                        style: const TextStyle(
                          color: success,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (visible.isEmpty && !_loading)
            const Center(
              child: Text(
                'No B2B partners found here.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w900),
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
                shop['owner'].toString().toLowerCase().contains(label.toLowerCase()) ||
                shop['specialty'].toString().toLowerCase().contains(label.toLowerCase()) ||
                shop['upiId'].toString().toLowerCase().contains(label.toLowerCase()) ||
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
                    push(
                      context,
                      MerchantProfilePage(
                        shopId: shop['shopId']?.toString(),
                        shopName: shop['name'],
                      ),
                    );
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
                          'shopId': shop['shopId'],
                          'sellerId': shop['sellerId'],
                          'avatarUrl': shop['avatarUrl'],
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => openShopLocation(
                context,
                shopName: shop['name']?.toString() ?? 'Shop',
                mapUrl: shop['mapUrl']?.toString(),
                destination: LatLng(shop['lat'], shop['lng']),
              ),
              icon: const Icon(Icons.location_on_outlined, size: 18),
              label: const Text('Open Location'),
              style: TextButton.styleFrom(
                foregroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
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
                  'Try searching by shop name, owner, category, phone, or UPI.',
                  style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.74)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final lanePaint = Paint()
      ..color = const Color(0xFFCDEDDC).withOpacity(0.72)
      ..strokeWidth = 2;

    for (double y = 90; y < size.height; y += 88) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), lanePaint);
    }
    for (double x = -50; x < size.width + 50; x += 92) {
      canvas.drawLine(Offset(x, 0), Offset(x + 82, size.height), lanePaint);
    }
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.22),
      Offset(size.width * 0.9, size.height * 0.78),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.7),
      Offset(size.width * 0.82, size.height * 0.24),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
