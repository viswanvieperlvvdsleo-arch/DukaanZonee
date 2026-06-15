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
  });

  final Shop shop;
  final Color color;
  final Map<String, int>? prefilledCart;
  final List<Product>? scannedProducts;

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
        final raw = p.price.replaceAll(RegExp(r'[₹,]'), '');
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
      _cart.addAll(widget.prefilledCart!);
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
    _amountCtrl.dispose();
    _searchCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _updateQuantity(Product p, int delta) {
    setState(() {
      final current = _cart[p.id] ?? 0;
      final next = (current + delta).clamp(0, 99);
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
        selectedItems.add({'product': p, 'qty': qty});
      }
    }

    final approved = await _showMockGatewaySheet(
      amount: amount,
      selectedItems: selectedItems,
    );
    if (approved != true) return;

    setState(() => _isPaying = true);
    try {
      final payment = await paymentSessionService.completeCheckout(
        shop: widget.shop,
        amount: amount,
        selectedItems: selectedItems,
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

  Future<bool?> _showMockGatewaySheet({
    required double amount,
    required List<Map<String, dynamic>> selectedItems,
  }) {
    final grossCents = (amount * 100).round();
    final gatewayFeeCents = (grossCents * 0.0236).round();
    final commissionCents = (grossCents * 0.03).round();
    final sellerNetCents = (grossCents - gatewayFeeCents - commissionCents)
        .clamp(0, grossCents);
    final itemCount = selectedItems.fold<int>(
      0,
      (total, item) => total + (item['qty'] as int? ?? 0),
    );

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
                      color: primary.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.payment_rounded, color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mock Gateway Checkout',
                      style: TextStyle(
                        color: ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _mockGatewayRow('Cart amount', _formatMockMoney(grossCents)),
              _mockGatewayRow(
                'Gateway estimate',
                _formatMockMoney(gatewayFeeCents),
              ),
              _mockGatewayRow(
                'DukaanZone 3%',
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
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Fail Test'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Pay Success'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
  Widget _buildProductRow(Product p, Color color) {
    final qty = _cart[p.id] ?? 0;
    final rawPrice = p.price.replaceAll(RegExp(r'[₹,]'), '');
    final unitPrice = double.tryParse(rawPrice) ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qty > 0 ? color.withValues(alpha: .06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: qty > 0 ? color.withValues(alpha: .25) : Colors.transparent,
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
              child: Icon(p.icon, color: color, size: 22),
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
                    p.stock,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // +/- Controls
            _buildQtyControl(p, qty, color),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyControl(Product p, int qty, Color color) {
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
          onTap: () => _updateQuantity(p, 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qty > 0
                  ? color.withValues(alpha: .18)
                  : color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: qty > 0 ? .4 : .25),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.add_rounded, color: color, size: 22),
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
