import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

enum SellerAuthStep { login, register }

class SellerAuthPage extends StatefulWidget {
  const SellerAuthPage({super.key, this.isRegister = false});
  final bool isRegister;

  @override
  State<SellerAuthPage> createState() => _SellerAuthPageState();
}

class _SellerAuthPageState extends State<SellerAuthPage> {
  late SellerAuthStep _currentStep;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _paymentQrController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedMapUrl;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.isRegister
        ? SellerAuthStep.register
        : SellerAuthStep.login;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _upiIdController.dispose();
    _paymentQrController.dispose();
    super.dispose();
  }

  Future<void> _handleAction() async {
    if (!_validateForm()) return;
    setState(() => _loading = true);
    if (_currentStep == SellerAuthStep.login) {
      final success = await authService.login(
        _emailController.text,
        _passwordController.text,
        role: Role.seller,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (success) {
        pushRoot(context, const RoleShell(role: Role.seller));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _authErrorMessage(
                'Seller login failed. Check email, password, and backend server.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final success = await authService.register(
      name: _nameController.text,
      email: _emailController.text,
      mobile: _mobileController.text,
      password: _passwordController.text,
      isSeller: true,
      shopName: _nameController.text,
      category: _selectedCategory,
      block: _selectedBlock,
      address: _addressController.text,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
      mapUrl: _selectedMapUrl,
      paymentQrPayload: _paymentQrController.text,
      upiId: _upiIdController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      pushRoot(context, const RoleShell(role: Role.seller));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authErrorMessage(
              'Could not create seller account. Check email/payment-method uniqueness and backend server.',
            ),
          ),
        ),
      );
    }
  }

  bool _validateForm() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter a valid business email.');
      return false;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return false;
    }
    if (_currentStep == SellerAuthStep.register) {
      if (_nameController.text.trim().length < 2) {
        _showError('Enter a shop name.');
        return false;
      }
      if (_paymentQrController.text.trim().isEmpty &&
          _upiIdController.text.trim().isEmpty) {
        _showError('Add your payment QR or enter your UPI ID.');
        return false;
      }
    }
    return true;
  }

  String? _extractUpiId(String payload) {
    final value = payload.trim();
    if (value.isEmpty) return null;
    final directMatch = RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z0-9._-]{2,}$');
    if (directMatch.hasMatch(value)) return value;
    final match = RegExp(r'[?&]pa=([^&]+)').firstMatch(value);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1) ?? '').trim().isEmpty
        ? null
        : Uri.decodeComponent(match.group(1)!);
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

  Future<void> _openPaymentQrScanner() async {
    final result = await push<String>(
      context,
      PaymentQrScannerPage(initialValue: _paymentQrController.text),
    );
    if (result == null || !mounted) return;
    _applyPaymentValue(result);
  }

  LatLng? _extractCoordinates(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final direct = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(trimmed);
    final atMarker = RegExp(
      r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(trimmed);
    final queryMarker = RegExp(
      r'(?:[?&](?:q|query|ll)=)(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(trimmed);
    final match = direct ?? atMarker ?? queryMarker;
    if (match == null) return null;
    final lat = double.tryParse(match.group(1) ?? '');
    final lng = double.tryParse(match.group(2) ?? '');
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  void _applyLocationValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    final coordinates = _extractCoordinates(value);
    _selectedLatitude = coordinates?.latitude;
    _selectedLongitude = coordinates?.longitude;
    if (coordinates != null) {
      _selectedMapUrl =
          'https://www.google.com/maps/search/?api=1&query=${coordinates.latitude},${coordinates.longitude}';
      if (_addressController.text.trim().isEmpty ||
          _addressController.text.startsWith('Pinned map location')) {
        _addressController.text =
            'Pinned map location (${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)})';
      }
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      _selectedMapUrl = value;
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = 'Pinned Google Maps location';
      }
    } else {
      _addressController.text = value;
      _selectedMapUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}';
    }
    setState(() {});
  }

  Future<void> _showLocationChooser() async {
    final controller = TextEditingController(
      text: _selectedMapUrl ?? _addressController.text,
    );
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            18,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Choose shop location',
                style: TextStyle(
                  color: ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste a Google Maps link, a lat,lng pair, or a readable address. We store this with your shelf so users can route to you.',
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Map link, coordinates, or address',
                  hintText: '17.72920,83.31500 or Google Maps link',
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        '17.72920,83.31500',
                      ),
                      icon: const Icon(Icons.my_location_outlined),
                      label: const Text('Use test current'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, controller.text),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Save location'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
    controller.dispose();
    if (value == null || !mounted) return;
    _applyLocationValue(value);
  }

  String _authErrorMessage(String fallback) {
    final service = authService;
    if (service is BackendAuthService && service.lastError != null) {
      return service.lastError!;
    }
    return fallback;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case SellerAuthStep.login:
        return _buildLogin();
      case SellerAuthStep.register:
        return _buildRegister();
    }
  }

  Widget _buildLogin() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(size: 64),
        const SizedBox(height: 32),
        const Text(
          'Seller Login',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your digital shelf globally.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Business Email',
            prefixIcon: const Icon(Icons.business_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: _passwordDecoration(),
        ),
        const SizedBox(height: 32),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : GradientButton(
                'Login to Dashboard',
                Icons.dashboard_customize,
                _handleAction,
              ),
        const SizedBox(height: 24),
        SocialButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New shopkeeper?',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _currentStep = SellerAuthStep.register),
              child: const Text(
                'Register Shop',
                style: TextStyle(color: primary, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _selectedCategory = 'Grocery';
  String _selectedBlock = 'Block A';

  Widget _buildRegister() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(size: 64),
        const SizedBox(height: 32),
        const Text(
          'Partner with Us',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Launch your global digital storefront.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),

        // Brand Mark Picker
        Center(
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: primary.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload Brand Mark',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Shop Name',
            prefixIcon: const Icon(Icons.store_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category',
            prefixIcon: const Icon(Icons.category_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: [
            'Grocery',
            'Electronics',
            'Fashion',
            'Pharmacy',
          ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: _selectedBlock,
          decoration: InputDecoration(
            labelText: 'Primary Block',
            prefixIcon: const Icon(Icons.location_city_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: [
            'Block A',
            'Block B',
            'Cyber Plaza',
            'Green Valley',
          ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedBlock = v!),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Business Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _mobileController,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            prefixIcon: const Icon(Icons.phone_outlined),
            prefixText: '+91 ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: _passwordDecoration(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Shop Address',
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showLocationChooser,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(
            _selectedMapUrl == null ? 'Choose Location' : 'Location Linked',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(double.infinity, 50),
            side: BorderSide(color: primary.withOpacity(0.28)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_selectedMapUrl != null) ...[
          const SizedBox(height: 8),
          Text(
            _selectedLatitude == null
                ? 'Map link saved for route/open location.'
                : 'Pinned: ${_selectedLatitude!.toStringAsFixed(5)}, ${_selectedLongitude!.toStringAsFixed(5)}',
            style: const TextStyle(
              color: success,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _upiIdController,
          decoration: InputDecoration(
            labelText: 'UPI ID',
            hintText: 'yourshop@upi',
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _paymentQrController,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Payment QR Payload',
            hintText: 'Scan or paste your existing QR payload',
            prefixIcon: const Icon(Icons.qr_code_2_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openPaymentQrScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text(
                  'Add Payment QR',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: primary.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('Use test QR data'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_iphone_outlined, color: primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Registered mobile ${_mobileController.text.trim().isEmpty ? 'will' : '+91 ${_mobileController.text.trim()} will'} stay linked for chat payments too.',
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
        const SizedBox(height: 32),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : GradientButton(
                'Apply for Approval',
                Icons.handshake_outlined,
                _handleAction,
              ),
      ],
    );
  }

  InputDecoration _passwordDecoration() {
    return InputDecoration(
      labelText: 'Password',
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _showPassword ? 'Hide password' : 'Show password',
        icon: Icon(
          _showPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _showPassword = !_showPassword),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
