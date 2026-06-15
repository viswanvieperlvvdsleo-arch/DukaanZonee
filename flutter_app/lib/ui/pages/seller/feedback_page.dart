import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerFeedbackPage extends StatelessWidget {
  const SellerFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle('Neighbor Voices', 'Community feedback and sentiment analysis.'),
        const SizedBox(height: 32),

        const Kicker('SENTIMENT ANALYTICS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: shadowSm,
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary, width: 6),
                ),
                child: const Center(child: Text('96%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22))),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Neighbor Trust Score', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('Your community loves your service. 96% of reviews in the last 30 days are positive.', style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        const Kicker('THREAD AUDIT'),
        const SizedBox(height: 12),
        _buildReviewCard(context, 'Priya S.', 'Fresh Organic Bananas', 'Always fresh and ready for pickup when I arrive. The app handshake is so fast!', 5),
        const SizedBox(height: 16),
        _buildReviewCard(context, 'Rahul M.', 'Mixed Veggie Pack', 'Good quality, but they ran out quickly. Glad I got the restock ping.', 4),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, String author, String product, String text, int rating) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(author, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Row(
                children: List.generate(5, (index) => Icon(Icons.star, color: index < rating ? Colors.amber : muted.withOpacity(0.3), size: 16)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Purchased: $product', style: const TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('"$text"', style: const TextStyle(color: muted, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback acknowledged.'))),
              icon: const Icon(Icons.reply, size: 16),
              label: const Text('Ack Feedback'),
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ),
        ],
      ),
    );
  }
}
