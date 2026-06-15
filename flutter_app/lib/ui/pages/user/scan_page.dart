import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class UserScanPage extends StatefulWidget {
  const UserScanPage({super.key});

  @override
  State<UserScanPage> createState() => _UserScanPageState();
}

class _UserScanPageState extends State<UserScanPage> {
  final MobileScannerController controller = MobileScannerController();
  final TextEditingController _manualQrController = TextEditingController();
  bool _hasError = false;
  String _errorMessage = '';
  bool _resolving = false;
  bool _handledScan = false;

  @override
  void dispose() {
    controller.dispose();
    _manualQrController.dispose();
    super.dispose();
  }

  Future<void> _retryCamera() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    try {
      await controller.start();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser.value;
    return AppPage(
      maxWidth: 680,
      children: [
        PageTitle(
          'Self-checkout scan',
          'Scanner active for: ${user?.name ?? 'Guest'}',
        ),
        const SizedBox(height: 20),
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(40),
            boxShadow: shadowLg,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!_hasError)
                  MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      final rawValue = barcodes.isNotEmpty
                          ? barcodes.first.rawValue
                          : null;
                      if (rawValue != null &&
                          rawValue.isNotEmpty &&
                          !_handledScan) {
                        _resolvePaymentQr(rawValue);
                      }
                    },
                    errorBuilder: (context, error) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _hasError = true;
                          _errorMessage = error.errorCode.name.isNotEmpty
                              ? error.errorCode.name
                              : 'Camera access failed';
                        });
                      });
                      return _buildErrorState();
                    },
                  )
                else
                  _buildErrorState(),

                // Scanner Frame
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _hasError ? Colors.redAccent : primary,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),

                Positioned(
                  bottom: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _hasError ? 'Camera Blocked' : 'Ready to scan items',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Simulation / Manual Entry Section
        Row(
          children: [
            const Expanded(
              child: SectionHeader('Detected Shop', 'Paste test QR payload'),
            ),
            TextButton.icon(
              onPressed: _resolving
                  ? null
                  : () => _resolvePaymentQr(_manualQrController.text),
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text(
                'Resolve QR',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ],
        ),
        TextField(
          controller: _manualQrController,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'upi://pay?pa=shop@upi&pn=Shop&cu=INR',
            prefixIcon: const Icon(Icons.qr_code_2_outlined),
            suffixIcon: _resolving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Camera scan will pass the real QR value automatically. Manual paste is only a fallback when camera access is blocked during local browser testing.',
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final s in shops.take(3))
          RepaintBoundary(
            child: ListTile(
              onTap: () {
                _manualQrController.text =
                    'upi://pay?pa=${s.name.toLowerCase().replaceAll(' ', '')}@upi&pn=${Uri.encodeComponent(s.name)}&cu=INR';
              },
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF4F6F8),
                child: Icon(Icons.storefront, color: ink),
              ),
              title: Text(
                s.name,
                style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
              ),
              subtitle: const Text(
                'Fill sample QR payload',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.edit_outlined, color: muted),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.redAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera Access Denied',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Camera permission is blocked or unavailable. Allow camera access for DukaanZone and retry the live scanner.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (_errorMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _retryCamera,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry Camera'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolvePaymentQr(String qrPayload) async {
    final value = qrPayload.trim();
    if (value.isEmpty || _resolving) return;
    final user = authService.currentUser.value;
    debugPrint('SCAN LOG: User ${user?.id} scanned payment QR');
    setState(() {
      _resolving = true;
      _handledScan = true;
    });
    try {
      final session = await paymentSessionService.scanPaymentQr(value);
      if (!mounted) return;
      push(
        context,
        SmartScanCheckoutPage(
          shop: session.shop,
          color: primary,
          scannedProducts: session.products,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shop not found for this QR: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolving = false;
          _handledScan = false;
        });
      }
    }
  }
}
