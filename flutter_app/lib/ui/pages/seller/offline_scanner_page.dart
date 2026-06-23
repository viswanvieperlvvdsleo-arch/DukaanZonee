import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class OfflineScannerPage extends StatefulWidget {
  const OfflineScannerPage({super.key});

  @override
  State<OfflineScannerPage> createState() => _OfflineScannerPageState();
}

class _OfflineScannerPageState extends State<OfflineScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  late final AnimationController _scanAnimationController;

  bool _isBusy = false;
  bool _isFlashOn = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _lastBarcode;
  Map<String, dynamic>? _lastLookup;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isBusy) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    await _processBarcode(raw);
  }

  Future<void> _processBarcode(String code) async {
    setState(() {
      _isBusy = true;
      _lastBarcode = code;
    });

    try {
      await HapticFeedback.mediumImpact();
      final lookup = await sellerBackendService.lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        _lastLookup = lookup;
      });

      final item = Map<String, dynamic>.from(lookup['item'] as Map? ?? {});
      final found = lookup['found'] == true && item.isNotEmpty;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductFormPage(
            initialName: found ? item['name']?.toString() : null,
            initialCategory: found ? item['category']?.toString() : null,
            initialBarcode: code,
            initialDescription: found ? item['description']?.toString() : null,
            initialImageUrl: found ? item['image_url']?.toString() : null,
            initialPrice: null,
            initialStock: null,
          ),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              found
                  ? 'Barcode matched. Product opened with known details.'
                  : 'Barcode not found. Create product form opened with barcode prefilled.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not process barcode: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _handleManualBarcode() async {
    final controller = TextEditingController(text: _lastBarcode ?? '');
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Enter Barcode',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Type barcode / SKU',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Use Barcode'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) {
      await _processBarcode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.arrow_back, color: ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline Barcode Scan',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Scan a product barcode. If we know it, we prefill details. If not, we open create-item with barcode ready.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 330,
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: shadowLg,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Stack(
                          children: [
                            if (!_hasError)
                              Positioned.fill(
                                child: MobileScanner(
                                  controller: _cameraController,
                                  onDetect: _onDetect,
                                  errorBuilder: (context, error) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _hasError = true;
                                            _errorMessage =
                                                error.errorCode.name;
                                          });
                                        });
                                    return _buildCameraError();
                                  },
                                ),
                              )
                            else
                              Positioned.fill(child: _buildCameraError()),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _ScannerOverlay(
                                  animation: _scanAnimationController,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isFlashOn = !_isFlashOn;
                                  });
                                  _cameraController.toggleTorch();
                                },
                                icon: Icon(
                                  _isFlashOn
                                      ? Icons.flashlight_on_rounded
                                      : Icons.flashlight_off_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (_isBusy)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withOpacity(0.30),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            'Enter Barcode',
                            Icons.keyboard_alt_outlined,
                            _handleManualBarcode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hasError
                                ? () {
                                    setState(() {
                                      _hasError = false;
                                      _errorMessage = '';
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Retry Camera',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: shadowSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Kicker('LAST SCAN'),
                          const SizedBox(height: 12),
                          if (_lastBarcode == null)
                            const Text(
                              'No barcode scanned yet.',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else ...[
                            Text(
                              _lastBarcode!,
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if ((_lastLookup?['found'] == true) &&
                                ((_lastLookup?['item'] as Map?)?.isNotEmpty ??
                                    false))
                              _buildLookupCard(
                                title:
                                    _lastLookup!['item']['name']?.toString() ??
                                    'Known product',
                                subtitle:
                                    '${_lastLookup!['item']['category']?.toString().isNotEmpty == true ? _lastLookup!['item']['category'] : 'Uncategorized'} • Last known Rs ${(((_lastLookup!['item']['price_cents'] as int? ?? 0) / 100)).toStringAsFixed(0)}',
                                icon: Icons.check_circle,
                                color: success,
                              )
                            else
                              _buildLookupCard(
                                title: 'Barcode not found in DukaanZone DB',
                                subtitle:
                                    'We will open create-product with this barcode prefilled.',
                                icon: Icons.edit_note_rounded,
                                color: primary,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraError() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.redAccent,
            size: 46,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera not available',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage.isEmpty
                ? 'Use manual barcode entry if camera access is blocked.'
                : _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _ScannerOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(painter: _ScannerPainter(animation.value));
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double animationValue;

  _ScannerPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.35);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.68,
      height: size.height * 0.42,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    canvas.drawPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addRRect(rrect)
        ..fillType = PathFillType.evenOdd,
      bgPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    final y = rect.top + rect.height * animationValue;
    final glowPaint = Paint()
      ..color = const Color(0xFFCBE3FC).withOpacity(0.30)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = const Color(0xFFCBE3FC)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rect.left + 12, y),
      Offset(rect.right - 12, y),
      glowPaint,
    );
    canvas.drawLine(
      Offset(rect.left + 12, y),
      Offset(rect.right - 12, y),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
