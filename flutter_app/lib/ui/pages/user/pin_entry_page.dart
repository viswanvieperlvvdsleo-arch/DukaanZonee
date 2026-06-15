import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({super.key, required this.amount, required this.orderId});
  final String amount;
  final String orderId;

@override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  String pin = '';
  bool processing = false;

void _onKeyPress(String key) {
    if (processing) return;
    setState(() {
      if (key == '<') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 4) {
        pin += key;
        if (pin.length == 4) _processPayment();
      }
    });
  }

Future<void> _processPayment() async {
    setState(() => processing = true);
    final isPaymentSuccess = await paymentService.processPayment(amount: 0, orderId: widget.orderId); // Mock
    if (!mounted) return;
    setState(() => processing = false);
    
    if (isPaymentSuccess) {
      // Deduct from user's balance
      double amt = 0.0;
      try {
        final cleanAmtStr = widget.amount.replaceAll('₹', '').replaceAll(',', '').trim();
        amt = double.parse(cleanAmtStr);
      } catch (_) {}
      
      final map = Map<String, double>.from(globalBankBalances.value);
      if (map.containsKey('HDFC Bank')) {
        map['HDFC Bank'] = (map['HDFC Bank'] ?? 0.0) - amt;
      }
      globalBankBalances.value = map;

      // Play Cash Register sound tone on payment success
      final oldTone = soundService.selectedTone.value;
      soundService.selectedTone.value = 'Cash Register';
      soundService.playSelectedTone().then((_) {
        soundService.selectedTone.value = oldTone;
      });

      showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          icon: const CircleAvatar(radius: 32, backgroundColor: const Color(0xFFDCFCE7), child: const Icon(Icons.check, color: success, size: 34)),
          title: const Text('Payment Successful'),
          content: Text('Paid ${widget.amount} securely. Shopkeeper has been notified.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return success to previous screen
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Enter UPI PIN', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Paying ${widget.amount}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < pin.length ? Colors.white : Colors.white24,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 48),
                if (processing)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      childAspectRatio: 1.5,
                      children: [
                        for (int i = 1; i <= 9; i++) KeypadButton(i.toString(), _onKeyPress),
                        const SizedBox(), // empty
                        KeypadButton('0', _onKeyPress),
                        KeypadButton('<', _onKeyPress),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

