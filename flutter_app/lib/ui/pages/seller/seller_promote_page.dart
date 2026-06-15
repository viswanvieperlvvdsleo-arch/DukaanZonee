import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerPromotePage extends StatefulWidget {
  const SellerPromotePage({super.key});

  @override
  State<SellerPromotePage> createState() => _SellerPromotePageState();
}

class _SellerPromotePageState extends State<SellerPromotePage> {
  Map<String, dynamic>? _selectedItem;
  int _selectedTierIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _promotions = const [];
  PlatformSettings _platformSettings = platformSettingsService.settings.value;

  final List<int> _tiers = const [3, 7, 30];

  @override
  void initState() {
    super.initState();
    _loadPromotionStudio();
  }

  Future<void> _loadPromotionStudio() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final settings = await platformSettingsService.load();
      final items = await sellerBackendService.getItems();
      final promos = await sellerBackendService.getPromotions();
      if (!mounted) return;
      setState(() {
        _platformSettings = settings;
        _items = items;
        _promotions = promos;
        _selectedItem = items.isEmpty ? null : _selectedItem ?? items.first;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  double _getItemUnitPrice(Map<String, dynamic>? item) {
    if (item == null) return 0.0;
    return double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
  }

  double _calculatePrice(Map<String, dynamic>? item, int days) {
    final unitPrice = _getItemUnitPrice(item);
    if (days == 3)
      return unitPrice * (_platformSettings.promotion3DayRate / 100);
    if (days == 7)
      return unitPrice * (_platformSettings.promotion7DayRate / 100);
    if (days == 30)
      return unitPrice * (_platformSettings.promotion30DayRate / 100);
    return 0.0;
  }

  Future<void> _payAndSubmit() async {
    final item = _selectedItem;
    if (item == null || _isSubmitting) return;
    final days = _tiers[_selectedTierIndex];
    final price = _calculatePrice(item, days);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Confirm Ad Campaign',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promote ${item['name']} for $days days?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Internal ad fee:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _formatRupees((price * 100).round()),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: success,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to PIN'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final pinAccepted = await _requestAdPaymentPin(price);
    if (pinAccepted != true) return;

    setState(() => _isSubmitting = true);
    try {
      await sellerBackendService.createPromotion(
        shelfItemId: item['id'].toString(),
        durationDays: days,
        amountCents: (price * 100).round(),
      );
      await _loadPromotionStudio();
      if (!mounted) return;
      await soundService.playSelectedTone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment accepted. Campaign is live now.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit campaign. $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _requestAdPaymentPin(double price) {
    var pin = '';
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void addDigit(String digit) {
            if (pin.length >= 4) return;
            setModalState(() => pin += digit);
            if (pin.length == 4) {
              Future.delayed(const Duration(milliseconds: 180), () {
                if (ctx.mounted) Navigator.pop(ctx, true);
              });
            }
          }

          Widget keypadButton({
            String? digit,
            IconData? icon,
            VoidCallback? onPressed,
          }) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: SizedBox(
                  height: 54,
                  child: TextButton(
                    onPressed:
                        onPressed ??
                        (digit == null ? null : () => addDigit(digit)),
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: icon != null
                        ? Icon(icon, color: muted)
                        : Text(
                            digit ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                22,
                24,
                24 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      color: muted.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: primary,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pay ${_formatRupees((price * 100).round())}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your test payment PIN',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: index < pin.length
                              ? primary
                              : muted.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Column(
                    children: [
                      Row(
                        children: [
                          keypadButton(digit: '1'),
                          keypadButton(digit: '2'),
                          keypadButton(digit: '3'),
                        ],
                      ),
                      Row(
                        children: [
                          keypadButton(digit: '4'),
                          keypadButton(digit: '5'),
                          keypadButton(digit: '6'),
                        ],
                      ),
                      Row(
                        children: [
                          keypadButton(digit: '7'),
                          keypadButton(digit: '8'),
                          keypadButton(digit: '9'),
                        ],
                      ),
                      Row(
                        children: [
                          keypadButton(
                            icon: Icons.close_rounded,
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          keypadButton(digit: '0'),
                          keypadButton(
                            icon: Icons.backspace_outlined,
                            onPressed: pin.isEmpty
                                ? null
                                : () => setModalState(
                                    () =>
                                        pin = pin.substring(0, pin.length - 1),
                                  ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final activeDays = _tiers[_selectedTierIndex];
    final calculatedCost = _calculatePrice(_selectedItem, activeDays);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: shadowSm,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Promotion Studio',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadPromotionStudio,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  if (_error != null) _buildErrorCard(),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Select Promotion Tier',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildTierSelector(),
                  const SizedBox(height: 28),
                  const Text(
                    '2. Select Product',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildProductDropdown(),
                  const SizedBox(height: 20),
                  if (_selectedItem != null)
                    _buildBillingCard(calculatedCost, activeDays),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedItem == null || _isSubmitting
                          ? null
                          : _payAndSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: primary.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isSubmitting
                            ? 'Submitting...'
                            : 'Pay & Submit Request',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Select Product from Your Shelf',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    _buildEmptyCard('No shelf products available to promote.')
                  else
                    ..._items.map(_buildShelfProductCard),
                  const SizedBox(height: 36),
                  const Text(
                    'Ad Campaigns',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (_promotions.isEmpty)
                    _buildEmptyCard('No promotional campaigns submitted yet.')
                  else
                    ..._promotions.map(_buildPromotionHistoryCard),
                  const SizedBox(height: 40),
                  _buildRulesCard(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Text('Could not load backend promotions. $_error'),
    );
  }

  Widget _buildTierSelector() {
    return Row(
      children: List.generate(_tiers.length, (index) {
        final days = _tiers[index];
        final isSelected = index == _selectedTierIndex;
        final cost = _calculatePrice(_selectedItem, days);
        final rate = switch (days) {
          3 => _platformSettings.promotion3DayRate,
          7 => _platformSettings.promotion7DayRate,
          _ => _platformSettings.promotion30DayRate,
        };
        final rateText = switch (days) {
          3 => '${rate.toStringAsFixed(0)}% of 1 pack',
          7 => '${rate.toStringAsFixed(0)}% of 1 pack',
          _ => '${rate.toStringAsFixed(0)}% of 1 pack',
        };

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTierIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(
                right: index == _tiers.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? primary : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : shadowSm,
                border: Border.all(
                  color: isSelected ? primary : muted.withOpacity(0.15),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$days Days',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isSelected ? Colors.white : ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rateText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white70 : muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRupees((cost * 100).round()),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isSelected ? Colors.white : success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProductDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowSm,
        border: Border.all(color: muted.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedItem?['id']?.toString(),
          isExpanded: true,
          dropdownColor: Theme.of(context).cardTheme.color,
          icon: const Icon(Icons.keyboard_arrow_down, color: primary),
          hint: const Text('Select shelf product'),
          items: _items.map((item) {
            return DropdownMenuItem<String>(
              value: item['id'].toString(),
              child: Text(
                item['name'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          }).toList(),
          onChanged: (itemId) {
            setState(() {
              _selectedItem = _items.firstWhere(
                (item) => item['id'].toString() == itemId,
                orElse: () => _items.first,
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildBillingCard(double calculatedCost, int activeDays) {
    final item = _selectedItem!;
    final isCompact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Flex(
        direction: isCompact ? Axis.vertical : Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: isCompact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Original rate: ${_formatRupees((_getItemUnitPrice(item) * 100).round())}',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 16 : 0),
          Column(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupees((calculatedCost * 100).round()),
                style: const TextStyle(
                  color: success,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'To pay for $activeDays days',
                style: const TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShelfProductCard(Map<String, dynamic> item) {
    final isSelected =
        item['id']?.toString() == _selectedItem?['id']?.toString();
    final imageUrl = item['imageUrl']?.toString();
    final price = _formatRupees((_getItemUnitPrice(item) * 100).round());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primary : muted.withOpacity(0.15),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildItemImage(imageUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rate: $price',
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          isSelected
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                )
              : IconButton.filledTonal(
                  onPressed: () => setState(() => _selectedItem = item),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  tooltip: 'Boost product',
                ),
        ],
      ),
    );
  }

  Widget _buildPromotionHistoryCard(Map<String, dynamic> promo) {
    final item = Map<String, dynamic>.from(promo['item'] as Map? ?? {});
    final status = promo['status']?.toString() ?? 'pending';
    final statusColor = switch (status) {
      'approved' => success,
      'rejected' => Colors.redAccent,
      'expired' => muted,
      _ => Colors.orange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowSm,
        border: Border.all(color: muted.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _buildItemImage(item['imageUrl']?.toString()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? 'Product',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${promo['durationDays'] ?? 0} days - ${_formatRupees(promo['amountCents'] as int? ?? 0)} paid',
                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: primary.withOpacity(0.08),
        child: ProductImageView(
          imageUrl: imageUrl,
          fallbackIcon: Icons.inventory_2_outlined,
          fallbackIconSize: 26,
          fallbackColor: primary,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: muted.withOpacity(0.15)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars, color: primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Ad Campaign Rules',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionRow(
            '3 Days Boost',
            'Internal fee is ${_platformSettings.promotion3DayRate.toStringAsFixed(0)}% of product rate.',
          ),
          _buildInstructionRow(
            '7 Days Boost',
            'Internal fee is ${_platformSettings.promotion7DayRate.toStringAsFixed(0)}% of product rate.',
          ),
          _buildInstructionRow(
            '30 Days Boost',
            'Internal fee is ${_platformSettings.promotion30DayRate.toStringAsFixed(0)}% of product rate.',
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 8),
          const Text(
            '* Test PIN payments go live immediately. Admin can still disapprove or mark payment return.',
            style: TextStyle(
              fontSize: 11,
              color: muted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: success, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: ink,
                  fontFamily: 'Inter',
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(
                      color: muted,
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

  String _formatRupees(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }
}
