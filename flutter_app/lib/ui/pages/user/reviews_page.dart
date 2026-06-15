import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key, this.productId, this.product})
    : assert(productId != null || product != null);

  final String? productId;
  final Product? product;

  String get resolvedProductId => product?.id ?? productId!;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final TextEditingController _controller = TextEditingController();
  late Future<ProductReviewsResult> _reviewsFuture;
  bool _isSubmitting = false;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = reviewService.getProductReviews(widget.resolvedProductId);
  }

  Future<void> _submitReview() async {
    final text = _controller.text.trim();
    if (text.length < 2 || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await reviewService.addProductReview(
        widget.resolvedProductId,
        rating: _rating,
        comment: text,
      );

      if (!mounted) return;
      setState(() {
        _controller.clear();
        _rating = 5;
        _reviewsFuture = Future.value(result);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login required to write a review.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteReview(ProductReview review) async {
    try {
      final result = await reviewService.deleteProductReview(
        widget.resolvedProductId,
        review.id,
      );
      if (!mounted) return;
      setState(() => _reviewsFuture = Future.value(result));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review deleted for everyone.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this review.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          product == null ? 'Reviews' : '${product.name} Reviews',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<ProductReviewsResult>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ReviewsEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load reviews',
              subtitle: 'Check the backend server and try again.',
              action: () => setState(
                () => _reviewsFuture = reviewService.getProductReviews(
                  widget.resolvedProductId,
                ),
              ),
            );
          }

          final result =
              snapshot.data ??
              const ProductReviewsResult(
                reviews: [],
                count: 0,
                averageRating: 0,
              );

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: result.reviews.length + 2,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == 0) return _reviewComposer();
              if (index == 1) return _ReviewSummary(result: result);

              final review = result.reviews[index - 2];
              final canDelete =
                  review.userId == authService.currentUser.value?.id;
              return _ReviewTile(
                review: review,
                canDelete: canDelete,
                onDelete: () => _deleteReview(review),
              );
            },
          );
        },
      ),
    );
  }

  Widget _reviewComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Write a review',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              final selected = value <= _rating;
              return IconButton(
                tooltip: '$value star rating',
                onPressed: () => setState(() => _rating = value),
                icon: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: selected ? const Color(0xFFF59E0B) : muted,
                  size: 28,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'How was the product?',
              filled: true,
              fillColor: bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _isSubmitting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Send review',
                      icon: const Icon(Icons.send, color: primary),
                      onPressed: _submitReview,
                    ),
            ),
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitReview(),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.result});

  final ProductReviewsResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reviews_outlined, color: primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.count == 0
                  ? 'No reviews yet. Be the first neighbor to share one.'
                  : '${result.averageRating.toStringAsFixed(1)} average from ${result.count} review${result.count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: ink,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.canDelete,
    required this.onDelete,
  });

  final ProductReview review;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: bg,
            child: Icon(Icons.person, size: 18, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  review.comment,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            PopupMenuButton<String>(
              tooltip: 'Review options',
              icon: const Icon(Icons.more_vert_rounded, color: muted),
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Delete for everyone',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReviewsEmptyState extends StatelessWidget {
  const _ReviewsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: muted, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
