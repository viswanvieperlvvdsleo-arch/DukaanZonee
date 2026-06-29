import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerFeedbackPage extends StatelessWidget {
  const SellerFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle(
          'Neighbor Voices',
          'Community feedback and sentiment analysis.',
        ),
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
                child: const Center(
                  child: Text(
                    '0%',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neighbor Trust Score',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Trust score will update after backend product reviews are submitted.',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Kicker('THREAD AUDIT'),
        const SizedBox(height: 12),
        _buildEmptyReviewState(context),
      ],
    );
  }

  Widget _buildEmptyReviewState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 56,
            color: muted.withOpacity(0.45),
          ),
          const SizedBox(height: 14),
          const Text(
            'No backend reviews yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Real product reviews will appear here after user checkout feedback is submitted.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
