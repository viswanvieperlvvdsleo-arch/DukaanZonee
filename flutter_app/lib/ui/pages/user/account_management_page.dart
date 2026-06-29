import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:image_cropper/image_cropper.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _shopCategoryController;
  late final TextEditingController _shopBlockController;
  late final TextEditingController _shopAddressController;
  late final TextEditingController _upiIdController;
  late final TextEditingController _paymentQrController;
  bool _isLoading = false;
  String? _profileImageData;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = authService.currentUser.value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _mobileController = TextEditingController(text: user?.mobile ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _shopCategoryController = TextEditingController(
      text: globalSellerShopProfile.value['category'] ?? '',
    );
    _shopBlockController = TextEditingController(
      text: globalSellerShopProfile.value['block'] ?? '',
    );
    _shopAddressController = TextEditingController(
      text: globalSellerShopProfile.value['address'] ?? '',
    );
    _upiIdController = TextEditingController(
      text: globalSellerShopProfile.value['upiId'] ?? '',
    );
    _paymentQrController = TextEditingController(
      text: globalSellerShopProfile.value['paymentQrPayload'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _shopCategoryController.dispose();
    _shopBlockController.dispose();
    _shopAddressController.dispose();
    _upiIdController.dispose();
    _paymentQrController.dispose();
    super.dispose();
  }

  String? _extractUpiId(String payload) {
    final value = payload.trim();
    if (value.isEmpty) return null;
    final directMatch = RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z0-9._-]{2,}$');
    if (directMatch.hasMatch(value)) return value;
    final match = RegExp(r'[?&]pa=([^&]+)').firstMatch(value);
    if (match == null) return null;
    final decoded = Uri.decodeComponent(match.group(1) ?? '').trim();
    return decoded.isEmpty ? null : decoded;
  }

  void _applyPaymentValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    _paymentQrController.text = value;
    final upi = _extractUpiId(value);
    if (upi != null && _upiIdController.text.trim().isEmpty) {
      _upiIdController.text = upi;
    }
    setState(() {});
  }

  Future<void> _removePaymentQr() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove payment QR?'),
        content: const Text(
          'This seller account will stop resolving shelf checkout from the current payment QR until you add a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await sellerBackendService.updateShop(clearPaymentQr: true);
      _paymentQrController.clear();
      _upiIdController.clear();
      await sellerBackendService.syncCurrentShopProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment QR removed')));
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanPaymentQr() async {
    final result = await push<String>(
      context,
      PaymentQrScannerPage(initialValue: _paymentQrController.text),
    );
    if (result == null || !mounted) return;
    _applyPaymentValue(result);
  }

  Future<void> _showStoredQr() async {
    final payload = _paymentQrController.text.trim();
    if (payload.isEmpty || !mounted) return;
    final upi = _extractUpiId(payload);
    final encoded = Uri.encodeComponent(payload);
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=360x360&data=$encoded';
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saved Payment QR',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  qrUrl,
                  width: math.min(
                    MediaQuery.of(context).size.width * 0.65,
                    280,
                  ),
                  height: math.min(
                    MediaQuery.of(context).size.width * 0.65,
                    280,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Could not render QR preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (upi != null && upi.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'UPI ID: $upi',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  payload,
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? selected = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (selected != null && mounted) {
        // Use professional ImageCropper
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: selected.path,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Profile Picture',
              toolbarColor: primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Adjust Profile Picture'),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(width: 450, height: 450),
              customDialogBuilder: (cropper, crop, getResult, onRotate, onScale) {
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
                    width: MediaQuery.of(context).size.width > 700
                        ? 600
                        : MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Column(
                      children: [
                        const Text(
                          'Adjust Profile Picture',
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
                                onPressed: () => Navigator.of(context).pop(),
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
                                  crop(); // Execute the crop operation
                                  final String? resultPath =
                                      await getResult(); // Retrieve the resulting path
                                  if (mounted) {
                                    Navigator.of(context).pop(resultPath);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Apply Crop',
                                  style: TextStyle(fontWeight: FontWeight.w900),
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
            ),
          ],
        );

        if (croppedFile != null) {
          final imageData = await _croppedImageToDataUrl(croppedFile);
          if (!mounted) return;
          setState(() {
            _profileImageData = imageData;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    final updatedName = _nameController.text.trim();
    try {
      await authService.updateProfile(
        name: updatedName,
        mobile: _mobileController.text,
        profilePic: _profileImageData,
      );
      if (authService.currentRole.value == Role.seller) {
        await sellerBackendService.updateShop(
          name: updatedName,
          category: _shopCategoryController.text,
          block: _shopBlockController.text,
          address: _shopAddressController.text,
          paymentQrPayload: _paymentQrController.text,
          upiId: _upiIdController.text,
          avatarUrl: _profileImageData,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Simulate network request
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser.value;
    final isSeller = authService.currentRole.value == Role.seller;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text(
          'Account Management',
          style: TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(50),
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primary.withOpacity(0.2),
                          width: 4,
                        ),
                        color: Colors.grey[200],
                      ),
                      child: ClipOval(
                        child: ProductImageView(
                          imageUrl:
                              _profileImageData ??
                              user?.profilePic ??
                              'https://api.dicebear.com/7.x/avataaars/png?seed=${user?.name ?? 'User'}',
                          fallbackIcon: Icons.person,
                          fallbackIconSize: 50,
                          fallbackColor: Colors.grey,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            Kicker(isSeller ? 'SHOP & ACCOUNT DETAILS' : 'PERSONAL DETAILS'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isSeller ? 'Shop Name' : 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _mobileController,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                prefixText: '+91 ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: muted.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: muted.withOpacity(0.2)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              readOnly: true,
              style: const TextStyle(color: muted),
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined, color: muted),
                filled: true,
                fillColor: muted.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: muted.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: muted.withOpacity(0.2)),
                ),
              ),
            ),
            if (isSeller) ...[
              const SizedBox(height: 32),
              const Kicker('STORE DETAILS'),
              const SizedBox(height: 16),
              TextField(
                controller: _shopCategoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _shopBlockController,
                decoration: InputDecoration(
                  labelText: 'Primary Block',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _shopAddressController,
                decoration: InputDecoration(
                  labelText: 'Shop Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Kicker('PAYMENT METHODS'),
              const SizedBox(height: 16),
              TextField(
                controller: _upiIdController,
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'yourshop@upi',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stored payment QR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _paymentQrController.text.trim().isEmpty
                                    ? 'No QR linked yet'
                                    : _paymentQrController.text.trim(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _paymentQrController.text.trim().isEmpty
                                ? null
                                : _removePaymentQr,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text(
                              'Remove QR',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(
                                color: Colors.redAccent.withOpacity(0.25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _scanPaymentQr,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: Text(
                              _paymentQrController.text.trim().isEmpty
                                  ? 'Add QR'
                                  : 'Add Other One',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: primary.withOpacity(0.25),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _paymentQrController.text.trim().isEmpty
                            ? null
                            : _showStoredQr,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text(
                          'Show QR',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ink.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final upiId = _upiIdController.text.trim().isNotEmpty
                        ? _upiIdController.text.trim()
                        : '${_emailController.text.trim().isEmpty ? 'seller' : _emailController.text.trim().split('@').first}@upi';
                    _upiIdController.text = upiId;
                    _applyPaymentValue(
                      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(_nameController.text.trim().isEmpty ? 'My Shop' : _nameController.text.trim())}&cu=INR',
                    );
                  },
                  icon: const Icon(Icons.bolt_outlined, color: success),
                  label: const Text(
                    'Use test QR data',
                    style: TextStyle(
                      color: success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.phone_outlined, color: primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Linked mobile for chat pay requests: +91 ${_mobileController.text.trim().isEmpty ? 'not set' : _mobileController.text.trim()}',
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 48),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    'Save Changes',
                    Icons.save_outlined,
                    _saveChanges,
                  ),
          ],
        ),
      ),
    );
  }
}
