import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukaan_zone_flutter/core/constants.dart';
import 'package:dukaan_zone_flutter/core/theme.dart';
import 'package:dukaan_zone_flutter/models/models.dart';
import 'package:dukaan_zone_flutter/services/services.dart';
import 'package:dukaan_zone_flutter/ui/pages/user/manual_payment_page.dart';

// ─────────────────────────────────────────────────────────────
//  SMART SCAN CHECKOUT PAGE
//  Shown after QR scan. User sees itemized shop products,
//  adds/removes quantities, total auto-updates in the amount
//  field, then taps Pay to proceed to ShopPaymentChatPage.
// ─────────────────────────────────────────────────────────────
class SmartScanCheckoutPage extends StatefulWidget {
  const SmartScanCheckoutPage({
    super.key,
    required this.shop,
    required this.color,
    this.prefilledCart, // from Group Saved: pre-populates the cart
    this.scannedProducts,
    this.gatewayProviders = const [],
    this.preferredGatewayProvider,
  });

  final Shop shop;
  final Color color;
  final Map<String, int>? prefilledCart;
  final List<Product>? scannedProducts;
  final List<PaymentGatewayOption> gatewayProviders;
  final String? preferredGatewayProvider;

  @override
  State<SmartScanCheckoutPage> createState() => _SmartScanCheckoutPageState();
}

