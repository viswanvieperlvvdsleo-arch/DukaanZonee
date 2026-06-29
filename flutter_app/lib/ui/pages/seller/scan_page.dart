import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SellerScanPage extends StatefulWidget {
  const SellerScanPage({super.key});

  @override
  State<SellerScanPage> createState() => _SellerScanPageState();
}

class _SellerScanPageState extends State<SellerScanPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasError = false;
  String? _lastScan;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 680,
      children: [
        const PageTitle(
          'Supplier & Buyer Scan',
          'Scan backend QR codes to load customer accounts or settle invoices.',
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
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final value = barcodes.first.rawValue?.trim();
                      if (value == null ||
                          value.isEmpty ||
                          value == _lastScan) {
                        return;
                      }
                      setState(() => _lastScan = value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'QR detected. Buyer/invoice lookup will use backend records here.',
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _hasError = true);
                      });
                      return _buildErrorState();
                    },
                  )
                else
                  _buildErrorState(),
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
                      _hasError ? 'Camera Blocked' : 'Position QR within frame',
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
        const SizedBox(height: 24),
        const SectionHeader(
          'Live scan only',
          'No prototype buyer profiles are shown here.',
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: shadowSm,
          ),
          child: const Text(
            'Buyer QR and invoice lookup will use backend records. Use chat or payment history for real buyer conversations today.',
            style: TextStyle(color: muted, fontWeight: FontWeight.w700),
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
            'Camera Access Blocked',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ensure site permissions are granted to access the scanner.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _hasError = false),
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
}
