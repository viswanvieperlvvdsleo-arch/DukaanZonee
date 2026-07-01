import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/services/device_location.dart';

class SellerInventoryPage extends StatefulWidget {
  const SellerInventoryPage({super.key});

  @override
  State<SellerInventoryPage> createState() => _SellerInventoryPageState();
}

class _SellerInventoryPageState extends State<SellerInventoryPage> {
  String get _avatarUrl => globalSellerShopProfile.value['avatarUrl']!;
  set _avatarUrl(String val) {
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'avatarUrl': val,
    };
  }

  String get _shopName => globalSellerShopProfile.value['name']!;
  set _shopName(String val) {
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'name': val,
    };
  }

  String get _shopAddress => globalSellerShopProfile.value['address']!;
  set _shopAddress(String val) {
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'address': val,
    };
  }

  String get _shopMapUrl => globalSellerShopProfile.value['mapUrl'] ?? '';
  set _shopMapUrl(String val) {
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'mapUrl': val,
    };
  }

  String get _shopPhone => globalSellerShopProfile.value['phone']!;
  set _shopPhone(String val) {
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'phone': val,
    };
  }

  String get _shopBio => globalSellerShopProfile.value['bio']!;
  set _shopBio(String val) {
    globalSellerShopProfile.value = {
      ...globalSellerShopProfile.value,
      'bio': val,
    };
  }

  String _shelfSearchQuery = '';
  bool _isUploadingImage = false;
  bool _loadingShelf = true;
  String? _shelfError;
  StreamSubscription<LiveEvent>? _liveSub;
  bool _followersPulse = false;

  final List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    // Automatic alert trigger on login/page load disabled for clean startup.
    // Low stock alerts will now trigger dynamically during real-time threshold updates.
    liveSocketService.connect();
    _liveSub = liveSocketService.events.listen(_handleLiveEvent);
    _loadShelf();
  }

  void _handleLiveEvent(LiveEvent event) {
    if (event.type != 'shop.followers.updated') return;
    final count = event.payload['followerCount'];
    if (!mounted || count == null) return;
    setState(() {
      globalSellerShopProfile.value = {
        ...globalSellerShopProfile.value,
        'followerCount': count.toString(),
      };
      _followersPulse = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _followersPulse = false);
    });
  }

  Future<void> _loadShelf() async {
    setState(() {
      _loadingShelf = true;
      _shelfError = null;
    });
    try {
      final shop = await sellerBackendService.getShop();
      final items = await sellerBackendService.getItems();
      if (!mounted) return;
      setState(() {
        globalSellerShopProfile.value = {
          ...globalSellerShopProfile.value,
          'name':
              shop['name']?.toString() ??
              globalSellerShopProfile.value['name']!,
          'address':
              shop['address']?.toString() ??
              globalSellerShopProfile.value['address']!,
          'category': shop['category']?.toString() ?? 'Local shop',
          'block': shop['block']?.toString() ?? '',
          'upiId': shop['upi_id']?.toString() ?? '',
          'paymentQrPayload': shop['payment_qr_payload']?.toString() ?? '',
          'mapUrl': shop['map_url']?.toString() ?? '',
          'followerCount': '${shop['follower_count'] as int? ?? 0}',
          'rating': '${shop['rating'] ?? 0}',
          'avatarUrl': shop['avatar_url']?.toString() ?? '',
        };
        _products
          ..clear()
          ..addAll(items);
        _loadingShelf = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _shelfError = error.toString();
        _loadingShelf = false;
      });
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        _buildSellerHeader(),
        const SizedBox(height: 32),
        _buildBioSection(),
        const SizedBox(height: 40),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Kicker('YOUR DIGITAL SHELF'),
            TapScale(
              onTap: () async {
                final dynamic result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormPage()),
                );
                if (result != null) {
                  await _loadShelf();
                }
              },
              child: const Text(
                'Add New +',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Dynamic In-line Shelf Search box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: shadowSm,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _shelfSearchQuery = val),
            decoration: InputDecoration(
              icon: const Icon(Icons.search, color: primary, size: 20),
              hintText: 'Search within your shelf...',
              border: InputBorder.none,
              hintStyle: const TextStyle(
                color: muted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              suffixIcon: _shelfSearchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() => _shelfSearchQuery = ''),
                      child: const Icon(Icons.clear, color: muted, size: 18),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_loadingShelf)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_shelfError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: muted, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    _shelfError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _loadShelf,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else
          // Grid of products (The Storefront)
          () {
            final filteredProducts = _products.where((p) {
              return p['name'].toString().toLowerCase().contains(
                _shelfSearchQuery.toLowerCase(),
              );
            }).toList();

            if (filteredProducts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 48,
                        color: muted.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No matching products found on your shelf.',
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.70,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) =>
                  _buildStorefrontCard(filteredProducts[index]),
            );
          }(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildAvatarImage({double size = 90}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: _isUploadingImage
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ProductImageView(
                imageUrl: _avatarUrl,
                fallbackIcon: Icons.storefront,
                fallbackIconSize: size * 0.42,
                fallbackColor: primary,
              ),
      ),
    );
  }

  Widget _buildSellerHeader() {
    final lowStockCount = _products
        .where((p) => p['isAlerting'] == true)
        .length;
    final followerCount =
        int.tryParse(globalSellerShopProfile.value['followerCount'] ?? '0') ??
        0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar (Top Left)
        TapScale(
          onTap: () => _showAvatarEditorDialog(),
          child: Hero(tag: 'seller_avatar', child: _buildAvatarImage(size: 90)),
        ),
        const SizedBox(width: 24),
        // Stats and Edit profile block (Right side)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Items', '${_products.length}'),
                  _buildStat(
                    'Followers',
                    '$followerCount',
                    highlighted: _followersPulse,
                  ),
                  _buildStat('Low Stock', '$lowStockCount'),
                ],
              ),
              const SizedBox(height: 16),
              TapScale(
                onTap: () => _showEditProfileDialog(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: primary),
                        SizedBox(width: 6),
                        Text(
                          'Edit Shop Profile',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, {bool highlighted = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? primary.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: highlighted ? primary : ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlighted ? primary : muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _shopName.toUpperCase(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Interactive address with inkwell / tap action
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showLocationMapDialog(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: primary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _shopAddress,
                      style: const TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.phone, color: muted, size: 14),
            const SizedBox(width: 6),
            Text(
              _shopPhone,
              style: const TextStyle(
                color: muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _shopBio,
          style: const TextStyle(
            color: ink,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildStorefrontCard(Map<String, dynamic> product) {
    final bool isAlerting = product['isAlerting'] ?? false;
    final int stock = product['stock'] ?? 0;
    final rate = product['rate'] ?? '0';

    return TapScale(
      onTap: () => push(context, SellerProductDetailPage(product: product)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isAlerting
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.grey.shade100,
            width: isAlerting ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Premium Visual Header Block
              Container(
                height: 105,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      product['color'].withOpacity(0.15),
                      product['color'].withOpacity(0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: ProductImageView(
                          imageUrl: product['imageUrl']?.toString(),
                          fallbackIcon: product['icon'] as IconData,
                          fallbackIconSize: 28,
                        ),
                      ),
                    ),
                    // Delete Button (Top-Left)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildCircleIcon(
                        Icons.delete_outline_rounded,
                        () => _showDeleteConfirm(product),
                        isDestructive: true,
                      ),
                    ),
                    // Edit Button (Top-Right)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _buildCircleIcon(
                        Icons.edit_outlined,
                        () => _showEditProductDialog(product),
                      ),
                    ),
                    // Status Badge (Bottom-Left)
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAlerting
                              ? Colors.redAccent
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: isAlerting
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAlerting
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: isAlerting ? Colors.white : success,
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAlerting ? 'LOW STOCK' : 'HEALTHY',
                              style: TextStyle(
                                color: isAlerting ? Colors.white : success,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Info Block
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: ink,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹$rate',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: primary,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isAlerting
                                      ? Colors.red.withOpacity(0.08)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$stock left',
                                  style: TextStyle(
                                    color: isAlerting ? Colors.red : muted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // 3. Action Pill Button
                      TapScale(
                        onTap: () => _showSetThreshold(product),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isAlerting
                                ? const LinearGradient(
                                    colors: [
                                      Colors.redAccent,
                                      Colors.deepOrangeAccent,
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [ink, ink.withOpacity(0.85)],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isAlerting
                                ? [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: ink.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAlerting
                                      ? Icons.notifications_active
                                      : Icons.settings_suggest_outlined,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAlerting
                                      ? 'MODIFY ALERT'
                                      : 'SET STOCK ALERT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIcon(
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: shadowSm,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : ink, size: 16),
      ),
    );
  }

  void _showAvatarEditorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Shop Cover Photo',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            // Current Image Preview
            Hero(tag: 'seller_avatar', child: _buildAvatarImage(size: 140)),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CURATED PRESETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: muted,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Presets Grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetItem(
                    'Produce',
                    'https://images.unsplash.com/photo-1542838132-92c53300491e?w=200&auto=format&fit=crop',
                  ),
                  _buildPresetItem(
                    'Bakery',
                    'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=200&auto=format&fit=crop',
                  ),
                  _buildPresetItem(
                    'Organic',
                    'https://images.unsplash.com/photo-1608686207856-001b95cf60ca?w=200&auto=format&fit=crop',
                  ),
                  _buildPresetItem(
                    'Grocery',
                    'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=200&auto=format&fit=crop',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Add Custom Image simulated button
            TapScale(
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: primary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Upload Custom Photo',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'DONE',
              style: TextStyle(color: ink, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? selected = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (selected != null && mounted) {
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: selected.path,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Shop Cover',
              toolbarColor: primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Adjust Shop Cover'),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(width: 450, height: 450),
              customDialogBuilder:
                  (cropper, crop, getResult, onRotate, onScale) {
                    return Builder(
                      builder: (dialogContext) {
                        return Dialog(
                          backgroundColor: const Color(0xFF1E293B),
                          insetPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 40,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            width: MediaQuery.of(dialogContext).size.width > 700
                                ? 600
                                : MediaQuery.of(dialogContext).size.width * 0.9,
                            height:
                                MediaQuery.of(dialogContext).size.height * 0.8,
                            child: Column(
                              children: [
                                const Text(
                                  'Adjust Shop Cover',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRect(child: cropper),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          crop();
                                          final String? resultPath =
                                              await getResult();
                                          if (mounted &&
                                              dialogContext.mounted) {
                                            Navigator.of(
                                              dialogContext,
                                            ).pop(resultPath);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        child: const Text(
                                          'Apply Crop',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          final imageData = await _croppedImageToDataUrl(croppedFile);
          await sellerBackendService.updateShop(avatarUrl: imageData);
          if (!mounted) return;
          setState(() => _avatarUrl = imageData);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shop cover picture updated successfully'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting cover image: $e')),
      );
    }
  }

  Future<String> _croppedImageToDataUrl(CroppedFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeForPath(file.path);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Widget _buildPresetItem(String label, String url) {
    final isSelected = _avatarUrl == url;
    return TapScale(
      onTap: () async {
        await sellerBackendService.updateShop(avatarUrl: url);
        setState(() => _avatarUrl = url);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.shade200,
            width: isSelected ? 3.0 : 1.0,
          ),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      ),
    );
  }

  void _showLocationMapDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: primary),
                const SizedBox(width: 8),
                const Text(
                  'Location Overview',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stylized Mini Map Placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFFE2E8F0),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Stylized Google Maps Sim Grid
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.85,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=400&auto=format&fit=crop',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Glowing marker with custom pulses
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: primary,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _shopAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Button to open the neighborhood map!
            TapScale(
              onTap: () {
                Navigator.pop(context);
                openShopLocation(
                  context,
                  shopName: _shopName,
                  mapUrl: _shopMapUrl,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Open Interactive Map Tab',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(color: ink, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _shopName);
    final addrCtrl = TextEditingController(text: _shopAddress);
    final mapCtrl = TextEditingController(text: _shopMapUrl);
    final phoneCtrl = TextEditingController(text: _shopPhone);
    final bioCtrl = TextEditingController(text: _shopBio);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text(
          'Edit Shop Details',
          style: TextStyle(fontWeight: FontWeight.w900, color: ink),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Shop Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addrCtrl,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: mapCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Map location',
                  hintText: 'Paste Google Maps link, address, or lat,lng',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final location = await getDeviceLocation();
                  if (!mounted) return;
                  if (location == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not read current location. Paste a Google Maps link instead.',
                        ),
                      ),
                    );
                    return;
                  }
                  final lat = location.latitude.toStringAsFixed(6);
                  final lng = location.longitude.toStringAsFixed(6);
                  mapCtrl.text = 'https://www.google.com/maps?q=$lat,$lng';
                  if (addrCtrl.text.trim().isEmpty ||
                      addrCtrl.text.startsWith('Pinned map location')) {
                    addrCtrl.text = 'Pinned map location ($lat, $lng)';
                  }
                },
                icon: const Icon(Icons.my_location_outlined),
                label: const Text('Use current location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Contact Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Shop Bio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.info_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: muted, fontWeight: FontWeight.w900),
            ),
          ),
          GradientButton('Save Profile', Icons.check, () async {
            try {
              await authService.updateProfile(mobile: phoneCtrl.text);
              await sellerBackendService.updateShop(
                name: nameCtrl.text,
                address: addrCtrl.text,
                mapUrl: mapCtrl.text,
              );
              await settingsPreferencesService.savePatch({
                'sellerShelfBio': bioCtrl.text,
              });
              if (!mounted) return;
              setState(() {
                _shopName = nameCtrl.text;
                _shopAddress = addrCtrl.text;
                _shopMapUrl = mapCtrl.text;
                _shopPhone = phoneCtrl.text;
                _shopBio = bioCtrl.text;
              });
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }, compact: true),
        ],
      ),
    );
  }

  void _replaceProduct(Map<String, dynamic> updated) {
    setState(() {
      final index = _products.indexWhere((p) => p['id'] == updated['id']);
      if (index == -1) {
        _products.insert(0, updated);
      } else {
        _products[index] = updated;
      }
    });
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameCtrl = TextEditingController(text: product['name']?.toString());
    final priceCtrl = TextEditingController(text: product['rate']?.toString());
    final stockCtrl = TextEditingController(text: product['stock']?.toString());
    final categoryCtrl = TextEditingController(
      text: product['category']?.toString() ?? '',
    );
    final barcodeCtrl = TextEditingController(
      text: product['barcode']?.toString() ?? '',
    );
    final descriptionCtrl = TextEditingController(
      text: product['description']?.toString() ?? '',
    );
    final imageCtrl = TextEditingController(
      text: product['imageUrl']?.toString() ?? '',
    );
    final thresholdCtrl = TextEditingController(
      text: product['threshold']?.toString() ?? '3',
    );
    var alertEnabled = product['alertEnabled'] != false;
    var isActive = product['isActive'] != false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            title: const Text(
              'Edit Shelf Item',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Rate',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Stock',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: categoryCtrl,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: thresholdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Alert At',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Barcode / SKU',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: imageCtrl,
                    decoration: InputDecoration(
                      labelText: 'Image Path / URL',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: alertEnabled,
                    onChanged: (value) =>
                        setModalState(() => alertEnabled = value),
                    title: const Text(
                      'Critical Restock Alert',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    activeColor: primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    value: isActive,
                    onChanged: (value) => setModalState(() => isActive = value),
                    title: const Text(
                      'Visible to Users',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    activeColor: primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w900),
                ),
              ),
              GradientButton('Save Item', Icons.check, () async {
                try {
                  final updated = await sellerBackendService.updateItem(
                    product['id'].toString(),
                    name: nameCtrl.text,
                    price: double.tryParse(priceCtrl.text) ?? 0,
                    stock: int.tryParse(stockCtrl.text) ?? 0,
                    category: categoryCtrl.text,
                    barcode: barcodeCtrl.text,
                    description: descriptionCtrl.text,
                    imageUrl: imageCtrl.text,
                    alertThreshold: int.tryParse(thresholdCtrl.text) ?? 3,
                    alertEnabled: alertEnabled,
                    isActive: isActive,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  _replaceProduct(updated);
                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }, compact: true),
            ],
          );
        },
      ),
    );
  }

  void _showSetThreshold(Map<String, dynamic> product) {
    final controller = TextEditingController(
      text: product['threshold'].toString(),
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text(
          'Set Alert Threshold',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'When stock reaches this number, the app will speak to you every hour until restocked.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Threshold Count',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: muted, fontWeight: FontWeight.w900),
            ),
          ),
          GradientButton('Save Threshold', Icons.check, () async {
            final nextThreshold = int.tryParse(controller.text) ?? 3;
            try {
              final updated = await sellerBackendService.updateItem(
                product['id'].toString(),
                alertThreshold: nextThreshold,
                alertEnabled: true,
              );
              if (!mounted || !dialogContext.mounted) return;
              _replaceProduct(updated);
              if (updated['isAlerting'] == true) {
                soundService.startHourlyAlert(
                  updated['id'].toString(),
                  updated['name'].toString(),
                );
              }
              Navigator.pop(dialogContext);
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }, compact: true),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text(
          'Remove from Shelf?',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
        ),
        content: Text('Are you sure you want to remove "${product['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: muted, fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await sellerBackendService.deleteItem(product['id'].toString());
                if (!mounted || !dialogContext.mounted) return;
                setState(
                  () => _products.removeWhere((p) => p['id'] == product['id']),
                );
                Navigator.pop(dialogContext);
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: const Text(
              'REMOVE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Seller Product Detail Page ---
class SellerProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;
  const SellerProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PageTitle(product['name'], 'Manager Deep-Dive Overview'),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Specific Profits
        const Kicker('PRODUCT PERFORMANCE'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Item Profit',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '₹${int.parse(product['rate']) * 12}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.trending_up, color: success, size: 40),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Stock Status
        const Kicker('INVENTORY STATUS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: shadowSm,
          ),
          child: Column(
            children: [
              _buildStatusRow(
                'Units Remaining',
                '${product['stock']}',
                isHighlighted: product['isAlerting'],
              ),
              const Divider(height: 32),
              _buildStatusRow(
                'Alert Threshold',
                '${product['threshold']}',
                color: muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Reviews
        const Kicker('USER FEEDBACK'),
        const SizedBox(height: 12),
        _buildReviewList(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    bool isHighlighted = false,
    Color color = ink,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, color: muted),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isHighlighted ? Colors.red : color,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.05)),
      ),
      child: const Column(
        children: [
          Icon(Icons.rate_review_outlined, color: muted, size: 34),
          SizedBox(height: 10),
          Text(
            'No backend reviews for this item yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
