import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/core/theme.dart';
import 'package:image_picker/image_picker.dart';

class PaymentQrScannerPage extends StatefulWidget {
  const PaymentQrScannerPage({super.key, this.initialValue});

  final String? initialValue;

  @override
  State<PaymentQrScannerPage> createState() => _PaymentQrScannerPageState();
}

class _PaymentQrScannerPageState extends State<PaymentQrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _manualController;
  bool _completed = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _startingCamera = false;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.initialValue ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  @override
  void dispose() {
    _scannerController.stop();
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _complete(String payload) {
    final value = payload.trim();
    if (_completed || value.isEmpty) return;
    _completed = true;
    Navigator.of(context).pop(value);
  }

  bool get _isInsecureRemoteWeb {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    final isLocalHost = host == 'localhost' || host == '127.0.0.1';
    return Uri.base.scheme != 'https' && !isLocalHost;
  }

  Future<void> _retryCamera() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    await _startCamera();
  }

  Future<void> _startCamera() async {
    if (_startingCamera || _completed) return;
    _startingCamera = true;
    try {
      await _scannerController.stop();
      await _scannerController.start();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = _normalizeCameraError(error);
      });
    } finally {
      _startingCamera = false;
    }
  }

  Future<void> _pickQrImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final decoded = await sellerBackendService.decodePaymentQrImage(
        bytes: bytes,
        mimeType: mimeType,
      );
      final payload = decoded['payload']?.toString().trim() ?? '';
      if (!mounted) return;
      if (payload.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR found in that image')),
        );
        return;
      }
      _complete(payload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read QR image: $error')),
      );
    }
  }

  String _normalizeCameraError(Object error) {
    final raw = error.toString();
    if (raw.contains('controllerAlreadyInitialized')) {
      return 'Camera session was already running. Scanner reset and retry is ready.';
    }
    return raw;
  }

  Widget _buildCameraErrorState() {
    final helpText = _isInsecureRemoteWeb
        ? 'Live camera scan is blocked on phone browser over http://192.168... Use HTTPS, a deployed .com domain, or run the native Android app for real QR scanning.'
        : 'Camera permission is blocked or unavailable. Allow camera access, then retry the live scanner.';
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.redAccent,
            size: 52,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera not available',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helpText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (_errorMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _retryCamera,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Retry Camera',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Add Payment QR',
          style: TextStyle(color: ink, fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan your existing payment QR box, or paste the QR / UPI value manually.',
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickQrImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text(
                        'Upload QR Image',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: primary.withOpacity(0.25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: shadowSm,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!_hasError)
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            for (final barcode in capture.barcodes) {
                              final value = barcode.rawValue?.trim();
                              if (value != null && value.isNotEmpty) {
                                _complete(value);
                                break;
                              }
                            }
                          },
                          errorBuilder: (context, error) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {
                                _hasError = true;
                                _errorMessage = error.errorCode.name.isNotEmpty
                                    ? _normalizeCameraError(
                                        error.errorCode.name,
                                      )
                                    : 'Camera access failed';
                              });
                            });
                            return _buildCameraErrorState();
                          },
                        )
                      else
                        _buildCameraErrorState(),
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Keep the real payment QR inside the frame. We will scan and save that exact value to this seller account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
              const SizedBox(height: 20),
              TextField(
                controller: _manualController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Paste QR payload or UPI ID',
                  hintText: 'upi://pay?... or yourname@upi',
                  prefixIcon: const Icon(Icons.qr_code_2_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _complete(_manualController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Use This Payment Value',
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
}
