import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SavingsDashboardPage extends StatelessWidget {
  const SavingsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text('My Impact', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder<SavingsData>(
        valueListenable: savingsService.data,
        builder: (context, data, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainCard(data),
                const SizedBox(height: 32),
                const SectionHeader('Environmental Impact', 'Buying Local'),
                const SizedBox(height: 16),
                _buildEcoCard(data),
                const SizedBox(height: 32),
                const SectionHeader('Recent Savings', 'Last 30 Days'),
                const SizedBox(height: 16),
                _buildSavingsHistory(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCard(SavingsData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: shadowLg,
      ),
      child: Column(
        children: [
          const Text('Total Money Saved', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('₹${data.totalSaved.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Local Trips', '${data.localTrips}'),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildStat('Avg. % Off', '12%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEcoCard(SavingsData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: shadowSm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: success.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.eco_outlined, color: success, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CO2 Emissions Saved', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text('You saved ${data.carbonSaved}kg of CO2 by walking or buying nearby.', style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsHistory() {
    return Column(
      children: [
        _HistoryItem('Fresh Mart', '₹45 saved', 'Yesterday'),
        _HistoryItem('Corner Store', '₹12 saved', '2 days ago'),
        _HistoryItem('Electronics Hub', '₹120 saved', '5 days ago'),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem(this.shop, this.amount, this.time);
  final String shop, amount, time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: muted.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(time, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
          Text(amount, style: const TextStyle(color: success, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
