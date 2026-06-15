import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class UserMapPage extends StatefulWidget {
  const UserMapPage({super.key});

@override
  State<UserMapPage> createState() => _UserMapPageState();
}

class _UserMapPageState extends State<UserMapPage> {
  final Completer<GoogleMapController> _controller = Completer();
  Shop? _selectedShop;
  Set<Marker> _markers = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(17.7292, 83.3150),
    zoom: 14.5,
  );

  @override
  void initState() {
    super.initState();
    _updateMarkers('');
    globalSearchQuery.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    globalSearchQuery.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    _updateMarkers(globalSearchQuery.value);
  }

  void _updateMarkers(String query) {
    final filtered = query.isEmpty 
        ? shops 
        : shops.where((s) => s.name.toLowerCase().contains(query.toLowerCase()) || s.type.toLowerCase().contains(query.toLowerCase())).toList();

    setState(() {
      _markers = filtered.map((shop) => Marker(
        markerId: MarkerId(shop.name),
        position: shop.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _selectShop(shop),
      )).toSet();
    });

    if (filtered.isNotEmpty && query.isNotEmpty) {
      _animateTo(filtered.first.location);
    }
  }

  Future<void> _animateTo(LatLng pos) async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
  }

  void _selectShop(Shop shop) {
    setState(() => _selectedShop = shop);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapState>(
      valueListenable: globalMapState,
      builder: (context, mapState, _) {
        final isRouting = mapState.mode == MapMode.routing;

        return Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
              },
              markers: _markers,
              polylines: isRouting ? _generatePolylines(mapState.destination) : const <Polyline>{},
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) _controller.complete(controller);
              },
            ),

            // Top Search Pill (if not routing)
            if (!isRouting)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPill('Nearby Shops', Icons.storefront, active: true),
                      const SizedBox(width: 8),
                      _buildPill('Grocery', Icons.shopping_basket),
                      const SizedBox(width: 8),
                      _buildPill('Electronics', Icons.headphones),
                    ],
                  ),
                ),
              ),

            // Routing Overlay
            if (isRouting)
              _buildRoutingOverlay(mapState),

            // Floating Action Buttons
            Positioned(
              bottom: _selectedShop != null || isRouting ? 260 : 120,
              right: 16,
              child: Column(
                children: [
                  _buildMapActionButton(Icons.my_location),
                  const SizedBox(height: 12),
                  _buildMapActionButton(Icons.layers_outlined),
                ],
              ),
            ),

            // Shop Details Bottom Sheet
            if (_selectedShop != null && !isRouting)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildShopDetailsSheet(_selectedShop!),
              ),

            // Routing Progress Sheet
            if (isRouting)
              Positioned(bottom: 0, left: 0, right: 0, child: _buildRoutingSheet()),
          ],
        );
      },
    );
  }

  Set<Polyline> _generatePolylines(LatLng? dest) {
    if (dest == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [const LatLng(17.7292, 83.3150), dest],
        color: Colors.blue,
        width: 6,
      )
    };
  }

  Widget _buildShopDetailsSheet(Shop shop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text('${shop.type} • ${shop.block}', style: const TextStyle(color: muted, fontSize: 14)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedShop = null)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    globalMapState.value = MapState(mode: MapMode.routing, destination: shop.location, destinationName: shop.name);
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF007A87), padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => push(context, MerchantProfilePage(shopName: shop.name)),
                  icon: const Icon(Icons.storefront),
                  label: const Text('View Shop'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildRoutingOverlay(MapState state) {
    return Positioned(
      top: 16, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: shadowLg),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text('Route to ${state.destinationName}', style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => globalMapState.value = MapState(mode: MapMode.standard)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32)), boxShadow: shadowLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [Text('14 min', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), Text('Fastest route', style: TextStyle(color: muted, fontSize: 12))]),
              Column(children: [Text('2.4 km', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), Text('Distance', style: TextStyle(color: muted, fontSize: 12))]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => globalMapState.value = MapState(mode: MapMode.standard),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF007A87), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Exit Navigation', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.blue[100]! : Colors.grey[300]!, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.blue[700] : Colors.black87),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: active ? Colors.blue[800] : Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActionButton(IconData icon) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: shadowSm),
      child: Icon(icon, color: Colors.black87, size: 24),
    );
  }
}
