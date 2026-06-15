import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class OrderListPage extends StatelessWidget {
  const OrderListPage({super.key, required this.title, required this.subtitle, required this.seller});
  final String title;
  final String subtitle;
  final bool seller;
  @override
  Widget build(BuildContext context) => AppPage(children: [
        PageTitle(title, subtitle),
        const SizedBox(height: 18),
        SellerOrderCard(id: '#DZ-4581', name: seller ? 'Rahul Sharma' : 'Organic Milk + Bread', amount: '₹202.00', status: seller ? 'Paid' : 'Ready for pickup', items: const ['Organic Milk (1L)', 'Brown Eggs (6pk)']),
        const SellerOrderCard(id: '#DZ-4580', name: 'Noise-Cancelling Pro', amount: '₹12,499.00', status: 'Delivered', items: ['Space Grey Unit']),
      ]);
}

