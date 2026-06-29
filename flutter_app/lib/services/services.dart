import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/services/api_service.dart';
import 'package:dukaan_zone_flutter/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
export 'sound_service.dart';
export 'notification_service.dart';
export 'api_service.dart';

// --- Services ---

abstract class PaymentService {
  Future<bool> processPayment({
    required double amount,
    required String orderId,
  });
}

class MockPaymentService implements PaymentService {
  @override
  Future<bool> processPayment({
    required double amount,
    required String orderId,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    return true; // Always succeed for now
  }
}

abstract class ReviewService {
  Future<ProductReviewsResult> getProductReviews(String productId);
  Future<ProductReviewsResult> addProductReview(
    String productId, {
    required int rating,
    required String comment,
  });
  Future<ProductReviewsResult> deleteProductReview(
    String productId,
    String reviewId,
  );
  Future<List<String>> getReviews(String productId);
  Future<String> getCommunityPulse(String productId);
  Future<void> addReview(String productId, String review);
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String userId;
  final String userName;
  final DateTime? createdAt;
}

class ProductReviewsResult {
  const ProductReviewsResult({
    required this.reviews,
    required this.count,
    required this.averageRating,
  });

  final List<ProductReview> reviews;
  final int count;
  final double averageRating;
}

class BackendReviewService implements ReviewService {
  @override
  Future<ProductReviewsResult> getProductReviews(String productId) async {
    final data = await apiClient.getJson(
      '/api/discovery/products/$productId/reviews',
    );
    return _mapResult(data);
  }

  @override
  Future<List<String>> getReviews(String productId) async {
    final result = await getProductReviews(productId);
    return result.reviews.map((review) => review.comment).toList();
  }

  @override
  Future<void> addReview(String productId, String review) async {
    await addProductReview(productId, rating: 5, comment: review);
  }

  @override
  Future<ProductReviewsResult> addProductReview(
    String productId, {
    required int rating,
    required String comment,
  }) async {
    final data = await apiClient.postJson(
      '/api/discovery/products/$productId/reviews',
      {'rating': rating, 'comment': comment},
    );
    return _mapResult(data);
  }

  @override
  Future<ProductReviewsResult> deleteProductReview(
    String productId,
    String reviewId,
  ) async {
    final data = await apiClient.deleteJsonWithResponse(
      '/api/discovery/products/$productId/reviews/$reviewId',
    );
    return _mapResult(data);
  }

  @override
  Future<String> getCommunityPulse(String productId) async {
    final result = await getProductReviews(productId);
    if (result.count == 0) {
      return 'No reviews yet. Be the first neighbor to share a real product note.';
    }
    return '${result.count} review${result.count == 1 ? '' : 's'} with ${result.averageRating.toStringAsFixed(1)} average rating.';
  }

  ProductReviewsResult _mapResult(Map<String, dynamic> data) {
    final summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
    final reviews = (data['reviews'] as List? ?? const []).whereType<Map>().map(
      (raw) {
        final review = Map<String, dynamic>.from(raw);
        return ProductReview(
          id: review['id']?.toString() ?? '',
          rating: review['rating'] as int? ?? 5,
          comment: review['comment']?.toString() ?? '',
          userId: review['userId']?.toString() ?? '',
          userName: review['userName']?.toString() ?? 'Neighbor',
          createdAt: DateTime.tryParse(review['createdAt']?.toString() ?? ''),
        );
      },
    ).toList();

    return ProductReviewsResult(
      reviews: reviews,
      count: summary['count'] as int? ?? reviews.length,
      averageRating:
          (summary['averageRating'] as num?)?.toDouble() ??
          (reviews.isEmpty
              ? 0
              : reviews.fold<double>(0, (sum, item) => sum + item.rating) /
                    reviews.length),
    );
  }
}

// Global service locators (for simplicity without extra packages)
final PaymentService paymentService = MockPaymentService();

final ReviewService reviewService = BackendReviewService();

class UserModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String? profilePic;
  final Role role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.profilePic,
    required this.role,
  });

  UserModel copyWith({String? name, String? mobile, String? profilePic}) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      mobile: mobile ?? this.mobile,
      profilePic: profilePic ?? this.profilePic,
      role: role,
    );
  }
}

class SavedAccountSession {
  const SavedAccountSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.profilePic,
  });

  final String userId;
  final String name;
  final String email;
  final Role role;
  final String token;
  final String? profilePic;
}

abstract class AuthService {
  ValueNotifier<bool> get isLoggedIn;
  ValueNotifier<Role?> get currentRole;
  ValueNotifier<UserModel?> get currentUser;
  Future<bool> restoreSession();
  Future<List<SavedAccountSession>> savedAccounts();
  Future<bool> switchSavedAccount(String token);
  Future<void> forgetSavedAccount(String userId);
  Future<bool> login(String email, String password, {Role role = Role.user});
  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
    bool isSeller = false,
    String? shopName,
    String? category,
    String? block,
    String? address,
    double? latitude,
    double? longitude,
    String? mapUrl,
    String? paymentQrPayload,
    String? upiId,
  });
  Future<bool> verifyOtp(String code);
  Future<void> updateProfile({
    String? name,
    String? mobile,
    String? profilePic,
  });
  Future<void> logout();
}

class MockAuthService implements AuthService {
  final _isLoggedIn = ValueNotifier<bool>(false);
  final _currentRole = ValueNotifier<Role?>(null);
  final _currentUser = ValueNotifier<UserModel?>(null);

  @override
  ValueNotifier<bool> get isLoggedIn => _isLoggedIn;
  @override
  ValueNotifier<Role?> get currentRole => _currentRole;
  @override
  ValueNotifier<UserModel?> get currentUser => _currentUser;

  @override
  Future<bool> restoreSession() async => _isLoggedIn.value;

  @override
  Future<List<SavedAccountSession>> savedAccounts() async {
    final user = _currentUser.value;
    if (user == null) return const [];
    return [
      SavedAccountSession(
        userId: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        token: 'mock',
        profilePic: user.profilePic,
      ),
    ];
  }

  @override
  Future<bool> switchSavedAccount(String token) async => token == 'mock';

  @override
  Future<void> forgetSavedAccount(String userId) async {}

  @override
  Future<bool> login(
    String email,
    String password, {
    Role role = Role.user,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    if (role == Role.admin) {
      return false;
    }

    _isLoggedIn.value = true;
    _currentRole.value = role;
    _currentUser.value = UserModel(
      id: 'user_123',
      name: email.split('@')[0].toUpperCase(),
      email: email,
      mobile: '0000000000',
      role: role,
    );
    return true;
  }

  @override
  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
    bool isSeller = false,
    String? shopName,
    String? category,
    String? block,
    String? address,
    double? latitude,
    double? longitude,
    String? mapUrl,
    String? paymentQrPayload,
    String? upiId,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    final role = isSeller ? Role.seller : Role.user;
    _isLoggedIn.value = true;
    _currentRole.value = role;
    _currentUser.value = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      mobile: mobile,
      role: role,
    );
    return true;
  }

  @override
  Future<bool> verifyOtp(String code) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return true; // Accept any OTP for testing
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? mobile,
    String? profilePic,
  }) async {
    if (_currentUser.value != null) {
      _currentUser.value = _currentUser.value!.copyWith(
        name: name,
        mobile: mobile,
        profilePic: profilePic,
      );
    }
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoggedIn.value = false;
    _currentRole.value = null;
    _currentUser.value = null;
  }
}

class BackendAuthService implements AuthService {
  static const _sessionTokenKey = 'dukaanzone.auth.token';
  static const _savedAccountsKey = 'dukaanzone.auth.saved_accounts';

  final _isLoggedIn = ValueNotifier<bool>(false);
  final _currentRole = ValueNotifier<Role?>(null);
  final _currentUser = ValueNotifier<UserModel?>(null);
  String? lastError;

  @override
  ValueNotifier<bool> get isLoggedIn => _isLoggedIn;

  @override
  ValueNotifier<Role?> get currentRole => _currentRole;

  @override
  ValueNotifier<UserModel?> get currentUser => _currentUser;

