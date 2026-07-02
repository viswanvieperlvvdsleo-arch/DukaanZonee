import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerItemsPage extends StatelessWidget {
  const SellerItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Shelf View',
          style: TextStyle(
            color: isDark ? Colors.white : ink,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF131926)
            : Colors.white.withValues(alpha: .96),
        surfaceTintColor: isDark ? const Color(0xFF131926) : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const UserHomePage(),
    );
  }
}
