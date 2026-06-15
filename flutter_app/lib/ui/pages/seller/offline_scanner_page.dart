import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class OfflineScannerPage extends StatefulWidget {
  const OfflineScannerPage({super.key});

  @override
  State<OfflineScannerPage> createState() => _OfflineScannerPageState();
}

class _OfflineScannerPageState extends State<OfflineScannerPage> with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController();
  late AnimationController _scanAnimationController;

  // State Variables
  bool _isVisionMode = true; // True for "Lens Mode", False for "Barcode Mode"
  bool _isFlashOn = false;
  bool _isProcessing = false;

  // Session counters
  int _itemsScanned = 0;
  int _imagesCaptured = 0;

  // The Cart - Pre-populated with 3 Fuji Apples 1KG to match reference design immediately
  final List<Map<String, dynamic>> _cart = [
    {
      'id': 'fuji_apple_1',
      'name': 'Fuji Apples 1KG',
      'price': 220.0,
      'quantity': 1,
      'store': 'Pooja General Store',
    },
    {
      'id': 'fuji_apple_2',
      'name': 'Fuji Apples 1KG',
      'price': 220.0,
      'quantity': 1,
      'store': 'Pooja General Store',
    },
    {
      'id': 'fuji_apple_3',
      'name': 'Fuji Apples 1KG',
      'price': 220.0,
      'quantity': 1,
      'store': 'Pooja General Store',
    },
  ];

  // Mock Database
  final Map<String, Map<String, dynamic>> _mockDatabase = {
    'fuji_apple_1': {
      'name': 'Fuji Apples 1KG',
      'price': 220.0,
      'store': 'Pooja General Store',
    },
    'mango_1': {
      'name': 'Fresh Mangoes 1KG',
      'price': 180.0,
      'store': 'Pooja General Store',
    },
    'banana_1': {
      'name': 'Organic Bananas 1Dozen',
      'price': 60.0,
      'store': 'Pooja General Store',
    },
  };

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

  // Simulate scanning a product
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      _processScannedCode(barcodes.first.rawValue!);
    }
  }

  void _processScannedCode(String code) {
    setState(() => _isProcessing = true);
    
    // Simulate AI / Network delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      
      setState(() {
        final product = _mockDatabase[code] ?? {
          'name': 'Fuji Apples 1KG',
          'price': 220.0,
          'store': 'Pooja General Store',
        };
        
        // Check if already in cart
        final existingIndex = _cart.indexWhere((item) => item['id'] == code);
        if (existingIndex != -1) {
          _cart[existingIndex]['quantity'] += 1;
        } else {
          _cart.add({
            'id': code,
            'name': product['name'] ?? 'Fuji Apples 1KG',
            'price': product['price'] ?? 220.0,
            'store': product['store'] ?? 'Pooja General Store',
            'quantity': 1,
          });
        }
        
        // Increment session counters
        _itemsScanned++;
        if (_isVisionMode) {
          _imagesCaptured++;
        }
        
        _isProcessing = false;
      });
    });
  }

  void _simulateGoogleLensScan() {
    // For demonstration, randomly pick an item when they tap the screen in Vision Mode
    final codes = _mockDatabase.keys.toList();
    codes.shuffle();
    _processScannedCode(codes.first);
  }

  double get _subtotal {
    return _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  double get _commission {
    return _subtotal * 0.03; // 3% commission
  }

  double get _payableTotal {
    return _subtotal - _commission;
  }

  void _handleCheckout() {
    if (_cart.isEmpty) return;
    
    // Play Cash Register sound tone on successful sale checkout
    final oldTone = soundService.selectedTone.value;
    soundService.selectedTone.value = 'Cash Register';
    soundService.playSelectedTone().then((_) {
      soundService.selectedTone.value = oldTone;
    });

    // Increase SBI Bank balance on successful received POS payment
    final double amountVal = _payableTotal;
    final map = Map<String, double>.from(globalBankBalances.value);
    map['SBI Bank'] = (map['SBI Bank'] ?? 0.0) + amountVal;
    globalBankBalances.value = map;

    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: success,
                child: Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sale Complete!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Collected: ₹${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
              ),
              const SizedBox(height: 4),
              Text(
                'DukaanZone Commission: ₹${_commission.toStringAsFixed(2)} deducted',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _cart.clear();
                      _itemsScanned = 0;
                      _imagesCaptured = 0;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Next Customer', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cameraHeight = MediaQuery.of(context).size.height * 0.42;
    final double sheetTop = MediaQuery.of(context).size.height * 0.40;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Feed (Constrained to top portion)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: cameraHeight,
            child: GestureDetector(
              onTap: _isVisionMode ? _simulateGoogleLensScan : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      child: MobileScanner(
                        controller: _cameraController,
                        onDetect: _isVisionMode ? (_) {} : _onDetect,
                      ),
                    ),
                  ),
                  // Faint overlay gradient for premium camera viewport look
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, 0.2),
                          radius: 0.8,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 2. Custom Scanner Overlay (Draws brackets and laser line)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: cameraHeight,
            child: IgnorePointer(
              child: _ScannerOverlayPainter(
                animation: _scanAnimationController,
                isVisionMode: _isVisionMode,
              ),
            ),
          ),
          
          // 3. Top Action Controls (Close button & Flash/Switch pill)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top-Left Close Button (Glass circle)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ),
                
                // Top-Right Flashlight & Camera Switch Pill
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isFlashOn = !_isFlashOn;
                            _cameraController.toggleTorch();
                          });
                        },
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                        onPressed: () => _cameraController.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Center-floating Mode Toggle & Instruction Text
          Positioned(
            top: cameraHeight * 0.45,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle Pill: BARCODE vs AI VISION
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Barcode Mode Option
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isVisionMode = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isVisionMode ? const Color(0xFFCBE3FC) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.view_week_rounded,
                                color: !_isVisionMode ? ink : Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'BARCODE',
                                style: TextStyle(
                                  color: !_isVisionMode ? ink : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // AI Vision Mode Option
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isVisionMode = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isVisionMode ? const Color(0xFFCBE3FC) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                color: _isVisionMode ? ink : Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI VISION',
                                style: TextStyle(
                                  color: _isVisionMode ? ink : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Instruction Text
                const Text(
                  'Tapping anywhere',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isVisionMode ? 'Point camera at product/barcode' : 'Align barcode within frame',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 5. White Bottom Sheet
          Positioned(
            top: sheetTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F8FB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle at top of sheet
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Scrollable Area
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Scanned Items List
                          if (_cart.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Product Icon Box
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F3F6),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.apple,
                                          color: ink,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item['name'],
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: ink,
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: ink,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${item['quantity']}x',
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  item['store'] ?? 'Store',
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, size: 48, color: muted),
                                  SizedBox(height: 12),
                                  Text(
                                    'No items scanned yet',
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Scan barcodes or tap the screen in AI Vision mode to add items',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // SUMMARY Section
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                                  child: Text(
                                    'SUMMARY',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: ink,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Divider(height: 1, color: Colors.grey.shade200),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Items Scanned: $_itemsScanned',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: ink,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        VerticalDivider(width: 1, color: Colors.grey.shade200),
                                        Expanded(
                                          child: Text(
                                            'Images Captured: $_imagesCaptured',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: ink,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // FINANCIALS Section
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'FINANCIALS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Subtotal',
                                      style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '₹${_subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'DukaanZone Commission (3%)',
                                      style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '- ₹${_commission.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(height: 1, color: Colors.grey.shade200),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Payable',
                                      style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '₹${_payableTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Verify & Deduct Button at the bottom
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade100)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty ? null : _handleCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCBE3FC),
                          disabledBackgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Verify & Deduct (₹${_payableTotal.toStringAsFixed(2)})',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: const CircularProgressIndicator(color: primary),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends StatelessWidget {
  final Animation<double> animation;
  final bool isVisionMode;

  const _ScannerOverlayPainter({required this.animation, required this.isVisionMode});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: ScannerPainter(animationValue: animation.value, isVisionMode: isVisionMode),
        );
      },
    );
  }
}

class ScannerPainter extends CustomPainter {
  final double animationValue;
  final bool isVisionMode;

  ScannerPainter({required this.animationValue, required this.isVisionMode});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.4);
    
    // Position the window in the center of the camera viewport
    final centerY = size.height * 0.5; 
    
    final windowWidth = size.width * 0.65;
    final windowHeight = isVisionMode ? size.height * 0.6 : size.height * 0.35;
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, centerY), width: windowWidth, height: windowHeight),
      const Radius.circular(24),
    );

    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(windowRect)
        ..fillType = PathFillType.evenOdd,
      bgPaint,
    );

    // Premium Bracket Corners
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
      
    final len = 24.0;
    final rect = windowRect.outerRect;
    final pad = 0.0; 
    
    // Top Left
    canvas.drawLine(Offset(rect.left - pad, rect.top + len), Offset(rect.left - pad, rect.top - pad), cornerPaint);
    canvas.drawLine(Offset(rect.left - pad, rect.top - pad), Offset(rect.left + len, rect.top - pad), cornerPaint);
    
    // Top Right
    canvas.drawLine(Offset(rect.right + pad, rect.top + len), Offset(rect.right + pad, rect.top - pad), cornerPaint);
    canvas.drawLine(Offset(rect.right + pad, rect.top - pad), Offset(rect.right - len, rect.top - pad), cornerPaint);
    
    // Bottom Left
    canvas.drawLine(Offset(rect.left - pad, rect.bottom - len), Offset(rect.left - pad, rect.bottom + pad), cornerPaint);
    canvas.drawLine(Offset(rect.left - pad, rect.bottom + pad), Offset(rect.left + len, rect.bottom + pad), cornerPaint);
    
    // Bottom Right
    canvas.drawLine(Offset(rect.right + pad, rect.bottom - len), Offset(rect.right + pad, rect.bottom + pad), cornerPaint);
    canvas.drawLine(Offset(rect.right + pad, rect.bottom + pad), Offset(rect.right - len, rect.bottom + pad), cornerPaint);

    // Animated Laser Line
    final lineY = rect.top + (rect.height * animationValue);
    final laserPaint = Paint()
      ..color = const Color(0xFFCBE3FC)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(Offset(rect.left + 5, lineY), Offset(rect.right - 5, lineY), laserPaint);
    
    // Laser Glow
    final glowPaint = Paint()
      ..color = const Color(0xFFCBE3FC).withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(rect.left + 5, lineY), Offset(rect.right - 5, lineY), glowPaint);
  }

  @override
  bool shouldRepaint(ScannerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isVisionMode != isVisionMode;
  }
}

