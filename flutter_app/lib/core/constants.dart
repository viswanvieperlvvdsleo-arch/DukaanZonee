import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dukaan_zone_flutter/models/models.dart';

// ─── Global State ──────────────────────────────────────────
final ValueNotifier<MapState> globalMapState = ValueNotifier(MapState());
final ValueNotifier<String> globalSearchQuery = ValueNotifier('');

// ─── Saved Groups ─────────────────────────────────────────
class SavedGroup {
  SavedGroup({
    required this.id,
    required this.name,
    required this.shopName,
    required this.items,
    this.shopId,
    this.createdAt,
    Map<String, Product>? productDetails,
  }) : productDetails = productDetails ?? {};
  final String id;
  String name;
  final String shopName;
  final String? shopId;
  final DateTime? createdAt;
  final Map<String, int> items;
  final Map<String, Product> productDetails;

  double get total {
    double t = 0;
    for (final entry in items.entries) {
      final p =
          productDetails[entry.key] ??
          catalogProducts.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => catalogProducts.first,
          );
      final raw = p.price.replaceAll(RegExp(r'[₹,]'), '');
      t += (double.tryParse(raw) ?? 0) * entry.value;
    }
    return t;
  }

  List<Product> get products => items.keys.map((id) {
    return productDetails[id] ??
        catalogProducts.firstWhere(
          (p) => p.id == id,
          orElse: () => catalogProducts.first,
        );
  }).toList();
}

final ValueNotifier<List<SavedGroup>> globalSavedGroups = ValueNotifier([]);

final ValueNotifier<List<Map<String, dynamic>>> globalPaymentHistory =
    ValueNotifier([]);

final ValueNotifier<double> globalSellerTodayRevenue = ValueNotifier(4250.0);

// ─── Promoted Products ─────────────────────────────────────
class PromotedProduct {
  PromotedProduct({
    required this.id,
    required this.productId,
    required this.shopName,
    required this.durationDays,
    required this.amountPaid,
    required this.startDate,
    this.isApproved = false,
    this.impressions = 0,
    this.clicks = 0,
  });

  final String id;
  final String productId;
  final String shopName;
  final int durationDays;
  final double amountPaid;
  final DateTime startDate;
  bool isApproved;
  int impressions;
  int clicks;

  DateTime get endDate => startDate.add(Duration(days: durationDays));
  bool get isExpired => DateTime.now().isAfter(endDate);
}

final ValueNotifier<List<PromotedProduct>> globalPromotedProducts =
    ValueNotifier([
      PromotedProduct(
        id: 'promo-1',
        productId: 'prod-3', // Mixed Veggie Pack
        shopName: 'Malhotra Fresh Farms',
        durationDays: 7,
        amountPaid: 60.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        isApproved: true,
        impressions: 142000,
        clicks: 12000,
      ),
    ]);

final ValueNotifier<int?> globalActiveTabOverride = ValueNotifier<int?>(null);
final ValueNotifier<Map<String, double>> globalBankBalances = ValueNotifier({
  'HDFC Bank': 45230.00,
  'SBI Bank': 12800.00,
});

final ValueNotifier<Map<String, String>>
globalSellerShopProfile = ValueNotifier({
  'name': 'My Shop',
  'address': '',
  'phone': '+91 90305 22754',
  'bio':
      'Sourcing the freshest organic greens and daily essentials directly from community producers.',
  'avatarUrl': '',
});

// ─── Mock Product Data ─────────────────────────────────────
List<Product> pulseProducts = [
  Product(
    'prod-1',
    'Bananas',
    '₹60.00',
    'Malhotra Fresh Farms',
    'Just Restocked',
    '15 dozen left',
    Icons.eco,
    Color(0xFFDCFCE7),
  ),
  Product(
    'prod-3',
    'Mixed Veggie Pack',
    '₹120.00',
    'Malhotra Fresh Farms',
    'Fresh',
    '10 packs left',
    Icons.shopping_basket,
    Color(0xFFFFEDD5),
  ),
  Product(
    'prod-4',
    'Grade-A Fuji Apples',
    '₹220.00',
    'Malhotra Fresh Farms',
    'Premium',
    '5 kg left',
    Icons.local_florist,
    Color(0xFFFEE2E2),
  ),
  Product(
    'prod-2',
    'Noise-Cancelling Pro',
    '₹12,499.00',
    'Tech Haven',
    'High Demand',
    '2 units left',
    Icons.headphones,
    Color(0xFFE0E7FF),
  ),
];

