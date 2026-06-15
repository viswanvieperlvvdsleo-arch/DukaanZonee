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
  String _errorMessage = '';

  final List<Map<String, dynamic>> _mockBuyers = [
    {
      'name': 'Aryan Malhotra',
      'email': 'aryan@example.com',
      'block': 'Block A',
      'phone': '9876543210',
      'upi': 'aryan@ybl',
      'avatarColor': Colors.blue,
      'lastMessage': 'Can you deliver the milk tomorrow early morning?',
      'time': '10:15 AM',
      'unread': true,
    },
    {
      'name': 'Priya Singh',
      'email': 'priya@example.com',
      'block': 'Block B',
      'phone': '9812345678',
      'upi': 'priya@okhdfc',
      'avatarColor': Colors.purple,
      'lastMessage': 'Thank you for the quick banana delivery!',
      'time': 'Yesterday',
      'unread': false,
    },
  ];

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
        const PageTitle('Supplier & Buyer Scan', 'Scan physical QR codes to load customer accounts or settle invoices.'),
        const SizedBox(height: 20),
        Container(
          height: 360,
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(40), boxShadow: shadowLg),
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
                      if (barcodes.isNotEmpty) {
                        _onDetectedBuyer('Aryan Malhotra');
                      }
                    },
                    errorBuilder: (context, error) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = error.errorCode.name;
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
                    border: Border.all(color: _hasError ? Colors.redAccent : primary, width: 4), 
                    borderRadius: BorderRadius.circular(34)
                  )
                ),
                
                Positioned(
                  bottom: 32, 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      _hasError ? 'Camera Blocked' : 'Position QR within frame', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)
                    ),
                  )
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Simulation / Manual Entry Section
        Row(
          children: [
            const Expanded(child: SectionHeader('Quick Simulation', 'Simulate scanned buyer profile')),
            TextButton.icon(
              onPressed: () => _onDetectedBuyer('Aryan Malhotra'),
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text('Scan Aryan', style: TextStyle(fontWeight: FontWeight.w900)),
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        for (final buyer in _mockBuyers) 
          RepaintBoundary(
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
              child: ListTile(
                onTap: () => push(context, SellerChatRoomPage(contact: buyer)),
                leading: CircleAvatar(
                  backgroundColor: buyer['avatarColor'].withOpacity(0.12),
                  child: Text(buyer['name'][0], style: TextStyle(color: buyer['avatarColor'], fontWeight: FontWeight.w900)),
                ),
                title: Text(buyer['name'], style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
                subtitle: Text('${buyer['block']} • ${buyer['upi']}', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.qr_code_scanner, color: primary),
              ),
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
          const Icon(Icons.videocam_off_outlined, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          const Text('Camera Access Blocked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Ensure site permissions are granted to access the scanner.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _hasError = false),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            child: const Text('Retry Camera'),
          ),
        ],
      ),
    );
  }

  void _onDetectedBuyer(String buyerName) {
    final buyer = _mockBuyers.firstWhere((b) => b['name'] == buyerName, orElse: () => _mockBuyers.first);
    push(context, SellerChatRoomPage(contact: buyer));
  }
}