  @override
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_sessionTokenKey);
      if (token == null || token.isEmpty) return false;

      apiClient.setToken(token);
      final data = await apiClient.getJson('/api/auth/me');
      final user = data['user'] as Map<String, dynamic>;
      _applyUser(user);
      await _bindPushForCurrentUser();
      liveSocketService.connect();
      return true;
    } catch (error) {
      lastError = error.toString();
      await _clearSavedSession();
      return false;
    }
  }

  @override
  Future<List<SavedAccountSession>> savedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedAccountsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            return SavedAccountSession(
              userId: map['userId']?.toString() ?? '',
              name: map['name']?.toString() ?? 'Account',
              email: map['email']?.toString() ?? '',
              role: _roleFromString(map['role']?.toString()),
              token: map['token']?.toString() ?? '',
              profilePic: map['profilePic']?.toString(),
            );
          })
          .where(
            (account) => account.userId.isNotEmpty && account.token.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> switchSavedAccount(String token) async {
    if (token.isEmpty) return false;
    try {
      apiClient.setToken(token);
      final data = await apiClient.getJson('/api/auth/me');
      final user = Map<String, dynamic>.from(data['user'] as Map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionTokenKey, token);
      _applyUser(user);
      await _saveAccount(user, token);
      await _bindPushForCurrentUser();
      liveSocketService.connect();
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  @override
  Future<void> forgetSavedAccount(String userId) async {
    final accounts = await savedAccounts();
    final remaining = accounts.where((account) => account.userId != userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedAccountsKey,
      jsonEncode(remaining.map(_savedAccountToJson).toList()),
    );
  }

  @override
  Future<bool> login(
    String email,
    String password, {
    Role role = Role.user,
  }) async {
    try {
      final data = await apiClient.postJson('/api/auth/login', {
        'email': email.trim(),
        'password': password,
        'role': role.name,
      });
      await _applySession(data);
      return true;
    } catch (error) {
      lastError = error.toString();
      debugPrint('Login failed: $error');
      return false;
    }
  }

  @override
  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
    bool isSeller = false,
    String? shopName,
    String? category,
    String? block,
    String? address,
    double? latitude,
    double? longitude,
    String? mapUrl,
    String? paymentQrPayload,
    String? upiId,
  }) async {
    try {
      final data = await apiClient.postJson(
        isSeller ? '/api/auth/register/seller' : '/api/auth/register/user',
        isSeller
            ? {
                'name': name.trim(),
                'email': email.trim(),
                'phone': mobile.trim(),
                'password': password,
                'shopName': (shopName ?? name).trim(),
                'category': category ?? 'Grocery',
                'block': block ?? 'Block A',
                if (address != null && address.trim().isNotEmpty)
                  'address': address.trim(),
                if (latitude != null) 'latitude': latitude,
                if (longitude != null) 'longitude': longitude,
                if (mapUrl != null && mapUrl.trim().isNotEmpty)
                  'mapUrl': mapUrl.trim(),
                if (paymentQrPayload != null &&
                    paymentQrPayload.trim().isNotEmpty)
                  'paymentQrPayload': paymentQrPayload.trim(),
                if (upiId != null && upiId.trim().isNotEmpty)
                  'upiId': upiId.trim(),
              }
            : {
                'name': name.trim(),
                'email': email.trim(),
                'phone': mobile.trim(),
                'password': password,
              },
      );
      await _applySession(data);
      return true;
    } catch (error) {
      lastError = error.toString();
      debugPrint('Register failed: $error');
      return false;
    }
  }

  @override
  Future<bool> verifyOtp(String code) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return code.trim() == '1234';
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? mobile,
    String? profilePic,
  }) async {
    if (_currentUser.value == null) return;

    try {
      final data = await apiClient.patchJson('/api/auth/me', {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (mobile != null) 'phone': mobile.trim(),
        if (profilePic != null) 'profilePic': profilePic,
      });
      final user = data['user'] as Map<String, dynamic>;
      _currentUser.value = UserModel(
        id: user['id']?.toString() ?? _currentUser.value!.id,
        name: user['name']?.toString() ?? _currentUser.value!.name,
        email: user['email']?.toString() ?? _currentUser.value!.email,
        mobile: user['phone']?.toString() ?? _currentUser.value!.mobile,
        profilePic: user['profilePic']?.toString(),
        role: _roleFromString(user['role']?.toString()),
      );
    } catch (error) {
      lastError = error.toString();
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await hardwareNotificationService.unregister();
    apiClient.setToken(null);
    liveSocketService.disconnect();
    await _clearSavedSession();
    _isLoggedIn.value = false;
    _currentRole.value = null;
    _currentUser.value = null;
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    final user = data['user'] as Map<String, dynamic>;
    final token = data['token']?.toString();
    apiClient.setToken(token);
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionTokenKey, token);
      await _saveAccount(user, token);
    }
    liveSocketService.connect();
    _applyUser(user);
    await _bindPushForCurrentUser();
  }

  void _applyUser(Map<String, dynamic> user) {
    final role = _roleFromString(user['role']?.toString());
    _currentUser.value = UserModel(
      id: user['id']?.toString() ?? '',
      name: user['name']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      mobile: user['phone']?.toString() ?? '',
      profilePic: user['profilePic']?.toString(),
      role: role,
    );
    _currentRole.value = role;
    _isLoggedIn.value = true;
  }

  Future<void> _bindPushForCurrentUser() async {
    final user = _currentUser.value;
    if (user == null || user.id.isEmpty) return;
    await hardwareNotificationService.bindAccount(
      accountType: user.role.name,
      accountId: user.id,
    );
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
  }

  Future<void> _saveAccount(Map<String, dynamic> user, String token) async {
    final current = await savedAccounts();
    final next = [
      SavedAccountSession(
        userId: user['id']?.toString() ?? '',
        name: user['name']?.toString() ?? 'Account',
        email: user['email']?.toString() ?? '',
        role: _roleFromString(user['role']?.toString()),
        token: token,
        profilePic: user['profilePic']?.toString(),
      ),
      ...current.where((account) => account.userId != user['id']?.toString()),
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedAccountsKey,
      jsonEncode(next.map(_savedAccountToJson).toList()),
    );
  }

  Map<String, dynamic> _savedAccountToJson(SavedAccountSession account) {
    return {
      'userId': account.userId,
      'name': account.name,
      'email': account.email,
      'role': account.role.name,
      'token': account.token,
      if (account.profilePic != null) 'profilePic': account.profilePic,
    };
  }

  Role _roleFromString(String? value) {
    return switch (value) {
      'seller' => Role.seller,
      'admin' => Role.admin,
      _ => Role.user,
    };
  }
}

class PaymentGatewayOption {
  const PaymentGatewayOption({
    required this.id,
    required this.label,
    required this.mode,
    required this.feeRate,
    required this.isLiveReady,
    this.note,
  });

  final String id;
  final String label;
  final String mode;
  final double feeRate;
  final bool isLiveReady;
  final String? note;

  bool get isMock => id == 'mock_gateway';
  bool get isSandbox => mode == 'sandbox' || mode == 'sandbox_adapter';

  String get statusLabel {
    if (mode == 'live_keys_configured') return 'Live keys ready';
    if (mode == 'sandbox_adapter') return 'Sandbox adapter';
    return 'Sandbox';
  }

  static PaymentGatewayOption fromJson(Map<String, dynamic> json) {
    return PaymentGatewayOption(
      id: json['id']?.toString() ?? 'mock_gateway',
      label: json['label']?.toString() ?? 'Mock Gateway',
      mode: json['mode']?.toString() ?? 'sandbox',
      feeRate: (json['feeRate'] as num?)?.toDouble() ?? 0.0236,
      isLiveReady: json['isLiveReady'] == true,
      note: json['note']?.toString(),
    );
  }
}

class PaymentSessionResult {
  const PaymentSessionResult({
    required this.shop,
    required this.products,
    required this.qrPayload,
    required this.providers,
    required this.preferredProvider,
    this.upiId,
  });

  final Shop shop;
  final List<Product> products;
  final String qrPayload;
  final List<PaymentGatewayOption> providers;
  final String preferredProvider;
  final String? upiId;
}