class _SmartScanCheckoutPageState extends State<SmartScanCheckoutPage>
    with TickerProviderStateMixin {
  // Cart: productId → quantity
  final Map<String, int> _cart = {};
  late final TextEditingController _amountCtrl;
  late final TextEditingController _searchCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _manualEdit = false; // true if user typed amount manually
  String _searchQuery = '';
  bool _isPaying = false;
  late String _selectedGatewayProvider;
  PlatformSettings _platformSettings = platformSettingsService.settings.value;

  List<PaymentGatewayOption> get _gatewayProviders =>
      widget.gatewayProviders.isNotEmpty
      ? widget.gatewayProviders
      : const [
          PaymentGatewayOption(
            id: 'mock_gateway',
            label: 'Mock Gateway',
            mode: 'sandbox',
            feeRate: 0.0236,
            isLiveReady: false,
          ),
          PaymentGatewayOption(
            id: 'razorpay',
            label: 'Razorpay',
            mode: 'sandbox_adapter',
            feeRate: 0.0236,
            isLiveReady: false,
          ),
          PaymentGatewayOption(
            id: 'phonepe',
            label: 'PhonePe',
            mode: 'sandbox_adapter',
            feeRate: 0.02,
            isLiveReady: false,
          ),
        ];

  PaymentGatewayOption get _selectedGateway => _gatewayProviders.firstWhere(
    (provider) => provider.id == _selectedGatewayProvider,
    orElse: () => _gatewayProviders.first,
  );

  List<Product> get _shopProducts =>
      widget.scannedProducts ??
      catalogProducts.where((p) => p.shop == widget.shop.name).toList();

  List<Product> get _filteredProducts {
    final all = _shopProducts;
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  double get _cartTotal {
    double total = 0;
    for (final p in _shopProducts) {
      final qty = _cart[p.id] ?? 0;
      if (qty > 0) {
        final raw = p.price.replaceAll(RegExp(r'[^0-9.]'), '');
        total += (double.tryParse(raw) ?? 0) * qty;
      }
    }
    return total;
  }

  int get _totalItems => _cart.values.fold(0, (sum, q) => sum + q);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _searchCtrl = TextEditingController();
    platformSettingsService.settings.addListener(_syncPlatformSettings);
    unawaited(_loadPlatformSettings());
    final preferred =
        widget.preferredGatewayProvider ?? widget.shop.gatewayProvider;
    _selectedGatewayProvider = _gatewayProviders.any((p) => p.id == preferred)
        ? preferred!
        : _gatewayProviders.first.id;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    // Pre-fill cart from group saved
    if (widget.prefilledCart != null) {
      for (final entry in widget.prefilledCart!.entries) {
        Product? product;
        for (final candidate in _shopProducts) {
          if (candidate.id == entry.key) {
            product = candidate;
            break;
          }
        }
        final available = product == null ? 0 : _stockQty(product);
        final safeQty = entry.value.clamp(0, available).toInt();
        if (safeQty > 0) {
          _cart[entry.key] = safeQty;
        }
      }
      final total = _cartTotal;
      if (total > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _amountCtrl.text = total.toStringAsFixed(2);
        });
      }
    }
  }

  @override
  void dispose() {
    platformSettingsService.settings.removeListener(_syncPlatformSettings);
    _amountCtrl.dispose();
    _searchCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _syncPlatformSettings() {
    if (!mounted) return;
    setState(() => _platformSettings = platformSettingsService.settings.value);
  }

  int _stockQty(Product p) {
    final stockText = p.stock.toLowerCase();
    if (stockText.contains('out')) return 0;
    final match = RegExp(r'\d+').firstMatch(stockText);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  String _stockLabel(Product p) {
    final stock = _stockQty(p);
    if (stock <= 0) return 'Out of stock';
    return stock == 1 ? '1 left' : '$stock left';
  }

  void _showStockMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadPlatformSettings() async {
    try {
      final settings = await platformSettingsService.load();
      if (!mounted) return;
      setState(() => _platformSettings = settings);
    } catch (_) {
      // Checkout can still proceed with the local default if settings are offline.
    }
  }

  void _updateQuantity(Product p, int delta) {
    final available = _stockQty(p);
    final current = _cart[p.id] ?? 0;
    if (delta > 0 && available <= 0) {
      _showStockMessage('${p.name} is out of stock');
      return;
    }
    if (delta > 0 && current >= available) {
      _showStockMessage('Only ${_stockLabel(p)} for ${p.name}');
      return;
    }

    setState(() {
      final next = (current + delta).clamp(0, available).toInt();
      if (next == 0) {
        _cart.remove(p.id);
      } else {
        _cart[p.id] = next;
      }
      // Sync amount field unless user is manually editing
      if (!_manualEdit) {
        if (_cartTotal > 0) {
          _amountCtrl.text = _cartTotal.toStringAsFixed(2);
        } else {
          _amountCtrl.clear();
        }
      }
    });

    // Pulse the total
    _pulseCtrl.forward(from: 0).then((_) => _pulseCtrl.reverse());
    HapticFeedback.selectionClick();
  }

  void _onAmountChanged(String val) {
    // Once user edits, stop syncing from cart
    _manualEdit = val.isNotEmpty;
  }

  void _onAmountFocusLost() {
    // If user clears amount, resume cart sync
    if (_amountCtrl.text.isEmpty) {
      setState(() {
        _manualEdit = false;
        if (_cartTotal > 0) {
          _amountCtrl.text = _cartTotal.toStringAsFixed(2);
        }
      });
    }
  }

  double get _payableAmount {
    if (_amountCtrl.text.isNotEmpty) {
      return double.tryParse(_amountCtrl.text) ?? _cartTotal;
    }
    return _cartTotal;
  }

  bool get _hasLinkedPaymentQr =>
      widget.shop.paymentQrPayload?.trim().isNotEmpty == true;

  String? get _linkedPaymentTarget {
    final upi = widget.shop.upiId?.trim();
    if (upi != null && upi.isNotEmpty) return upi;

    final qrUpi = _extractUpiId(widget.shop.paymentQrPayload);
    if (qrUpi != null && qrUpi.isNotEmpty) return qrUpi;

    final phone = widget.shop.phone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;

    return _hasLinkedPaymentQr ? 'Saved payment QR' : null;
  }

  String? _extractUpiId(String? payload) {
    final value = payload?.trim();
    if (value == null || value.isEmpty) return null;

    try {
      final uri = Uri.parse(value);
      final pa = uri.queryParameters['pa']?.trim();
      if (pa != null && pa.isNotEmpty) return pa;
    } catch (_) {
      // Fall through to the lightweight regex parser for non-URI QR payloads.
    }

    final match = RegExp(r'[?&]pa=([^&]+)').firstMatch(value);
    if (match != null) {
      final raw = match.group(1);
      if (raw != null && raw.isNotEmpty) return Uri.decodeComponent(raw);
    }

    if (RegExp(r'^[\w.\-]+@[\w.\-]+$').hasMatch(value)) return value;
    return null;
  }

  Future<void> _proceedToPayment() async {
    final amount = _payableAmount;
    if (amount <= 0 && _totalItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add items or enter an amount to continue'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Build summary of selected items
    final selectedItems = <Map<String, dynamic>>[];
    for (final p in _shopProducts) {
      final qty = _cart[p.id] ?? 0;
      if (qty > 0) {
        final available = _stockQty(p);
        if (available <= 0) {
          _showStockMessage('${p.name} is out of stock');
          return;
        }
        if (qty > available) {
          _showStockMessage('${p.name} has only $available left');
          return;
        }
        selectedItems.add({'product': p, 'qty': qty});
      }
    }

    final providerId = await _showGatewaySheet(
      amount: amount,
      selectedItems: selectedItems,
    );
    if (providerId == null) return;
    final provider = _gatewayProviders.firstWhere(
      (option) => option.id == providerId,
      orElse: () => _selectedGateway,
    );

    final pinApproved = await _showSandboxPinSheet(amount, provider);
    if (pinApproved != true) return;

    setState(() => _isPaying = true);
    try {
      final payment = await paymentSessionService.completeCheckout(
        shop: widget.shop,
        amount: amount,
        selectedItems: selectedItems,
        provider: provider.id,
      );
      if (!mounted) return;
      globalPaymentHistory.value = [
        {
          'merchant': payment.shopName,
          'date': 'Today, ${_timeNow()}',
          'amount': payment.amountLabel,
          'items': payment.itemsLabel,
          'icon': Icons.storefront_outlined,
        },
        ...globalPaymentHistory.value,
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${payment.amountLabel} recorded for ${payment.shopName}',
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      push(
        context,
        ShopPaymentChatPage(
          shop: widget.shop,
          color: widget.color,
          prefilledItems: selectedItems,
          completedPayment: payment,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  String _timeNow() {
    final n = DateTime.now();
    final hour = n.hour == 0 ? 12 : (n.hour > 12 ? n.hour - 12 : n.hour);
    return '$hour:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<String?> _showGatewaySheet({
    required double amount,
    required List<Map<String, dynamic>> selectedItems,
  }) {
    final grossCents = (amount * 100).round();
    final commissionRate = _platformSettings.commissionRate;
    final commissionCents = (grossCents * commissionRate).round();
    final commissionLabel =
        'DukaanZone ${_formatPercent(commissionRate * 100)}';
    final itemCount = selectedItems.fold<int>(
      0,
      (total, item) => total + (item['qty'] as int? ?? 0),
    );

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selected = _gatewayProviders.firstWhere(
            (provider) => provider.id == _selectedGatewayProvider,
            orElse: () => _gatewayProviders.first,
          );
          final gatewayFeeCents = (grossCents * selected.feeRate).round();
          final sellerNetCents =
              (grossCents - gatewayFeeCents - commissionCents).clamp(
                0,
                grossCents,
              );

          return SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: shadowLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.payment_rounded, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${selected.label} Checkout',
                          style: TextStyle(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _gatewayProviders.map((provider) {
                      final active = provider.id == selected.id;
                      return ChoiceChip(
                        selected: active,
                        label: Text(provider.label),
                        avatar: Icon(
                          provider.id == 'phonepe'
                              ? Icons.account_balance_wallet_rounded
                              : provider.id == 'razorpay'
                              ? Icons.bolt_rounded
                              : Icons.science_rounded,
                          size: 17,
                          color: active ? Colors.white : primary,
                        ),
                        selectedColor: primary,
                        labelStyle: TextStyle(
                          color: active ? Colors.white : ink,
                          fontWeight: FontWeight.w900,
                        ),
                        onSelected: (_) {
                          setState(
                            () => _selectedGatewayProvider = provider.id,
                          );
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected.isLiveReady
                          ? const Color(0xFFE8FFF4)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      selected.isLiveReady
                          ? 'Real keys configured. This adapter is ready for live capture.'
                          : '${selected.statusLabel}: this test records payment safely without moving real money.',
                      style: TextStyle(
                        color: selected.isLiveReady
                            ? const Color(0xFF047857)
                            : const Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _mockGatewayRow('Cart amount', _formatMockMoney(grossCents)),
                  _mockGatewayRow(
                    '${selected.label} fee estimate',
                    _formatMockMoney(gatewayFeeCents),
                  ),
                  _mockGatewayRow(
                    commissionLabel,
                    _formatMockMoney(commissionCents),
                  ),
                  const Divider(height: 24),
                  _mockGatewayRow(
                    'Seller net after fees',
                    _formatMockMoney(sellerNetCents),
                    strong: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    itemCount > 0
                        ? '$itemCount item(s) will be marked paid after success.'
                        : 'Manual amount payment will be marked paid after success.',
                    style: const TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, selected.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Continue to PIN'),
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
    );
  }

  Future<bool?> _showSandboxPinSheet(
    double amount,
    PaymentGatewayOption provider,
  ) {
    var pin = '';
    var processing = false;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> submitSuccess() async {
            setSheetState(() => processing = true);
            await Future.delayed(const Duration(milliseconds: 650));
            final oldTone = soundService.selectedTone.value;
            soundService.selectedTone.value = 'Cash Register';
            await soundService.playSelectedTone();
            soundService.selectedTone.value = oldTone;
            if (!ctx.mounted) return;
            Navigator.pop(ctx, true);
          }

          void onKey(String key) {
            if (processing) return;
            if (key == '<') {
              setSheetState(() {
                if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
              });
              return;
            }
            if (pin.length >= 4) return;
            setSheetState(() => pin += key);
            HapticFeedback.selectionClick();
            if (pin.length == 4) {
              submitSuccess();
            }
          }

          return SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: shadowLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter sandbox PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${provider.label} test pay ${_formatMockMoney((amount * 100).round())} to ${widget.shop.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        width: index < pin.length ? 18 : 14,
                        height: index < pin.length ? 18 : 14,
                        decoration: BoxDecoration(
                          color: index < pin.length ? primary : Colors.white24,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (processing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: [
                        for (var i = 1; i <= 9; i++)
                          _SandboxPinKey(label: '$i', onTap: onKey),
                        const SizedBox(),
                        _SandboxPinKey(label: '0', onTap: onKey),
                        _SandboxPinKey(
                          label: '<',
                          onTap: onKey,
                          icon: Icons.backspace_outlined,
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: processing
                        ? null
                        : () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Cancel payment',
                      style: TextStyle(color: Colors.white70),
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

  Widget _mockGatewayRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? ink : muted,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? success : ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMockMoney(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }

  String _formatPercent(double percent) {
    final fixed = percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1);
    return '$fixed%';
  }

  // ── Save Group Dialog ─────────────────────────────────────
  void _showSaveGroupDialog() {
    final nameCtrl = TextEditingController(
      text: '${widget.shop.name.split(' ').first} Order',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, color: widget.color),
            const SizedBox(width: 8),
            const Text(
              'Save as Group',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_totalItems item${_totalItems == 1 ? '' : 's'} from ${widget.shop.name}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                ),
                hintText: 'e.g. Morning Groceries',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: widget.color, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final cartSnapshot = Map<String, int>.from(
                Map.fromEntries(_cart.entries.where((e) => e.value > 0)),
              );
              try {
                final group = await savedGroupService.createGroup(
                  name: name,
                  shopName: widget.shop.name,
                  shopId: widget.shop.id,
                  items: cartSnapshot,
                );
                globalSavedGroups.value = [group, ...globalSavedGroups.value];
                if (!mounted || !ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 10),
                        Text('"$name" saved to your groups!'),
                      ],
                    ),
                    backgroundColor: widget.color,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Could not save group to backend.'),
                    backgroundColor: Colors.red.shade400,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Save Group',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final color = widget.color;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            _buildHeader(color),

            // ── Amount Field ─────────────────────────────────────
            _buildAmountField(color),

            // ── Search Bar ───────────────────────────────────────
            _buildSearchBar(color),

            // ── Product List ─────────────────────────────────────
            Expanded(
              child: products.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: products.length,
                      itemBuilder: (ctx, i) =>
                          _buildProductRow(products[i], color),
                    ),
            ),
          ],
        ),
      ),

      // ── Pay Button ───────────────────────────────────────────
      bottomNavigationBar: _buildPayBar(color),
    );
  }

  // ────────────────────────────────────────────────────────────
  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${widget.shop.type} • ${widget.shop.block}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Save as Group button (visible when cart has items)
          if (_totalItems > 0)
            GestureDetector(
              onTap: _showSaveGroupDialog,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: .3)),
                ),
                child: Icon(Icons.favorite_rounded, color: color, size: 20),
              ),
            ),
          // Shop avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: .15),
            child: Text(
              widget.shop.name[0],
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  Widget _buildSearchBar(Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? color.withValues(alpha: .4)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          icon: Icon(
            Icons.search_rounded,
            color: _searchQuery.isNotEmpty ? color : const Color(0xFF94A3B8),
            size: 20,
          ),
          hintText: 'Search products in this shop...',
          hintStyle: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 18,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  Widget _buildAmountField(Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .12), color.withValues(alpha: .04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'TOTAL AMOUNT',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (_totalItems > 0)
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_totalItems item${_totalItems == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) _onAmountFocusLost();
            },
            child: TextField(
              controller: _amountCtrl,
              onChanged: _onAmountChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -1,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: .7),
                ),
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: .3),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          _buildLinkedPaymentHint(color),
          if (_manualEdit && _cartTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _manualEdit = false;
                    _amountCtrl.text = _cartTotal.toStringAsFixed(2);
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      color: color.withValues(alpha: .6),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to sync from items (₹${_cartTotal.toStringAsFixed(2)})',
                      style: TextStyle(
                        color: color.withValues(alpha: .7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  Widget _buildLinkedPaymentHint(Color color) {
    final target = _linkedPaymentTarget;
    if (target == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(
            _hasLinkedPaymentQr
                ? Icons.qr_code_2_rounded
                : Icons.account_balance_wallet_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'Paying to',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product p, Color color) {
    final qty = _cart[p.id] ?? 0;
    final stockQty = _stockQty(p);
    final outOfStock = stockQty <= 0;
    final rawPrice = p.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final unitPrice = double.tryParse(rawPrice) ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qty > 0 ? color.withValues(alpha: .06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: outOfStock
              ? Colors.red.withValues(alpha: .18)
              : qty > 0
              ? color.withValues(alpha: .25)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Product icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                outOfStock ? Icons.block_rounded : p.icon,
                color: outOfStock ? Colors.redAccent : color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        p.price,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      if (qty > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '= ₹${(unitPrice * qty).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _stockLabel(p),
                    style: TextStyle(
                      color: outOfStock
                          ? Colors.redAccent
                          : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // +/- Controls
            _buildQtyControl(p, qty, color, stockQty),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyControl(Product p, int qty, Color color, int stockQty) {
    final canAdd = stockQty > 0 && qty < stockQty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Minus / Delete (only when qty > 0) ───────────────
        if (qty > 0) ...[
          _CircleControlBtn(
            icon: qty == 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            color: qty == 1 ? Colors.red : color,
            onTap: () => _updateQuantity(p, -1),
          ),
          // Quantity counter
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(qty),
              width: 32,
              alignment: Alignment.center,
              child: Text(
                '$qty',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: color,
                ),
              ),
            ),
          ),
        ],

        // ─── Plus always visible ───────────────────────────────
        GestureDetector(
          onTap: canAdd ? () => _updateQuantity(p, 1) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: !canAdd
                  ? Colors.grey.shade100
                  : qty > 0
                  ? color.withValues(alpha: .18)
                  : color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !canAdd
                    ? Colors.grey.shade300
                    : color.withValues(alpha: qty > 0 ? .4 : .25),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              color: canAdd ? color : Colors.grey.shade400,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found\nfor ${widget.shop.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter amount manually above to pay',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayBar(Color color) {
    final amount = _payableAmount;
    final hasValue = !_isPaying && (amount > 0 || _totalItems > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cart summary chip
            if (_totalItems > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_totalItems item${_totalItems == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₹${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

            // Pay button
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 58,
                decoration: BoxDecoration(
                  gradient: hasValue
                      ? LinearGradient(
                          colors: [color, color.withValues(alpha: .75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: hasValue ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: hasValue
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: .35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: hasValue ? _proceedToPayment : null,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPaying)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            Icon(
                              Icons.lock_rounded,
                              color: hasValue
                                  ? Colors.white.withValues(alpha: .85)
                                  : Colors.grey.shade400,
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isPaying
                                ? 'Recording payment...'
                                : amount > 0
                                ? 'Pay  ₹${amount.toStringAsFixed(2)}'
                                : 'Add items to pay',
                            style: TextStyle(
                              color: hasValue
                                  ? Colors.white
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _SandboxPinKey extends StatelessWidget {
  const _SandboxPinKey({required this.label, required this.onTap, this.icon});

  final String label;
  final ValueChanged<String> onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => onTap(label),
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: icon == null
              ? Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CircleControlBtn extends StatelessWidget {
  const _CircleControlBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
