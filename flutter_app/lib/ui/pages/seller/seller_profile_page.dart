import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import '../shared/login_page.dart';
import '../shared/register_page.dart';

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  bool _isOnline = true;
  bool _orderAlertsEnabled = true;
  bool _lowStockAlertsEnabled = true;
  bool _b2bAlertsEnabled = true;
  int _shelfItemCount = 0;
  int _lowStockItemCount = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _syncSellerSettings();
  }

  Future<void> _syncSellerSettings() async {
    try {
      final shop = await sellerBackendService.syncCurrentShopProfile();
      final items = await sellerBackendService.getItems();
      final prefs = await settingsPreferencesService.load();
      _isOnline = shop['is_open'] == false ? false : true;
      _shelfItemCount = items.length;
      _lowStockItemCount = items
          .where((item) => item['isAlerting'] == true)
          .length;
      _orderAlertsEnabled =
          prefs['sellerOrderAlerts'] as bool? ?? _orderAlertsEnabled;
      _lowStockAlertsEnabled =
          prefs['sellerLowStockAlerts'] as bool? ?? _lowStockAlertsEnabled;
      _b2bAlertsEnabled =
          prefs['sellerB2bAlerts'] as bool? ?? _b2bAlertsEnabled;
      if (mounted) setState(() {});
    } catch (_) {
      // Settings stays usable with the current local session while offline.
    }
  }

  Future<void> _pickStorefrontImage() async {
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
              toolbarTitle: 'Adjust Store Avatar',
              toolbarColor: primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Adjust Store Avatar'),
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
                                  'Adjust Store Avatar',
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
                                          if (mounted)
                                            Navigator.of(
                                              dialogContext,
                                            ).pop(resultPath);
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
          globalSellerShopProfile.value = {
            ...globalSellerShopProfile.value,
            'avatarUrl': imageData,
          };
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Store avatar updated successfully!')),
          );
        }
      }
    } catch (e) {
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

  void _showAutoReplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 20,
            ),
            child: ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: globalAutoReplyConfig,
              builder: (context, config, _) {
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Auto-Reply Configurations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Configure automated responses when offline or busy.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      const TabBar(
                        labelColor: primary,
                        unselectedLabelColor: muted,
                        indicatorColor: primary,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        tabs: [
                          Tab(text: 'Customer (User)'),
                          Tab(text: 'Merchant (Shopkeeper)'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          children: [
                            // Customer Auto Reply Tab
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Enable Customer Auto-Reply',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: config['userEnabled'] == true,
                                      onChanged: (v) {
                                        globalAutoReplyConfig.value = {
                                          ...config,
                                          'userEnabled': v,
                                        };
                                        setModalState(() {});
                                      },
                                      activeColor: primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (config['userEnabled'] == true) ...[
                                  const Text(
                                    'Select Preset Response',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value:
                                        autoReplyPresets.contains(
                                          config['userPreset'],
                                        )
                                        ? config['userPreset']
                                        : autoReplyPresets.first,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: autoReplyPresets
                                        .map(
                                          (preset) => DropdownMenuItem(
                                            value: preset,
                                            child: Text(
                                              preset,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        globalAutoReplyConfig.value = {
                                          ...config,
                                          'userPreset': val,
                                        };
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Or Write Custom Message',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Type your custom reply...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      globalAutoReplyConfig.value = {
                                        ...config,
                                        'userCustom': val,
                                      };
                                    },
                                    controller:
                                        TextEditingController(
                                            text: config['userCustom'],
                                          )
                                          ..selection = TextSelection.collapsed(
                                            offset: (config['userCustom'] ?? '')
                                                .length,
                                          ),
                                  ),
                                ],
                              ],
                            ),
                            // Merchant B2B Auto Reply Tab
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Enable B2B Auto-Reply',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value:
                                          config['shopkeeperEnabled'] == true,
                                      onChanged: (v) {
                                        globalAutoReplyConfig.value = {
                                          ...config,
                                          'shopkeeperEnabled': v,
                                        };
                                        setModalState(() {});
                                      },
                                      activeColor: primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (config['shopkeeperEnabled'] == true) ...[
                                  const Text(
                                    'Select Preset Response',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value:
                                        autoReplyPresets.contains(
                                          config['shopkeeperPreset'],
                                        )
                                        ? config['shopkeeperPreset']
                                        : autoReplyPresets.first,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: autoReplyPresets
                                        .map(
                                          (preset) => DropdownMenuItem(
                                            value: preset,
                                            child: Text(
                                              preset,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        globalAutoReplyConfig.value = {
                                          ...config,
                                          'shopkeeperPreset': val,
                                        };
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Or Write Custom Message',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Type your custom B2B reply...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      globalAutoReplyConfig.value = {
                                        ...config,
                                        'shopkeeperCustom': val,
                                      };
                                    },
                                    controller:
                                        TextEditingController(
                                            text: config['shopkeeperCustom'],
                                          )
                                          ..selection = TextSelection.collapsed(
                                            offset:
                                                (config['shopkeeperCustom'] ??
                                                        '')
                                                    .length,
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          settingsPreferencesService.savePatch({
                            'sellerAutoReply': globalAutoReplyConfig.value,
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Auto-reply configurations updated successfully!',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Save configurations',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Storefront Command',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorefrontIdentity(context),
            const SizedBox(height: 32),
            _buildActionGrid(context),
            const SizedBox(height: 32),
            const Kicker('SETTINGS & PREFERENCES'),
            const SizedBox(height: 16),
            _buildSettingsSection(context),
            const SizedBox(height: 48),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  authService.logout();
                  pushRoot(context, const EntryPage());
                },
                icon: const Icon(
                  Icons.power_settings_new,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Terminate Session',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStorefrontIdentity(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: globalSellerShopProfile,
      builder: (context, profile, _) {
        final avatar = profile['avatarUrl'] ?? '';
        final user = authService.currentUser.value;
        final shopName = profile['name'] ?? user?.name ?? 'My Shop';
        final block = profile['block']?.isNotEmpty == true
            ? profile['block']!
            : 'Local area';
        final category = profile['category']?.isNotEmpty == true
            ? profile['category']!
            : 'Local shop';
        final phone = user?.mobile.isNotEmpty == true
            ? user!.mobile
            : (profile['phone'] ?? '');
        final email = user?.email ?? '';

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(32),
            boxShadow: shadowSm,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickStorefrontImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary.withOpacity(0.1),
                            border: Border.all(
                              color: primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: ProductImageView(
                              imageUrl: avatar,
                              fallbackIcon: Icons.store,
                              fallbackIconSize: 40,
                              fallbackColor: primary,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: primary,
                            child: const Icon(
                              Icons.add_a_photo,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? success.withOpacity(0.1)
                          : muted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? success : muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _isOnline ? success : muted,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
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
                    child: Text(
                      shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.verified,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: primary, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$block • $category',
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (email.isNotEmpty || phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.alternate_email_rounded,
                      color: muted,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [email, phone].where((v) => v.isNotEmpty).join(' • '),
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildStat('Items', '$_shelfItemCount')),
                  Container(
                    width: 1,
                    height: 40,
                    color: muted.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildStat('Low Stock', '$_lowStockItemCount'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => push(
                        context,
                        MerchantProfilePage(
                          shopName: shopName,
                          role: Role.seller,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Preview Storefront',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final next = !_isOnline;
                        setState(() => _isOnline = next);
                        try {
                          await sellerBackendService.updateShop(isOpen: next);
                        } catch (error) {
                          if (!mounted) return;
                          setState(() => _isOnline = !next);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline
                            ? const Color(0xFF1E293B)
                            : primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _isOnline ? 'Go Offline' : 'Go Online',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String val) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            'Identity',
            Icons.badge_outlined,
            onTap: () => push(context, const AccountManagementPage()),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context,
            'Payouts',
            Icons.account_balance_wallet_outlined,
            onTap: () => push(context, const BankDetailsPage()),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context,
            'Auto-Reply',
            Icons.quickreply_outlined,
            onTap: () => _showAutoReplySheet(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: shadowSm,
        ),
        child: Column(
          children: [
            Icon(icon, color: primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Account Settings',
            subtitle: 'Update your profile name, email, and phone',
            onTap: () => push(context, const AccountManagementPage()),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.qr_code_2_rounded,
            title: 'Payment Methods',
            subtitle: 'Add payment QR, UPI ID, and linked mobile pay details',
            onTap: () => push(context, const AccountManagementPage()),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.translate_rounded,
            title: 'App Language',
            subtitle: 'Change app localization preferences',
            onTap: () => push(context, const LanguageSelectionPage()),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Configure order, stock, and B2B alerts',
            onTap: () => _showNotificationsDialog(context),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Switch seller tools to the midnight theme',
            onTap: () {},
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeController.themeMode,
              builder: (context, mode, _) {
                return Switch.adaptive(
                  value: mode == ThemeMode.dark,
                  activeColor: primary,
                  onChanged: (v) {
                    themeController.themeMode.value = v
                        ? ThemeMode.dark
                        : ThemeMode.light;
                    settingsPreferencesService.savePatch({'darkMode': v});
                  },
                );
              },
            ),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Add Account',
            subtitle: 'Add or switch saved buyer, seller, and admin accounts',
            onTap: () => _showSavedAccountsDialog(context),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.storage_rounded,
            title: 'Storage & Media',
            subtitle: 'Manage local audio, image, and document caches',
            onTap: () => push(context, const MediaStorageSettingsPage()),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.account_balance_outlined,
            title: 'Bank Accounts',
            subtitle: 'View linked bank details & balance check',
            onTap: () => push(context, const BankDetailsPage()),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.campaign_rounded,
            title: 'Promote Products',
            subtitle: 'Boost your products to the top of the user feed',
            onTap: () => push(context, const SellerPromotePage()),
          ),
          Divider(
            height: 1,
            color: muted.withOpacity(0.1),
            indent: 56,
            endIndent: 20,
          ),
          _buildSettingsTile(
            icon: Icons.report_problem_outlined,
            title: 'Report an Issue',
            subtitle: 'Submit platform issues or disputes to admin',
            onTap: () => push(context, const ReportIssuePage()),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Toggle alerts and pick your custom sound tone.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  title: const Text(
                    'Order & Booking Alerts',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'New customer purchases and payout updates',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Switch.adaptive(
                    value: _orderAlertsEnabled,
                    onChanged: (v) {
                      setModalState(() {
                        _orderAlertsEnabled = v;
                      });
                      setState(() {});
                      settingsPreferencesService.savePatch({
                        'sellerOrderAlerts': v,
                      });
                      if (v) {
                        soundService.playSelectedTone();
                      }
                    },
                    activeColor: primary,
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text(
                    'Low Stock Alerts',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Notifications when products run out of stock',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Switch.adaptive(
                    value: _lowStockAlertsEnabled,
                    onChanged: (v) {
                      setModalState(() {
                        _lowStockAlertsEnabled = v;
                      });
                      setState(() {});
                      settingsPreferencesService.savePatch({
                        'sellerLowStockAlerts': v,
                      });
                      if (v) {
                        soundService.playSelectedTone();
                      }
                    },
                    activeColor: primary,
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text(
                    'B2B Connection Alerts',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Collaboration requests from neighboring shops',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Switch.adaptive(
                    value: _b2bAlertsEnabled,
                    onChanged: (v) {
                      setModalState(() {
                        _b2bAlertsEnabled = v;
                      });
                      setState(() {});
                      settingsPreferencesService.savePatch({
                        'sellerB2bAlerts': v,
                      });
                      if (v) {
                        soundService.playSelectedTone();
                      }
                    },
                    activeColor: primary,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Notification Sound Tone',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select and preview the tone played for alerts.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: soundService.selectedTone,
                  builder: (context, currentTone, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: soundService.availableTones.map((tone) {
                        final isSelected = currentTone == tone;
                        return ChoiceChip(
                          label: Text(tone),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              soundService.selectedTone.value = tone;
                              soundService.playSelectedTone();
                              settingsPreferencesService.savePatch({
                                'notificationTone': tone,
                              });
                              setModalState(() {});
                            }
                          },
                          selectedColor: primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          backgroundColor: Colors.grey.shade100,
                          checkmarkColor: Colors.white,
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSavedAccountsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: FutureBuilder<List<SavedAccountSession>>(
          future: authService.savedAccounts(),
          builder: (context, snapshot) {
            final accounts = snapshot.data ?? const <SavedAccountSession>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accounts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch saved accounts with one tap, or add another login.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No saved accounts yet.',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isActive =
                            authService.currentUser.value?.id == account.userId;
                        final icon = account.role == Role.seller
                            ? Icons.storefront_outlined
                            : account.role == Role.admin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline_rounded;
                        return ListTile(
                          onTap: () async {
                            final ok = await authService.switchSavedAccount(
                              account.token,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            if (ok) {
                              pushRoot(context, RoleShell(role: account.role));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not switch account.'),
                                ),
                              );
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: primary.withOpacity(.10),
                            child: Icon(icon, color: primary),
                          ),
                          title: Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${account.role.name} • ${account.email}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive)
                                const Icon(Icons.check_circle, color: success),
                              IconButton(
                                tooltip: 'Forget account',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: muted,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  await authService.forgetSavedAccount(
                                    account.userId,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(ctx);
                                  _showSavedAccountsDialog(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          push(
                            context,
                            LoginPage(
                              initialRole:
                                  authService.currentRole.value ?? Role.seller,
                            ),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Add account'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          push(context, const RegisterPage());
                        },
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Create'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}