class CompletedPayment {
  const CompletedPayment({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.grossCents,
    required this.gatewayFeeCents,
    required this.commissionCents,
    required this.sellerNetCents,
    required this.status,
    required this.source,
    required this.provider,
    this.gateway,
    this.gatewayReference,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String shopId;
  final String shopName;
  final int grossCents;
  final int gatewayFeeCents;
  final int commissionCents;
  final int sellerNetCents;
  final String status;
  final String source;
  final String provider;
  final PaymentGatewayOption? gateway;
  final String? gatewayReference;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> items;

  String get amountLabel => _formatCents(grossCents);

  String get itemsLabel {
    if (items.isEmpty) return 'Direct shop payment';
    return items
        .map((item) {
          final name = item['name']?.toString() ?? 'Item';
          final qty = item['quantity'] as int? ?? 1;
          return '$name x$qty';
        })
        .join(', ');
  }
}

String _formatCents(int cents) {
  return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
}

class PaymentSessionService {
  Future<PaymentSessionResult> scanPaymentQr(String qrPayload) async {
    final data = await apiClient.postJson('/api/payment-sessions/scan', {
      'qrPayload': qrPayload,
    });
    final shopMap = Map<String, dynamic>.from(data['shop'] as Map);
    final session = Map<String, dynamic>.from(data['paymentSession'] as Map);
    final shop = Shop(
      shopMap['name']?.toString() ?? 'Shop',
      shopMap['block']?.toString() ?? '',
      shopMap['category']?.toString() ?? 'Local shop',
      '4.8',
      '0',
      const LatLng(0, 0),
      id: shopMap['id']?.toString(),
      address: shopMap['address']?.toString(),
      paymentQrPayload: shopMap['payment_qr_payload']?.toString(),
      upiId: shopMap['upi_id']?.toString(),
      gatewayProvider:
          shopMap['gateway_provider']?.toString() ??
          session['preferredProvider']?.toString(),
      phone: shopMap['seller_phone']?.toString(),
      avatarUrl: shopMap['avatar_url']?.toString(),
      mapUrl: shopMap['map_url']?.toString(),
      sellerId:
          shopMap['sellerId']?.toString() ?? shopMap['seller_id']?.toString(),
    );
    final products = (data['items'] as List<dynamic>).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final priceCents = item['price_cents'] as int? ?? 0;
      final stock = item['stock_qty'] as int? ?? 0;
      return Product(
        item['id']?.toString() ?? '',
        item['name']?.toString() ?? '',
        '₹${(priceCents / 100).toStringAsFixed(priceCents % 100 == 0 ? 0 : 2)}',
        shop.name,
        'Live',
        '$stock left',
        Icons.shopping_bag_outlined,
        const Color(0xFFE8F5E9),
        imageUrl: item['image_url']?.toString(),
        shopId: shopMap['id']?.toString(),
        shopBlock: shop.block,
        shopCategory: shop.type,
        shopAddress: shop.address,
        paymentQrPayload:
            shopMap['payment_qr_payload']?.toString() ??
            session['qrPayload']?.toString(),
        upiId: session['upiId']?.toString(),
        description: item['description']?.toString(),
        shopAvatarUrl: shop.avatarUrl,
        shopMapUrl: shop.mapUrl,
      );
    }).toList();
    final providers = (session['providers'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (raw) =>
              PaymentGatewayOption.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList();

    return PaymentSessionResult(
      shop: shop,
      products: products,
      qrPayload: session['qrPayload']?.toString() ?? qrPayload,
      providers: providers.isEmpty
          ? const [
              PaymentGatewayOption(
                id: 'mock_gateway',
                label: 'Mock Gateway',
                mode: 'sandbox',
                feeRate: 0.0236,
                isLiveReady: false,
              ),
            ]
          : providers,
      preferredProvider:
          session['preferredProvider']?.toString() ?? 'mock_gateway',
      upiId: session['upiId']?.toString(),
    );
  }

  Future<CompletedPayment> completeCheckout({
    required Shop shop,
    required double amount,
    required List<Map<String, dynamic>> selectedItems,
    String provider = 'mock_gateway',
  }) async {
    final shopId = shop.id;
    if (shopId == null || shopId.trim().isEmpty) {
      throw const ApiException('Shop id missing for checkout');
    }

    final bodyItems = selectedItems.map((entry) {
      final product = entry['product'] as Product;
      return {'shelfItemId': product.id, 'quantity': entry['qty'] as int? ?? 1};
    }).toList();

    final data = await apiClient.postJson('/api/payment-sessions/complete', {
      'shopId': shopId,
      'amountCents': (amount * 100).round(),
      'items': bodyItems,
      'source': 'in_app',
      'provider': provider,
    });
    final payment = Map<String, dynamic>.from(data['payment'] as Map);
    return _mapCompletedPayment(payment, fallbackShop: shop);
  }

  Future<List<CompletedPayment>> history() async {
    final data = await apiClient.getJson('/api/payment-sessions/history');
    return (data['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapCompletedPayment(Map<String, dynamic>.from(raw)))
        .toList();
  }

  CompletedPayment _mapCompletedPayment(
    Map<String, dynamic> payment, {
    Shop? fallbackShop,
  }) {
    return CompletedPayment(
      id: payment['id']?.toString() ?? '',
      shopId: payment['shopId']?.toString() ?? fallbackShop?.id ?? '',
      shopName:
          payment['shopName']?.toString() ?? fallbackShop?.name ?? 'Local shop',
      grossCents: payment['grossCents'] as int? ?? 0,
      gatewayFeeCents: payment['gatewayFeeCents'] as int? ?? 0,
      commissionCents: payment['commissionCents'] as int? ?? 0,
      sellerNetCents: payment['sellerNetCents'] as int? ?? 0,
      status: payment['status']?.toString() ?? 'completed',
      source: payment['source']?.toString() ?? 'in_app',
      provider: payment['provider']?.toString() ?? 'mock_gateway',
      gateway: payment['gateway'] is Map
          ? PaymentGatewayOption.fromJson(
              Map<String, dynamic>.from(payment['gateway'] as Map),
            )
          : null,
      gatewayReference: payment['gatewayReference']?.toString(),
      createdAt: DateTime.tryParse(payment['createdAt']?.toString() ?? ''),
      items: (payment['items'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(),
    );
  }
}

class DiscoverySnapshot {
  const DiscoverySnapshot({required this.featured, required this.products});

  final List<Product> featured;
  final List<Product> products;
}

class DiscoveryService {
  Future<DiscoverySnapshot> getHome() async {
    final data = await apiClient.getJson('/api/discovery/home?limit=60');
    return DiscoverySnapshot(
      featured: _mapList(data['featured']),
      products: _mapList(data['products']),
    );
  }

  Future<List<Product>> searchProducts(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final suffix = encoded.isEmpty ? '' : '?q=$encoded';
    final data = await apiClient.getJson('/api/discovery/search$suffix');
    return _mapList(data['products']);
  }

  Future<List<Product>> getSavedProducts() async {
    final data = await apiClient.getJson('/api/discovery/saved/products');
    return _mapList(data['products']);
  }

  Future<Product> saveProduct(String productId) async {
    final data = await apiClient.postJson(
      '/api/discovery/products/$productId/save',
      {},
    );
    return _mapProduct(Map<String, dynamic>.from(data['product'] as Map));
  }

  Future<void> unsaveProduct(String productId) {
    return apiClient.deleteJson('/api/discovery/products/$productId/save');
  }

  Future<void> trackPromotionClick(String promotionId) {
    return apiClient.postJson(
      '/api/discovery/promotions/$promotionId/click',
      {},
    );
  }

  List<Product> _mapList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => _mapProduct(Map<String, dynamic>.from(item)))
        .toList();
  }

  Product _mapProduct(Map<String, dynamic> item) {
    final shop = Map<String, dynamic>.from(item['shop'] as Map? ?? {});
    final priceCents = item['priceCents'] as int? ?? 0;
    final stock = item['stockQty'] as int? ?? 0;
    final category = item['category']?.toString();
    final shopCategory = shop['category']?.toString();
    final badge =
        (category?.isNotEmpty == true ? category : shopCategory) ?? 'Live';

    return Product(
      item['id']?.toString() ?? '',
      item['name']?.toString() ?? 'Shelf item',
      _formatRupees(priceCents),
      shop['name']?.toString() ?? 'Local shop',
      badge,
      stock == 1 ? '1 left' : '$stock left',
      Icons.shopping_bag_outlined,
      const Color(0xFFE8F5E9),
      imageUrl: item['imageUrl']?.toString(),
      shopId: shop['id']?.toString(),
      shopBlock: shop['block']?.toString(),
      shopCategory: shopCategory,
      shopAddress: shop['address']?.toString(),
      paymentQrPayload: shop['paymentQrPayload']?.toString(),
      upiId: shop['upiId']?.toString(),
      description: item['description']?.toString(),
      shopAvatarUrl: shop['avatarUrl']?.toString(),
      shopMapUrl: shop['mapUrl']?.toString(),
      shopFollowerCount: shop['followerCount'] as int? ?? 0,
      shopRating: (shop['rating'] as num?)?.toDouble() ?? 0,
      isFollowingShop: shop['isFollowing'] == true,
      isSaved: item['isSaved'] == true,
      promotionId: item['promotionId']?.toString(),
    );
  }

  String _formatRupees(int priceCents) {
    final rupees = priceCents / 100;
    final text = rupees.toStringAsFixed(priceCents % 100 == 0 ? 0 : 2);
    return 'Rs $text';
  }
}

class SavedGroupService {
  Future<List<SavedGroup>> listGroups() async {
    final data = await apiClient.getJson('/api/discovery/saved/groups');
    return _mapGroups(data['groups']);
  }

  Future<SavedGroup> createGroup({
    required String name,
    required String shopName,
    String? shopId,
    required Map<String, int> items,
  }) async {
    final data = await apiClient.postJson('/api/discovery/saved/groups', {
      'name': name,
      'shopName': shopName,
      if (shopId != null && shopId.isNotEmpty) 'shopId': shopId,
      'items': _encodeItems(items),
    });
    return _mapGroup(Map<String, dynamic>.from(data['group'] as Map));
  }

  Future<SavedGroup> updateGroup(
    SavedGroup group, {
    String? name,
    String? shopName,
    Map<String, int>? items,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (shopName != null) 'shopName': shopName,
      if (items != null) 'items': _encodeItems(items),
    };
    final data = await apiClient.patchJson(
      '/api/discovery/saved/groups/${group.id}',
      body,
    );
    return _mapGroup(Map<String, dynamic>.from(data['group'] as Map));
  }

  Future<void> deleteGroup(String groupId) {
    return apiClient.deleteJson('/api/discovery/saved/groups/$groupId');
  }

  List<Map<String, dynamic>> _encodeItems(Map<String, int> items) {
    return items.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => {
            'shelfItemId': entry.key,
            'quantity': entry.value.clamp(1, 99),
          },
        )
        .toList();
  }

  List<SavedGroup> _mapGroups(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => _mapGroup(Map<String, dynamic>.from(item)))
        .toList();
  }

  SavedGroup _mapGroup(Map<String, dynamic> group) {
    final products = (group['products'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapProduct(Map<String, dynamic>.from(raw)))
        .toList();
    final productDetails = {
      for (final product in products) product.id: product,
    };
    final itemMap = <String, int>{};
    final rawItems = group['items'];
    if (rawItems is Map) {
      for (final entry in rawItems.entries) {
        final productId = entry.key?.toString();
        final quantity = (entry.value as num?)?.toInt() ?? 0;
        if (productId != null && productId.isNotEmpty && quantity > 0) {
          itemMap[productId] = quantity;
        }
      }
    }

    return SavedGroup(
      id: group['id']?.toString() ?? '',
      name: group['name']?.toString() ?? 'Saved group',
      shopName: group['shopName']?.toString() ?? 'Local shop',
      shopId: group['shopId']?.toString(),
      createdAt: DateTime.tryParse(group['createdAt']?.toString() ?? ''),
      items: itemMap,
      productDetails: productDetails,
    );
  }

  Product _mapProduct(Map<String, dynamic> item) {
    final shop = Map<String, dynamic>.from(item['shop'] as Map? ?? {});
    final priceCents = item['priceCents'] as int? ?? 0;
    final stock = item['stockQty'] as int? ?? 0;
    final category = item['category']?.toString();
    final shopCategory = shop['category']?.toString();
    final badge =
        (category?.isNotEmpty == true ? category : shopCategory) ?? 'Live';
    final rupees = priceCents / 100;

    return Product(
      item['id']?.toString() ?? '',
      item['name']?.toString() ?? 'Shelf item',
      'Rs ${rupees.toStringAsFixed(priceCents % 100 == 0 ? 0 : 2)}',
      shop['name']?.toString() ?? 'Local shop',
      badge,
      stock == 1 ? '1 left' : '$stock left',
      Icons.shopping_bag_outlined,
      const Color(0xFFE8F5E9),
      imageUrl: item['imageUrl']?.toString(),
      shopId: shop['id']?.toString(),
      shopBlock: shop['block']?.toString(),
      shopCategory: shopCategory,
      shopAddress: shop['address']?.toString(),
      paymentQrPayload: shop['paymentQrPayload']?.toString(),
      upiId: shop['upiId']?.toString(),
      description: item['description']?.toString(),
      shopAvatarUrl: shop['avatarUrl']?.toString(),
      shopMapUrl: shop['mapUrl']?.toString(),
      shopFollowerCount: shop['followerCount'] as int? ?? 0,
      shopRating: (shop['rating'] as num?)?.toDouble() ?? 0,
      isFollowingShop: shop['isFollowing'] == true,
      isSaved: item['isSaved'] == true,
      promotionId: item['promotionId']?.toString(),
    );
  }
}

class ShopProfileService {
  Future<List<Shop>> listShops({String query = ''}) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final suffix = encoded.isEmpty ? '' : '?q=$encoded';
    final data = await apiClient.getJson('/api/discovery/shops$suffix');
    return (data['shops'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapShop(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<Shop> getShop(String shopId) async {
    final data = await apiClient.getJson('/api/discovery/shops/$shopId');
    return _mapShop(Map<String, dynamic>.from(data['shop'] as Map));
  }

  Future<Shop> followShop(String shopId) async {
    final data = await apiClient.postJson(
      '/api/discovery/shops/$shopId/follow',
      {},
    );
    return _mapShop(Map<String, dynamic>.from(data['shop'] as Map));
  }

  Future<Shop> unfollowShop(String shopId) async {
    final data = await apiClient.deleteJsonWithResponse(
      '/api/discovery/shops/$shopId/follow',
    );
    return _mapShop(Map<String, dynamic>.from(data['shop'] as Map));
  }

  Shop _mapShop(Map<String, dynamic> shop) {
    final latitude = (shop['latitude'] as num?)?.toDouble();
    final longitude = (shop['longitude'] as num?)?.toDouble();
    final items = (shop['items'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return ShopShelfItem(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? 'Item',
            category: item['category']?.toString(),
            barcode: item['barcode']?.toString(),
            stockQty: (item['stockQty'] as num?)?.toInt() ?? 0,
            priceCents: (item['priceCents'] as num?)?.toInt() ?? 0,
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
    return Shop(
      shop['name']?.toString() ?? 'Shop',
      shop['block']?.toString() ?? '',
      shop['category']?.toString() ?? 'Local shop',
      ((shop['rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
      '${shop['followerCount'] as int? ?? 0}',
      LatLng(latitude ?? 17.7292, longitude ?? 83.3150),
      id: shop['id']?.toString(),
      address: shop['address']?.toString(),
      paymentQrPayload: shop['paymentQrPayload']?.toString(),
      upiId: shop['upiId']?.toString(),
      phone: shop['phone']?.toString(),
      avatarUrl: shop['avatarUrl']?.toString(),
      mapUrl: shop['mapUrl']?.toString(),
      followerCount: shop['followerCount'] as int? ?? 0,
      ratingValue: (shop['rating'] as num?)?.toDouble() ?? 0,
      isFollowing: shop['isFollowing'] == true,
      sellerId: shop['sellerId']?.toString() ?? shop['seller_id']?.toString(),
      items: items,
    );
  }
}

final shopProfileService = ShopProfileService();

class LiveEvent {
  const LiveEvent({required this.type, required this.payload});

  final String type;
  final Map<String, dynamic> payload;
}

class LiveSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  String? _connectedToken;
  final StreamController<LiveEvent> _events =
      StreamController<LiveEvent>.broadcast();
  final ValueNotifier<Set<String>> onlineUserIds = ValueNotifier<Set<String>>(
    <String>{},
  );

  Stream<LiveEvent> get events => _events.stream;
  bool get isConnected => _channel != null;
  bool isUserOnline(String? userId) =>
      userId != null && onlineUserIds.value.contains(userId);

  void connect() {
    final token = apiClient.token;
    if (token == null || token.isEmpty) return;
    if (_channel != null && _connectedToken == token) return;
    if (_channel != null && _connectedToken != token) {
      disconnect();
    }

    final base = Uri.parse(apiClient.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final uri = base.replace(
      scheme: scheme,
      path: '/ws',
      queryParameters: {'token': token},
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _connectedToken = token;
    _socketSub = channel.stream.listen(
      _handleRawEvent,
      onDone: disconnect,
      onError: (_) => disconnect(),
      cancelOnError: true,
    );
  }

  void disconnect() {
    _socketSub?.cancel();
    _socketSub = null;
    _channel?.sink.close();
    _channel = null;
    _connectedToken = null;
  }

  void send(String type, Map<String, dynamic> payload) {
    connect();
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode({'type': type, 'payload': payload}));
  }

  void sendChatMessage({
    required String roomId,
    required String text,
    String scope = 'chat',
    String? shopId,
    String? targetUserId,
    String? id,
    String type = 'text',
    String? mediaUrl,
    String? mediaName,
    String? mediaMime,
    int? mediaSizeBytes,
    int? mediaDurationSeconds,
  }) {
    send('chat.message', {
      'id': id,
      'roomId': roomId,
      'scope': scope,
      'text': text,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaName != null) 'mediaName': mediaName,
      if (mediaMime != null) 'mediaMime': mediaMime,
      if (mediaSizeBytes != null) 'mediaSizeBytes': mediaSizeBytes,
      if (mediaDurationSeconds != null)
        'mediaDurationSeconds': mediaDurationSeconds,
      if (shopId != null) 'shopId': shopId,
      if (targetUserId != null) 'targetUserId': targetUserId,
    });
  }

  void sendChatDelete({required String roomId, required String messageId}) {
    send('chat.delete', {'roomId': roomId, 'id': messageId});
  }

  void sendChatReaction({
    required String roomId,
    required String messageId,
    required String? reaction,
  }) {
    send('chat.react', {
      'roomId': roomId,
      'id': messageId,
      if (reaction != null) 'reaction': reaction,
    });
  }

  void sendChatTyping({
    required String roomId,
    required String scope,
    String? shopId,
    String? targetUserId,
    bool isTyping = true,
  }) {
    send('chat.typing', {
      'roomId': roomId,
      'scope': scope,
      'isTyping': isTyping,
      if (shopId != null) 'shopId': shopId,
      if (targetUserId != null) 'targetUserId': targetUserId,
    });
  }

  void sendChatRead(String roomId) {
    send('chat.read', {'roomId': roomId});
  }

  void sendCallStart({
    required String id,
    required String roomId,
    required String kind,
    String scope = 'shop_payment',
    String? shopId,
    String? targetUserId,
  }) {
    send('call.start', {
      'id': id,
      'roomId': roomId,
      'scope': scope,
      'kind': kind,
      if (shopId != null) 'shopId': shopId,
      if (targetUserId != null) 'targetUserId': targetUserId,
    });
  }

  void sendCallEnd({required String id, String status = 'ended'}) {
    send('call.end', {'id': id, 'status': status});
  }

  void _handleRawEvent(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final type = data['type']?.toString() ?? 'unknown';
      final payload = Map<String, dynamic>.from(data['payload'] as Map? ?? {});
      if (type == 'presence.snapshot') {
        onlineUserIds.value = (payload['onlineUserIds'] as List? ?? const [])
            .map((id) => id.toString())
            .toSet();
      } else if (type == 'presence.update') {
        final userId = payload['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final next = {...onlineUserIds.value};
          if (payload['isOnline'] == true) {
            next.add(userId);
          } else {
            next.remove(userId);
          }
          onlineUserIds.value = next;
        }
      }
      _events.add(LiveEvent(type: type, payload: payload));
    } catch (error) {
      debugPrint('Realtime parse failed: $error');
    }
  }
}

final liveSocketService = LiveSocketService();

Future<void> openShopLocation(
  BuildContext context, {
  required String shopName,
  String? mapUrl,
  LatLng? destination,
}) async {
  final trimmedUrl = mapUrl?.trim() ?? '';
  if (trimmedUrl.isNotEmpty) {
    final uri = Uri.tryParse(trimmedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  globalMapState.value = MapState(
    mode: MapMode.routing,
    destinationName: shopName,
    destination: destination,
  );
  if (context.mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

Future<void> openMediaDownload(
  BuildContext context, {
  required String? mediaPath,
  required String title,
}) async {
  final trimmed = mediaPath?.trim() ?? '';
  if (trimmed.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No media file is available to download.'),
        ),
      );
    }
    return;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open $title from the browser menu to save it locally.'),
      ),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.isRead,
    this.createdAt,
    this.actorName,
    this.shopId,
    this.shopName,
    this.shopAvatarUrl,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime? createdAt;
  final String? actorName;
  final String? shopId;
  final String? shopName;
  final String? shopAvatarUrl;
}

class AppNotificationService {
  Future<List<AppNotification>> list() async {
    final data = await apiClient.getJson('/api/notifications');
    return (data['notifications'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapNotification(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<void> markAllRead() {
    return apiClient.patchJson('/api/notifications/read-all', {}).then((_) {});
  }

  Future<void> markRead(String notificationId) {
    return apiClient
        .patchJson('/api/notifications/$notificationId/read', {})
        .then((_) {});
  }

  Future<void> clearAll() {
    return apiClient.deleteJson('/api/notifications');
  }

  Future<void> remove(String notificationId) {
    return apiClient.deleteJson('/api/notifications/$notificationId');
  }

  AppNotification _mapNotification(Map<String, dynamic> item) {
    return AppNotification(
      id: item['id']?.toString() ?? '',
      type: item['type']?.toString() ?? 'notification',
      title: item['title']?.toString() ?? '',
      body: item['body']?.toString(),
      isRead: item['isRead'] == true,
      createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? ''),
      actorName: item['actorName']?.toString(),
      shopId: item['shopId']?.toString(),
      shopName: item['shopName']?.toString(),
      shopAvatarUrl: item['shopAvatarUrl']?.toString(),
    );
  }
}

final appNotificationService = AppNotificationService();

class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.roomId,
    required this.scope,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.deliveryStatus,
    this.deliveredAt,
    this.readAt,
    this.type = 'text',
    this.mediaUrl,
    this.mediaName,
    this.mediaMime,
    this.mediaSizeBytes,
    this.mediaDurationSeconds,
    this.reaction,
    this.deletedAt,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String scope;
  final String text;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String deliveryStatus;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String type;
  final String? mediaUrl;
  final String? mediaName;
  final String? mediaMime;
  final int? mediaSizeBytes;
  final int? mediaDurationSeconds;
  final String? reaction;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  bool get isMine => senderId == authService.currentUser.value?.id;
}

class ChatRoomRecord {
  const ChatRoomRecord({
    required this.roomId,
    required this.scope,
    required this.lastMessage,
    this.updatedAt,
    this.shopId,
    this.shopName,
    this.shopCategory,
    this.shopBlock,
    this.shopAvatarUrl,
    this.shopSellerId,
    this.shopSellerOnline = false,
    this.unreadCount = 0,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAvatarUrl,
    this.customerOnline = false,
  });

  final String roomId;
  final String scope;
  final String lastMessage;
  final DateTime? updatedAt;
  final String? shopId;
  final String? shopName;
  final String? shopCategory;
  final String? shopBlock;
  final String? shopAvatarUrl;
  final String? shopSellerId;
  final bool shopSellerOnline;
  final int unreadCount;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAvatarUrl;
  final bool customerOnline;
}

class ChatHistoryService {
  Future<List<ChatRoomRecord>> listRooms({
    String scope = 'shop_payment',
  }) async {
    final data = await apiClient.getJson('/api/chats/rooms?scope=$scope');
    return (data['rooms'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapRoom(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<List<ChatMessageRecord>> listRoomMessages(String roomId) async {
    final encodedRoom = Uri.encodeComponent(roomId);
    final data = await apiClient.getJson(
      '/api/chats/rooms/$encodedRoom/messages',
    );
    return (data['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapMessage(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<void> hideRoom(String roomId) async {
    final encodedRoom = Uri.encodeComponent(roomId);
    await apiClient.deleteJson('/api/chats/rooms/$encodedRoom');
  }

  ChatRoomRecord _mapRoom(Map<String, dynamic> item) {
    final customer = Map<String, dynamic>.from(item['customer'] as Map? ?? {});
    return ChatRoomRecord(
      roomId: item['roomId']?.toString() ?? '',
      scope: item['scope']?.toString() ?? 'chat',
      lastMessage: item['lastMessage']?.toString() ?? '',
      updatedAt: DateTime.tryParse(item['updatedAt']?.toString() ?? ''),
      shopId: item['shopId']?.toString(),
      shopName: item['shopName']?.toString(),
      shopCategory: item['shopCategory']?.toString(),
      shopBlock: item['shopBlock']?.toString(),
      shopAvatarUrl: item['shopAvatarUrl']?.toString(),
      shopSellerId: item['shopSellerId']?.toString(),
      shopSellerOnline: item['shopSellerOnline'] == true,
      unreadCount: item['unreadCount'] as int? ?? 0,
      customerId: customer['id']?.toString(),
      customerName: customer['name']?.toString(),
      customerPhone: customer['phone']?.toString(),
      customerEmail: customer['email']?.toString(),
      customerAvatarUrl: customer['avatarUrl']?.toString(),
      customerOnline: customer['isOnline'] == true,
    );
  }

  ChatMessageRecord _mapMessage(Map<String, dynamic> item) {
    final sender = Map<String, dynamic>.from(item['sender'] as Map? ?? {});
    return ChatMessageRecord(
      id: item['id']?.toString() ?? '',
      roomId: item['roomId']?.toString() ?? '',
      scope: item['scope']?.toString() ?? 'chat',
      text: item['text']?.toString() ?? '',
      senderId: sender['id']?.toString() ?? '',
      senderName: sender['name']?.toString() ?? 'Neighbor',
      senderRole: sender['role']?.toString() ?? 'user',
      deliveryStatus: item['deliveryStatus']?.toString() ?? 'sent_online',
      deliveredAt: DateTime.tryParse(item['deliveredAt']?.toString() ?? ''),
      readAt: DateTime.tryParse(item['readAt']?.toString() ?? ''),
      type: item['type']?.toString() ?? 'text',
      mediaUrl: item['mediaUrl']?.toString(),
      mediaName: item['mediaName']?.toString(),
      mediaMime: item['mediaMime']?.toString(),
      mediaSizeBytes: item['mediaSizeBytes'] as int?,
      mediaDurationSeconds: item['mediaDurationSeconds'] as int?,
      reaction: item['reaction']?.toString(),
      deletedAt: DateTime.tryParse(item['deletedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? ''),
    );
  }
}

final chatHistoryService = ChatHistoryService();

class PlatformSettings {
  const PlatformSettings({
    required this.commissionRate,
    required this.promotion3DayRate,
    required this.promotion7DayRate,
    required this.promotion30DayRate,
    required this.notificationHubEnabled,
    required this.notificationDriver,
    required this.dbPollingIntervalMs,
  });

  final double commissionRate;
  final double promotion3DayRate;
  final double promotion7DayRate;
  final double promotion30DayRate;
  final bool notificationHubEnabled;
  final String notificationDriver;
  final int dbPollingIntervalMs;

  double get commissionPercent => commissionRate * 100;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return PlatformSettings(
      commissionRate: number('commissionRate', 0.04).clamp(0.0, 0.25),
      promotion3DayRate: number('promotion3DayRate', 30),
      promotion7DayRate: number('promotion7DayRate', 60),
      promotion30DayRate: number('promotion30DayRate', 150),
      notificationHubEnabled: json['notificationHubEnabled'] != false,
      notificationDriver:
          json['notificationDriver']?.toString() ?? 'PostgreSQL (pg_notify)',
      dbPollingIntervalMs:
          (json['dbPollingIntervalMs'] as num?)?.toInt() ??
          int.tryParse(json['dbPollingIntervalMs']?.toString() ?? '') ??
          250,
    );
  }

  Map<String, dynamic> toJson() => {
    'commissionRate': commissionRate,
    'promotion3DayRate': promotion3DayRate,
    'promotion7DayRate': promotion7DayRate,
    'promotion30DayRate': promotion30DayRate,
    'notificationHubEnabled': notificationHubEnabled,
    'notificationDriver': notificationDriver,
    'dbPollingIntervalMs': dbPollingIntervalMs,
  };

  PlatformSettings copyWith({
    double? commissionRate,
    double? promotion3DayRate,
    double? promotion7DayRate,
    double? promotion30DayRate,
    bool? notificationHubEnabled,
    String? notificationDriver,
    int? dbPollingIntervalMs,
  }) {
    return PlatformSettings(
      commissionRate: commissionRate ?? this.commissionRate,
      promotion3DayRate: promotion3DayRate ?? this.promotion3DayRate,
      promotion7DayRate: promotion7DayRate ?? this.promotion7DayRate,
      promotion30DayRate: promotion30DayRate ?? this.promotion30DayRate,
      notificationHubEnabled:
          notificationHubEnabled ?? this.notificationHubEnabled,
      notificationDriver: notificationDriver ?? this.notificationDriver,
      dbPollingIntervalMs: dbPollingIntervalMs ?? this.dbPollingIntervalMs,
    );
  }
}

class PlatformSettingsService {
  final settings = ValueNotifier<PlatformSettings>(
    const PlatformSettings(
      commissionRate: 0.04,
      promotion3DayRate: 30,
      promotion7DayRate: 60,
      promotion30DayRate: 150,
      notificationHubEnabled: true,
      notificationDriver: 'PostgreSQL (pg_notify)',
      dbPollingIntervalMs: 250,
    ),
  );

  Future<PlatformSettings> load() async {
    final data = await apiClient.getJson('/api/settings/platform');
    final loaded = PlatformSettings.fromJson(
      Map<String, dynamic>.from(data['settings'] as Map? ?? {}),
    );
    settings.value = loaded;
    return loaded;
  }

  Future<PlatformSettings> adminLoad() async {
    final data = await apiClient.getJson('/api/admin/settings');
    final loaded = PlatformSettings.fromJson(
      Map<String, dynamic>.from(data['settings'] as Map? ?? {}),
    );
    settings.value = loaded;
    return loaded;
  }

  Future<PlatformSettings> adminSave(PlatformSettings value) async {
    final data = await apiClient.patchJson('/api/admin/settings', {
      'settings': value.toJson(),
    });
    final saved = PlatformSettings.fromJson(
      Map<String, dynamic>.from(data['settings'] as Map? ?? {}),
    );
    settings.value = saved;
    return saved;
  }
}

final platformSettingsService = PlatformSettingsService();

Future<void> openProductCheckout(BuildContext context, Product product) async {
  final qrPayload = product.paymentQrPayload;
  if (qrPayload == null || qrPayload.trim().isEmpty) {
    push(context, CheckoutPage(product: product));
    return;
  }

  try {
    final session = await paymentSessionService.scanPaymentQr(qrPayload);
    if (!context.mounted) return;
    int availableStock(Product item) {
      final raw = item.stock.toLowerCase().trim();
      if (raw.contains('out')) return 0;
      final match = RegExp(r'\d+').firstMatch(raw);
      return match == null ? 999 : int.tryParse(match.group(0) ?? '') ?? 0;
    }

    final productName = product.name.toLowerCase().trim();
    Product? matchingProduct;
    for (final item in session.products) {
      if (item.id == product.id) {
        matchingProduct = item;
        break;
      }
    }
    if (matchingProduct == null) {
      for (final item in session.products) {
        if (item.name.toLowerCase().trim() == productName) {
          matchingProduct = item;
          break;
        }
      }
    }
    matchingProduct ??= session.products.isNotEmpty
        ? session.products.first
        : null;
    final prefilledCart = <String, int>{};
    if (matchingProduct != null && availableStock(matchingProduct) > 0) {
      prefilledCart[matchingProduct.id] = 1;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} is out of stock right now.')),
      );
    }
    push(
      context,
      SmartScanCheckoutPage(
        shop: session.shop,
        color: primary,
        prefilledCart: prefilledCart,
        scannedProducts: session.products,
        gatewayProviders: session.providers,
        preferredGatewayProvider: session.preferredProvider,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open live shelf: $error')),
    );
  }
}

class SellerBackendService {
  Future<Map<String, dynamic>> getShop() async {
    final data = await apiClient.getJson('/api/seller/shop');
    return Map<String, dynamic>.from(data['shop'] as Map);
  }

  Future<Map<String, dynamic>> syncCurrentShopProfile() async {
    final shop = await getShop();
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'name':
          shop['name']?.toString() ??
          globalSellerShopProfile.value['name'] ??
          'My Shop',
      'address':
          shop['address']?.toString() ??
          globalSellerShopProfile.value['address'] ??
          '',
      'category': shop['category']?.toString() ?? 'Local shop',
      'block': shop['block']?.toString() ?? '',
      'upiId': shop['upi_id']?.toString() ?? '',
      'paymentQrPayload': shop['payment_qr_payload']?.toString() ?? '',
      'payoutStatus': shop['payout_status']?.toString() ?? 'sandbox_ready',
      'gatewayProvider': shop['gateway_provider']?.toString() ?? 'mock_gateway',
      'paymentQrUpdatedAt': shop['payment_qr_updated_at']?.toString() ?? '',
      'mapUrl': shop['map_url']?.toString() ?? '',
      'followerCount': '${shop['follower_count'] as int? ?? 0}',
      'rating': '${shop['rating'] ?? 0}',
      'avatarUrl': shop['avatar_url']?.toString() ?? '',
      'isOpen': (shop['is_open'] == false ? false : true).toString(),
    };
    return shop;
  }

  Future<Map<String, dynamic>> getPaymentProfile() async {
    final data = await apiClient.getJson('/api/seller/payment-profile');
    return Map<String, dynamic>.from(data['paymentProfile'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> updatePaymentProfile({
    String? paymentQrPayload,
    String? upiId,
    String? gatewayProvider,
    bool clearPaymentQr = false,
  }) async {
    final data = await apiClient.patchJson('/api/seller/payment-profile', {
      if (clearPaymentQr) 'clearPaymentQr': true,
      if (paymentQrPayload != null && paymentQrPayload.trim().isNotEmpty)
        'paymentQrPayload': paymentQrPayload.trim(),
      if (upiId != null && upiId.trim().isNotEmpty) 'upiId': upiId.trim(),
      if (gatewayProvider != null && gatewayProvider.trim().isNotEmpty)
        'gatewayProvider': gatewayProvider.trim(),
    });
    await syncCurrentShopProfile();
    return Map<String, dynamic>.from(data['paymentProfile'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> updateShop({
    String? name,
    String? category,
    String? block,
    String? address,
    String? paymentQrPayload,
    String? upiId,
    String? avatarUrl,
    String? mapUrl,
    bool? isOpen,
    bool clearPaymentQr = false,
  }) async {
    final data = await apiClient.patchJson('/api/seller/shop', {
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (category != null) 'category': category.trim(),
      if (block != null) 'block': block.trim(),
      if (address != null) 'address': address.trim(),
      if (clearPaymentQr) 'clearPaymentQr': true,
      if (paymentQrPayload != null && paymentQrPayload.trim().isNotEmpty)
        'paymentQrPayload': paymentQrPayload.trim(),
      if (upiId != null && upiId.trim().isNotEmpty) 'upiId': upiId.trim(),
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        'avatarUrl': avatarUrl.trim(),
      if (mapUrl != null && mapUrl.trim().isNotEmpty) 'mapUrl': mapUrl.trim(),
      if (isOpen != null) 'isOpen': isOpen,
    });
    final shop = Map<String, dynamic>.from(data['shop'] as Map);
    await syncCurrentShopProfile();
    return shop;
  }

  Future<Map<String, dynamic>> decodePaymentQrImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final imageData = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final data = await apiClient.postJson(
      '/api/seller/payment-qr/decode-image',
      {'imageData': imageData},
    );
    return {
      'payload': data['payload']?.toString() ?? '',
      'upiId': data['upiId']?.toString(),
    };
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    final data = await apiClient.getJson('/api/seller/items');
    return (data['items'] as List<dynamic>)
        .map((item) => _mapShelfItem(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> lookupBarcode(String barcode) async {
    final code = Uri.encodeComponent(barcode.trim());
    final data = await apiClient.getJson('/api/seller/barcode-lookup/$code');
    return {
      'found': data['found'] == true,
      'barcode': data['barcode']?.toString() ?? barcode.trim(),
      'item': Map<String, dynamic>.from(data['item'] as Map? ?? {}),
    };
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final data = await apiClient.getJson('/api/seller/dashboard');
    return {
      'shop': Map<String, dynamic>.from(data['shop'] as Map? ?? {}),
      'summary': Map<String, dynamic>.from(data['summary'] as Map? ?? {}),
      'recentPayments': (data['recentPayments'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(),
      'analyticsPayments': (data['analyticsPayments'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(),
      'topItems': (data['topItems'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(),
    };
  }

  Future<List<Map<String, dynamic>>> getPromotions() async {
    final data = await apiClient.getJson('/api/seller/promotions');
    return (data['promotions'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
  }

  Future<Map<String, dynamic>> createPromotion({
    required String shelfItemId,
    required int durationDays,
    required int amountCents,
  }) async {
    final data = await apiClient.postJson('/api/seller/promotions', {
      'shelfItemId': shelfItemId,
      'durationDays': durationDays,
      'amountCents': amountCents,
    });
    return Map<String, dynamic>.from(data['promotion'] as Map? ?? {});
  }

  Future<Product> createItem({
    required String name,
    required double price,
    required int stock,
    String? category,
    String? barcode,
    String? description,
    String? imageUrl,
    int? alertThreshold,
    bool alertEnabled = true,
    bool isActive = true,
  }) async {
    final data = await apiClient.postJson('/api/seller/items', {
      'name': name,
      'priceCents': (price * 100).round(),
      'stockQty': stock,
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (barcode != null && barcode.trim().isNotEmpty)
        'barcode': barcode.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      if (alertThreshold != null) 'alertThreshold': alertThreshold,
      'alertEnabled': alertEnabled,
      'isActive': isActive,
    });
    final item = _mapShelfItem(Map<String, dynamic>.from(data['item'] as Map));
    return Product(
      item['id'].toString(),
      item['name'].toString(),
      '₹${item['rate']}',
      globalSellerShopProfile.value['name'] ?? 'My Shop',
      'Live',
      '${item['stock']} left',
      item['icon'] as IconData,
      item['color'] as Color,
      imageUrl: item['imageUrl']?.toString(),
    );
  }

  Future<Map<String, dynamic>> updateItem(
    String itemId, {
    String? name,
    double? price,
    int? stock,
    String? category,
    String? barcode,
    String? description,
    String? imageUrl,
    int? alertThreshold,
    bool? alertEnabled,
    bool? isActive,
  }) async {
    final data = await apiClient.patchJson('/api/seller/items/$itemId', {
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (price != null) 'priceCents': (price * 100).round(),
      if (stock != null) 'stockQty': stock,
      if (category != null) 'category': category.trim(),
      if (barcode != null) 'barcode': barcode.trim(),
      if (description != null) 'description': description.trim(),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      if (alertThreshold != null) 'alertThreshold': alertThreshold,
      if (alertEnabled != null) 'alertEnabled': alertEnabled,
      if (isActive != null) 'isActive': isActive,
    });
    return _mapShelfItem(Map<String, dynamic>.from(data['item'] as Map));
  }

  Future<void> deleteItem(String itemId) {
    return apiClient.deleteJson('/api/seller/items/$itemId');
  }

  Map<String, dynamic> _mapShelfItem(Map<String, dynamic> item) {
    final priceCents = item['price_cents'] as int? ?? 0;
    final stock = item['stock_qty'] as int? ?? 0;
    return {
      'id': item['id']?.toString() ?? '',
      'name': item['name']?.toString() ?? '',
      'rate': (priceCents / 100).toStringAsFixed(priceCents % 100 == 0 ? 0 : 2),
      'stock': stock,
      'category': item['category']?.toString() ?? '',
      'barcode': item['barcode']?.toString() ?? '',
      'description': item['description']?.toString() ?? '',
      'threshold': item['alert_threshold'] as int? ?? 3,
      'alertEnabled': item['alert_enabled'] as bool? ?? true,
      'isAlerting':
          (item['alert_enabled'] as bool? ?? true) &&
          stock <= (item['alert_threshold'] as int? ?? 3),
      'isActive': item['is_active'] as bool? ?? true,
      'icon': Icons.shopping_bag_outlined,
      'color': const Color(0xFFE8F5E9),
      'imageUrl': item['image_url'],
    };
  }
}

// ─── LOCALIZATION SERVICE ─────────────────────────────────────

class AppLanguage {
  final String name;
  final String nativeName;
  final String code;
  final String flag;

  AppLanguage({
    required this.name,
    required this.nativeName,
    required this.code,
    required this.flag,
  });
}

final List<AppLanguage> supportedLanguages = [
  AppLanguage(name: 'English', nativeName: 'English', code: 'en', flag: '🇺🇸'),
  AppLanguage(name: 'Hindi', nativeName: 'हिन्दी', code: 'hi', flag: '🇮🇳'),
  AppLanguage(name: 'Telugu', nativeName: 'తెలుగు', code: 'te', flag: '🇮🇳'),
  AppLanguage(name: 'Tamil', nativeName: 'தமிழ்', code: 'ta', flag: '🇮🇳'),
  AppLanguage(name: 'Bengali', nativeName: 'বাংলা', code: 'bn', flag: '🇮🇳'),
  AppLanguage(name: 'Spanish', nativeName: 'Español', code: 'es', flag: '🇪🇸'),
];

class LocalizationService {
  final currentLanguage = ValueNotifier<AppLanguage>(supportedLanguages[0]);

  void setLanguage(AppLanguage lang) {
    currentLanguage.value = lang;
  }

  String translate(String key) {
    final code = currentLanguage.value.code;
    final map = _translations[key];
    if (map == null) return key;
    return map[code] ?? map['en'] ?? key;
  }

  final Map<String, Map<String, String>> _translations = {
    'Home': {'en': 'Home', 'hi': 'होम', 'te': 'హోమ్'},
    'Settings': {'en': 'Settings', 'hi': 'सेटिंग्स', 'te': 'సెట్టింగులు'},
    'My Settings': {
      'en': 'My Settings',
      'hi': 'मेरी सेटिंग्स',
      'te': 'నా సెట్టింగులు',
    },
    'Scanner': {'en': 'Scanner', 'hi': 'स्कैनर', 'te': 'స్కానర్'},
    'Cart': {'en': 'Cart', 'hi': 'कार्ट', 'te': 'కార్ట్'},
    'Map': {'en': 'Map', 'hi': 'मैप', 'te': 'మ్యాప్'},
  };
}

final localizationService = LocalizationService();

class SettingsPreferencesService {
  final preferences = ValueNotifier<Map<String, dynamic>>({});

  Future<Map<String, dynamic>> load() async {
    final data = await apiClient.getJson('/api/settings/me');
    final prefs = Map<String, dynamic>.from(data['preferences'] as Map? ?? {});
    preferences.value = {...preferences.value, ...prefs};
    _applyAppPreferences(preferences.value);
    return preferences.value;
  }

  Future<Map<String, dynamic>> savePatch(Map<String, dynamic> patch) async {
    preferences.value = _mergeMaps(preferences.value, patch);
    final data = await apiClient.patchJson('/api/settings/me', {
      'preferences': patch,
    });
    final prefs = Map<String, dynamic>.from(data['preferences'] as Map? ?? {});
    preferences.value = prefs;
    _applyAppPreferences(preferences.value);
    return preferences.value;
  }

  bool boolValue(String key, bool fallback) {
    final value = preferences.value[key];
    return value is bool ? value : fallback;
  }

  String stringValue(String key, String fallback) {
    final value = preferences.value[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  void _applyAppPreferences(Map<String, dynamic> prefs) {
    final languageCode = prefs['appLanguage'];
    if (languageCode is String) {
      final match = supportedLanguages.where(
        (lang) => lang.code == languageCode,
      );
      if (match.isNotEmpty) {
        localizationService.setLanguage(match.first);
      }
    }

    final darkMode = prefs['darkMode'];
    if (darkMode is bool) {
      themeController.themeMode.value = darkMode
          ? ThemeMode.dark
          : ThemeMode.light;
    }

    final tone = prefs['notificationTone'];
    if (tone is String && soundService.availableTones.contains(tone)) {
      soundService.selectedTone.value = tone;
    }

    final autoReply = prefs['sellerAutoReply'];
    if (autoReply is Map) {
      globalAutoReplyConfig.value = {
        ...globalAutoReplyConfig.value,
        ...Map<String, dynamic>.from(autoReply),
      };
    }

    final hubs = prefs['locationHubs'];
    if (hubs is List && hubs.isNotEmpty) {
      locationController.hubsNotifier.value = hubs.whereType<Map>().map((hub) {
        final map = Map<String, dynamic>.from(hub);
        return LocationHub(
          map['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          map['name']?.toString() ?? 'Neighborhood',
          map['address']?.toString() ?? '',
        );
      }).toList();
    }

    final activeHubId = prefs['activeLocationHubId'];
    if (activeHubId is String) {
      final matches = locationController.hubsNotifier.value.where(
        (hub) => hub.id == activeHubId,
      );
      if (matches.isNotEmpty) {
        locationController.activeHub.value = matches.first;
      }
    }
  }

  Map<String, dynamic> _mergeMaps(
    Map<String, dynamic> current,
    Map<String, dynamic> patch,
  ) {
    final merged = Map<String, dynamic>.from(current);
    patch.forEach((key, value) {
      final existing = merged[key];
      if (existing is Map && value is Map) {
        merged[key] = _mergeMaps(
          Map<String, dynamic>.from(existing),
          Map<String, dynamic>.from(value),
        );
      } else {
        merged[key] = value;
      }
    });
    return merged;
  }
}

final settingsPreferencesService = SettingsPreferencesService();

// ─── SUPPORT SERVICE ──────────────────────────────────────────

enum IssueStatus { pending, inProgress, resolved }

class SupportIssue {
  final String id;
  final String category;
  final String description;
  final IssueStatus status;
  final DateTime createdAt;

  SupportIssue({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
  });
}

class SupportService {
  final issues = ValueNotifier<List<SupportIssue>>([]);

  Future<List<SupportIssue>> loadIssues() async {
    final data = await apiClient.getJson('/api/support/disputes');
    final loaded = (data['disputes'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => _mapIssue(Map<String, dynamic>.from(raw)))
        .toList();
    issues.value = loaded;
    return loaded;
  }

  Future<SupportIssue> reportIssue(String category, String description) async {
    final data = await apiClient.postJson('/api/support/disputes', {
      'category': category,
      'description': description,
    });
    final newIssue = _mapIssue(
      Map<String, dynamic>.from(data['dispute'] as Map? ?? {}),
    );
    issues.value = [...issues.value, newIssue];
    return newIssue;
  }

  SupportIssue _mapIssue(Map<String, dynamic> data) {
    return SupportIssue(
      id: data['id']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Issue',
      description: data['description']?.toString() ?? '',
      status: _mapStatus(data['status']?.toString()),
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  IssueStatus _mapStatus(String? value) {
    switch (value) {
      case 'acknowledged':
        return IssueStatus.inProgress;
      case 'resolved':
        return IssueStatus.resolved;
      case 'open':
      default:
        return IssueStatus.pending;
    }
  }

  void updateIssueStatus(String id, IssueStatus status) {
    issues.value = issues.value.map((issue) {
      if (issue.id == id) {
        return SupportIssue(
          id: issue.id,
          category: issue.category,
          description: issue.description,
          status: status,
          createdAt: issue.createdAt,
        );
      }
      return issue;
    }).toList();
  }
}

final supportService = SupportService();

// ─── SAVINGS SERVICE ──────────────────────────────────────────

class SavingsData {
  final double totalSaved;
  final int localTrips;
  final double carbonSaved; // in kg

  SavingsData({
    required this.totalSaved,
    required this.localTrips,
    required this.carbonSaved,
  });
}

class SavingsService {
  final data = ValueNotifier<SavingsData>(
    SavingsData(totalSaved: 450.0, localTrips: 12, carbonSaved: 3.4),
  );

  void addSavings(double amount) {
    data.value = SavingsData(
      totalSaved: data.value.totalSaved + amount,
      localTrips: data.value.localTrips + 1,
      carbonSaved: data.value.carbonSaved + 0.2,
    );
  }
}

final savingsService = SavingsService();

final AuthService authService = BackendAuthService();
final SellerBackendService sellerBackendService = SellerBackendService();
final PaymentSessionService paymentSessionService = PaymentSessionService();
final DiscoveryService discoveryService = DiscoveryService();
final SavedGroupService savedGroupService = SavedGroupService();

// Elite Neighbor Engine Controllers
class ThemeController {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }
}

class LocationHub {
  final String id;
  final String name;
  final String address;
  LocationHub(this.id, this.name, this.address);
}

class LocationController {
  static final LocationController instance = LocationController._();
  LocationController._();

  final ValueNotifier<List<LocationHub>> hubsNotifier = ValueNotifier([
    LocationHub('home', 'Home Hub', 'Silver Towers, Block A'),
    LocationHub('work', 'Work Hub', 'Cyber Plaza, 5th Floor'),
    LocationHub('parents', 'Parents\' Apt', 'Green Valley, Sector 12'),
  ]);

  late final ValueNotifier<LocationHub> activeHub = ValueNotifier(
    hubsNotifier.value[0],
  );

  void switchHub(String id) {
    activeHub.value = hubsNotifier.value.firstWhere((h) => h.id == id);
    _save();
  }

  void addHub(String name, String address) {
    final newHub = LocationHub(
      DateTime.now().millisecondsSinceEpoch.toString(),
      name,
      address,
    );
    hubsNotifier.value = [...hubsNotifier.value, newHub];
    activeHub.value = newHub;
    _save();
  }

  void updateHub(String id, String name, String address) {
    hubsNotifier.value = hubsNotifier.value
        .map((h) => h.id == id ? LocationHub(id, name, address) : h)
        .toList();
    if (activeHub.value.id == id) {
      activeHub.value = LocationHub(id, name, address);
    }
    _save();
  }

  void deleteHub(String id) {
    if (hubsNotifier.value.length <= 1) return; // Prevent deleting the last hub
    hubsNotifier.value = hubsNotifier.value.where((h) => h.id != id).toList();
    if (activeHub.value.id == id) {
      activeHub.value = hubsNotifier.value.first;
    }
    _save();
  }

  void _save() {
    settingsPreferencesService.savePatch({
      'activeLocationHubId': activeHub.value.id,
      'locationHubs': hubsNotifier.value
          .map(
            (hub) => {'id': hub.id, 'name': hub.name, 'address': hub.address},
          )
          .toList(),
    });
  }
}

final themeController = ThemeController.instance;
final locationController = LocationController.instance;
