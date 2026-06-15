import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.product});
  final Product product;

@override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool scanned = false;
  late List<Product> cart;

@override
  void initState() {
    super.initState();
    cart = [widget.product];
  }

double _calculateTotal() {
    return cart.fold(0, (total, p) {
      final priceString = p.price.replaceAll('₹', '').replaceAll(',', '');
      return total + (double.tryParse(priceString) ?? 0);
    });
  }

@override
  Widget build(BuildContext context) {
    final totalAmount = _calculateTotal();
    final formattedTotal = '₹${totalAmount.toStringAsFixed(2)}';
    
    // Find other items from same shop
    final shopItems = catalogProducts.where((p) => p.shop == widget.product.shop && !cart.any((c) => c.id == p.id)).toList();

return Scaffold(
      appBar: AppBar(title: const Text('Self-checkout'), backgroundColor: bg),
      body: AppPage(
        maxWidth: 720,
        children: [
          const PageTitle('Scan & Pay', 'Frontend mock flow for QR checkout and payment.'),
          const SizedBox(height: 18),
          
          if (!scanned) ...[
            Container(
              height: 310,
              decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(38), boxShadow: shadowLg),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white.withValues(alpha: .14), size: 188),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    width: 235,
                    height: 235,
                    decoration: BoxDecoration(
                      border: Border.all(color: primary, width: 4),
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                  const Positioned(
                    bottom: 28,
                    child: Text('Scan shop QR to verify counter', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton('Simulate QR Scan', Icons.qr_code_scanner, () => setState(() => scanned = true)),
          ] else ...[
            const SignalCard(title: 'Counter verified', body: 'Shop checkout point confirmed.', icon: Icons.verified),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Kicker('CART ITEMS'),
                  const SizedBox(height: 14),
                  for (final item in cart) ...[
                    CompactProductTile(product: item),
                    const SizedBox(height: 8),
                  ],
                  const Divider(height: 28),
                  SummaryLine('Item total', formattedTotal),
                  const SummaryLine('Platform fee', 'Included'),
                  const SummaryLine('Seller commission to DukaanZone', '3%'),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Expanded(child: Text('Payable now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    Text(formattedTotal, style: const TextStyle(fontSize: 24, color: success, fontWeight: FontWeight.w900)),
                  ]),
                ]),
              ),
            ),
            if (shopItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionHeader('Other items from this shop', ''),
              const SizedBox(height: 12),
              SizedBox(
                height: 290,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shopItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = shopItems[index];
                    return GestureDetector(
                      onTap: () => setState(() => cart.add(item)),
                      child: Stack(
                        children: [
                          PremiumProductCard(product: item, onTap: () => setState(() => cart.add(item))),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: primary,
                              child: const Icon(Icons.add, size: 22, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              'Proceed to Pay',
              Icons.lock_outline,
              () => push(context, PinEntryPage(amount: formattedTotal, orderId: widget.product.id)),
            ),
          ],
        ],
      ),
    );
  }
}