List<Product> catalogProducts = [
  Product(
    'prod-4',
    'Grade-A Fuji Apples (1KG)',
    '₹220.00',
    'Malhotra Fresh Farms',
    'Premium',
    '5 kg left',
    Icons.local_florist,
    Color(0xFFFEE2E2),
  ),
  Product(
    'prod-3',
    'Premium Mixed Greens Collection (500g)',
    '₹120.00',
    'Malhotra Fresh Farms',
    'Fresh',
    '10 units left',
    Icons.spa,
    Color(0xFFDFF3E7),
  ),
  Product(
    'prod-1',
    'Fresh Organic Bananas (Dozen)',
    '₹60.00',
    'Malhotra Fresh Farms',
    'Just Restocked',
    '15 dozen left',
    Icons.eco,
    Color(0xFFFFF7D6),
  ),
  Product(
    'prod-2',
    'Noise Cancelling Earbuds (Space Grey)',
    '₹12,499.00',
    'Tech Haven',
    'High Demand',
    '2 units left',
    Icons.headphones,
    Color(0xFFE0E7FF),
  ),
];

const shops = [
  Shop(
    'Malhotra Fresh Farms',
    'Block A',
    'Grocery',
    '4.8',
    '164',
    LatLng(17.7300, 83.3160),
  ),
  Shop(
    'Tech Haven',
    'Block B',
    'Electronics',
    '4.9',
    '91',
    LatLng(17.7285, 83.3130),
  ),
  Shop(
    'Fresh Daily Dairy',
    'Block A',
    'Essentials',
    '4.7',
    '118',
    LatLng(17.7270, 83.3180),
  ),
];

// ─── Helper Navigation ─────────────────────────────────────
// OxygenOS-style: new page slides up gently + fades in.
// GPU-only: translate + opacity. No layout thrash.
Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, __, child) {
          // Single GPU pass: translate-Y 24px → 0 + opacity 0 → 1
          // Uses easeOutCubic matching cubic-bezier(0.0, 0.0, 0.2, 1)
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.0, 0.0, 0.2, 1.0),
            reverseCurve: const Cubic(0.4, 0.0, 1.0, 1.0),
          );
          return AnimatedBuilder(
            animation: curved,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (1.0 - curved.value) * 24.0),
              child: Opacity(
                opacity: curved.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
            child: child,
          );
        },
      ),
    );

// Auto Reply State
final ValueNotifier<Map<String, dynamic>> globalAutoReplyConfig =
    ValueNotifier({
      'userEnabled': false,
      'userPreset': 'We will get back to you shortly',
      'userCustom': '',
      'shopkeeperEnabled': false,
      'shopkeeperPreset': 'Currently busy, will call you back',
      'shopkeeperCustom': '',
    });

final List<String> autoReplyPresets = [
  'We will get back to you shortly',
  'Currently busy, will call you back',
  'For urgent queries, call our store number',
  'Out of store, back in an hour',
];

Future<T?> pushRoot<T>(BuildContext context, Widget page) =>
    Navigator.of(context).pushAndRemoveUntil<T>(
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.0, 0.0, 0.2, 1.0),
            reverseCurve: const Cubic(0.4, 0.0, 1.0, 1.0),
          );
          return AnimatedBuilder(
            animation: curved,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (1.0 - curved.value) * 24.0),
              child: Opacity(
                opacity: curved.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
            child: child,
          );
        },
      ),
      (route) => false,
    );
