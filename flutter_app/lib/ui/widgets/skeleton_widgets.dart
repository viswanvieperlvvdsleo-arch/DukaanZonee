import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

// ─── Shimmer base ────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({this.width, this.height, this.radius = 12});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF2F5);
    final highlight = isDark ? const Color(0xFF334155) : Colors.white;

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                (_shimmer.value - 0.5).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.5).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Convenience helpers ─────────────────────────────────────────────────────

Widget _skel({double? w, double? h, double r = 12}) =>
    _ShimmerBox(width: w, height: h, radius: r);

// ─── Page-level skeletons ────────────────────────────────────────────────────

/// Full-page skeleton for any list/card page
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.cardCount = 4});
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skel(w: 220, h: 32, r: 12),
              const SizedBox(height: 8),
              _skel(w: 320, h: 14, r: 7),
              const SizedBox(height: 24),
              for (int i = 0; i < cardCount; i++) ...[
                CardSkeleton(),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Single card skeleton
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          _skel(w: 74, h: 74, r: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skel(w: 180, h: 17, r: 8),
                const SizedBox(height: 7),
                _skel(w: 140, h: 12, r: 6),
                const SizedBox(height: 10),
                _skel(w: 82, h: 18, r: 9),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _skel(w: 34, h: 34, r: 17),
        ],
      ),
    );
  }
}

/// Product grid skeleton (2-column)
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.6,
      children: List.generate(count, (_) => const _ProductCardSkeleton()),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: shadowSm,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _skel(r: 24)),
          const SizedBox(height: 12),
          _skel(h: 16, r: 8),
          const SizedBox(height: 8),
          _skel(w: 80, h: 14, r: 7),
          const SizedBox(height: 8),
          _skel(w: 60, h: 20, r: 10),
        ],
      ),
    );
  }
}

class _HomeProductSkeleton extends StatelessWidget {
  const _HomeProductSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 132,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: const [
                    Positioned(left: 6, top: 6, child: PremiumSkeleton(width: 28, height: 28, radius: 14)),
                    Positioned(right: 6, top: 6, child: PremiumSkeleton(width: 28, height: 28, radius: 14)),
                    Center(child: PremiumSkeleton(width: 58, height: 58, radius: 18)),
                    Positioned(left: 8, bottom: 8, child: PremiumSkeleton(width: 64, height: 28, radius: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const PremiumSkeleton(width: 122, height: 17, radius: 8),
              const SizedBox(height: 6),
              const PremiumSkeleton(width: 72, height: 17, radius: 8),
              const Spacer(),
              Row(
                children: const [
                  Expanded(child: PremiumSkeleton(height: 12, radius: 6)),
                  SizedBox(width: 8),
                  PremiumSkeleton(width: 72, height: 32, radius: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeProductSkeleton extends StatelessWidget {
  const _LargeProductSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  children: const [
                    Positioned(left: 6, top: 6, child: PremiumSkeleton(width: 28, height: 28, radius: 14)),
                    Positioned(right: 6, top: 6, child: PremiumSkeleton(width: 28, height: 28, radius: 14)),
                    Center(child: PremiumSkeleton(width: 74, height: 74, radius: 22)),
                    Positioned(left: 12, bottom: 12, child: PremiumSkeleton(width: 82, height: 28, radius: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const PremiumSkeleton(width: 180, height: 19, radius: 9),
            const SizedBox(height: 8),
            const PremiumSkeleton(width: 150, height: 13, radius: 7),
            const SizedBox(height: 10),
            const PremiumSkeleton(width: 86, height: 21, radius: 10),
            const SizedBox(height: 10),
            const PremiumSkeleton(height: 5, radius: 999),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(child: PremiumSkeleton(height: 13, radius: 7)),
                SizedBox(width: 10),
                PremiumSkeleton(width: 72, height: 34, radius: 17),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip skeleton (for carousels / lists)
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(count, (i) {
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
            child: Container(
              width: 140,
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(28),
                boxShadow: shadowSm,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _skel(r: 20)),
                  const SizedBox(height: 10),
                  _skel(h: 14, r: 7),
                  const SizedBox(height: 6),
                  _skel(w: 60, h: 12, r: 6),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Button with loading spinner — wrap any button with this
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.color,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? primary;
    return TapScale(
      onTap: isLoading ? () {} : onTap,
      scale: 0.97,
      child: Container(
        height: compact ? 42 : 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          boxShadow: [
            BoxShadow(
              color: bg.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: compact ? 16 : 20,
                height: compact ? 16 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.9),
                  ),
                ),
              )
            else
              Icon(icon, color: Colors.white, size: compact ? 16 : 20),
            const SizedBox(width: 8),
            Text(
              isLoading ? 'Please wait...' : label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 13 : 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline icon button with spinner
class SpinIconButton extends StatelessWidget {
  const SpinIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.color = primary,
    this.size = 42,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

/// Global PremiumSkeleton alias/widget for premium shimmer effects
class PremiumSkeleton extends StatelessWidget {
  const PremiumSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: width,
      height: height,
      radius: radius,
    );
  }
}

// ─── Skeleton types ────────────────────────────────────────────────────────────

enum SkeletonType {
  auth,
  home,
  search,
  saved,
  settings,
  history,
  notifications,
  dashboard,
  sellerDash,
  list,
  details,
  chat,
  grid,
  map,
  scan,
  accounts,
  shops,
  financials,
  signals,
  promos,
  disputes,
}

class PremiumSkeletonPageWrapper extends StatefulWidget {
  const PremiumSkeletonPageWrapper({
    super.key,
    required this.child,
    this.type = SkeletonType.list,
    this.loadingDuration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final SkeletonType type;
  final Duration loadingDuration;

  @override
  State<PremiumSkeletonPageWrapper> createState() => _PremiumSkeletonPageWrapperState();
}

class _PremiumSkeletonPageWrapperState extends State<PremiumSkeletonPageWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.loadingDuration, () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isLoading ? _buildSkeleton(context) : widget.child,
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    switch (widget.type) {
      case SkeletonType.auth:
        return _buildAuthSkeleton(bgColor, isDark);
      case SkeletonType.home:
        return _buildHomeSkeleton(bgColor, isDark);
      case SkeletonType.search:
        return _buildSearchSkeleton(bgColor, isDark);
      case SkeletonType.saved:
        return _buildSavedSkeleton(bgColor, isDark);
      case SkeletonType.settings:
        return _buildSettingsSkeleton(bgColor, isDark);
      case SkeletonType.history:
        return _buildHistorySkeleton(bgColor, isDark);
      case SkeletonType.notifications:
        return _buildNotificationsSkeleton(bgColor, isDark);
      case SkeletonType.map:
        return _buildMapSkeleton(bgColor, isDark);
      case SkeletonType.scan:
        return _buildScanSkeleton(bgColor, isDark);
      case SkeletonType.dashboard:
      case SkeletonType.sellerDash:
        return _buildDashboardSkeleton(bgColor, isDark);
      case SkeletonType.shops:
        return _buildShopsSkeleton(bgColor, isDark);
      case SkeletonType.financials:
        return _buildFinancialsSkeleton(bgColor, isDark);
      case SkeletonType.signals:
        return _buildSignalsSkeleton(bgColor, isDark);
      case SkeletonType.promos:
        return _buildPromosSkeleton(bgColor, isDark);
      case SkeletonType.disputes:
        return _buildDisputesSkeleton(bgColor, isDark);
      case SkeletonType.accounts:
        return _buildAccountsSkeleton(bgColor, isDark);
      case SkeletonType.details:
        return _buildDetailsSkeleton(bgColor, isDark);
      case SkeletonType.chat:
        return _buildChatSkeleton(bgColor, isDark);
      case SkeletonType.grid:
        return _buildGridSkeleton(bgColor, isDark);
      case SkeletonType.list:
        return _buildListSkeleton(bgColor, isDark);
    }
  }

  Widget _buildAuthSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSkeleton(width: 64, height: 64, radius: 18),
                const SizedBox(height: 32),
                const PremiumSkeleton(width: 240, height: 34, radius: 12),
                const SizedBox(height: 10),
                const PremiumSkeleton(width: 300, height: 16, radius: 8),
                const SizedBox(height: 32),
                Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      PremiumSkeleton(width: 24, height: 24, radius: 12),
                      SizedBox(width: 14),
                      PremiumSkeleton(width: 130, height: 14, radius: 7),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      PremiumSkeleton(width: 24, height: 24, radius: 12),
                      SizedBox(width: 14),
                      PremiumSkeleton(width: 110, height: 14, radius: 7),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: PremiumSkeleton(width: 120, height: 16, radius: 8),
                ),
                const SizedBox(height: 32),
                const PremiumSkeleton(height: 58, radius: 28),
                const SizedBox(height: 24),
                const Center(child: PremiumSkeleton(width: 34, height: 14, radius: 7)),
                const SizedBox(height: 24),
                const PremiumSkeleton(height: 54, radius: 27),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: const Icon(Icons.arrow_back, color: ink),
        title: Container(
          height: 54,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: const Row(
            children: [
              PremiumSkeleton(width: 22, height: 22, radius: 11),
              SizedBox(width: 12),
              Expanded(child: PremiumSkeleton(height: 14, radius: 7)),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSkeleton(width: 150, height: 12, radius: 6),
                const SizedBox(height: 14),
                for (int i = 0; i < 3; i++) ...[
                  _buildCompactProductTileSkeleton(isDark),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                const PremiumSkeleton(width: 132, height: 12, radius: 6),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    PremiumSkeleton(width: 118, height: 38, radius: 16),
                    PremiumSkeleton(width: 86, height: 38, radius: 16),
                    PremiumSkeleton(width: 94, height: 38, radius: 16),
                    PremiumSkeleton(width: 126, height: 38, radius: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSkeleton(width: 260, height: 32, radius: 12),
                  SizedBox(height: 8),
                  PremiumSkeleton(width: 320, height: 14, radius: 7),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: const [
                    Expanded(child: PremiumSkeleton(height: 38, radius: 11)),
                    SizedBox(width: 8),
                    Expanded(child: PremiumSkeleton(height: 38, radius: 11)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                itemCount: 3,
                itemBuilder: (_, __) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: shadowSm,
                  ),
                  child: Row(
                    children: [
                      const PremiumSkeleton(width: 96, height: 96, radius: 18),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            PremiumSkeleton(width: 170, height: 18, radius: 9),
                            SizedBox(height: 8),
                            PremiumSkeleton(width: 130, height: 12, radius: 6),
                            SizedBox(height: 12),
                            PremiumSkeleton(width: 82, height: 20, radius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const PremiumSkeleton(width: 38, height: 38, radius: 19),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSkeleton(width: 220, height: 32, radius: 12),
                const SizedBox(height: 8),
                const PremiumSkeleton(width: 330, height: 14, radius: 7),
                const SizedBox(height: 18),
                for (int i = 0; i < 4; i++) ...[
                  _buildSettingsCardSkeleton(isDark),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? bgColor : Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSkeleton(width: 230, height: 32, radius: 12),
                const SizedBox(height: 8),
                const PremiumSkeleton(width: 330, height: 14, radius: 7),
                const SizedBox(height: 24),
                for (int i = 0; i < 4; i++) ...[
                  _buildHistoryItemSkeleton(isDark),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? bgColor : Colors.white,
      body: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: 5,
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  PremiumSkeleton(width: 220, height: 38, radius: 12),
                  Row(
                    children: [
                      PremiumSkeleton(width: 72, height: 30, radius: 15),
                      SizedBox(width: 8),
                      PremiumSkeleton(width: 32, height: 32, radius: 16),
                    ],
                  ),
                ],
              ),
            );
          }
          final darkCard = index.isOdd;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: darkCard
                  ? const Color(0xFF1E242C)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F4F9)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: darkCard
                  ? [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 8, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    PremiumSkeleton(width: 40, height: 40, radius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PremiumSkeleton(height: 14, radius: 7),
                          SizedBox(height: 6),
                          PremiumSkeleton(width: 220, height: 14, radius: 7),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    PremiumSkeleton(width: 6, height: 6, radius: 3),
                  ],
                ),
                const SizedBox(height: 12),
                const PremiumSkeleton(width: 92, height: 28, radius: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 420,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFF182231),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: shadowLg,
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 92, 28, 34),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumSkeleton(width: 98, height: 30, radius: 15),
                      const SizedBox(height: 20),
                      const PremiumSkeleton(width: 560, height: 42, radius: 12),
                      const SizedBox(height: 18),
                      const PremiumSkeleton(width: 130, height: 32, radius: 10),
                      const SizedBox(height: 20),
                      const PremiumSkeleton(width: 240, height: 18, radius: 9),
                      const SizedBox(height: 12),
                      const PremiumSkeleton(width: 300, height: 16, radius: 8),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 118,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                const PremiumSkeleton(width: 174, height: 12, radius: 6),
                const SizedBox(height: 14),
                SizedBox(
                  height: 294,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, index) => const _HomeProductSkeleton(),
                  ),
                ),
                const SizedBox(height: 26),
                const PremiumSkeleton(width: 190, height: 12, radius: 6),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    PremiumSkeleton(width: 140, height: 20, radius: 8),
                    PremiumSkeleton(width: 60, height: 16, radius: 8),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 720 ? 3 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 18,
                      childAspectRatio: constraints.maxWidth > 720 ? .58 : .43,
                      children: List.generate(4, (_) => const _LargeProductSkeleton()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Full screen map shimmer background
          const PremiumSkeleton(height: double.infinity, radius: 0),
          // Top search bar float
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: shadowLg,
                    ),
                    child: Row(
                      children: const [
                        PremiumSkeleton(width: 24, height: 24, radius: 12),
                        SizedBox(width: 12),
                        Expanded(child: PremiumSkeleton(height: 16, radius: 8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Map category chips row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: List.generate(4, (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 80,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(child: PremiumSkeleton(width: 50, height: 12, radius: 6)),
                        ),
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom card float
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: shadowLg,
              ),
              child: Row(
                children: [
                  const PremiumSkeleton(width: 100, height: double.infinity, radius: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        PremiumSkeleton(width: 120, height: 18, radius: 9),
                        SizedBox(height: 8),
                        PremiumSkeleton(width: 80, height: 14, radius: 7),
                        Spacer(),
                        PremiumSkeleton(width: 60, height: 24, radius: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.black, // viewfinder is dark
      body: Stack(
        children: [
          // Semi-transparent overlay shimmer
          Opacity(
            opacity: 0.15,
            child: const PremiumSkeleton(height: double.infinity, radius: 0),
          ),
          // Scan outline box in center
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: primary, width: 4),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Stack(
                    children: [
                      // Scanner line simulation
                      Center(
                        child: Container(
                          width: 220,
                          height: 3,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Align QR Code within frame',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          // Top back/settings row
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  PremiumSkeleton(width: 40, height: 40, radius: 20),
                  PremiumSkeleton(width: 40, height: 40, radius: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSkeleton(width: 220, height: 32, radius: 12),
                const SizedBox(height: 8),
                const PremiumSkeleton(width: 320, height: 14, radius: 7),
                const SizedBox(height: 24),
                for (int i = 0; i < 4; i++) ...[
                  _buildCompactProductTileSkeleton(isDark),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 220, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 320, height: 16, radius: 6),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 180, height: 12, radius: 6),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  return GridView.count(
                    crossAxisCount: compact ? 2 : 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: compact ? 1.7 : 1.25,
                    children: List.generate(4, (_) => Container(
                      padding: EdgeInsets.all(compact ? 14 : 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: shadowSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          PremiumSkeleton(width: 32, height: 32, radius: 16),
                          PremiumSkeleton(width: 80, height: 20, radius: 8),
                          PremiumSkeleton(width: 60, height: 12, radius: 6),
                        ],
                      ),
                    )),
                  );
                },
              ),
              const SizedBox(height: 28),

              Container(
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSkeleton(width: 140, height: 20, radius: 8),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: PremiumSkeleton(
                              height: (30 + i * 20).toDouble(),
                              radius: 8,
                            ),
                          ),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 180, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), boxShadow: shadowSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSkeleton(width: 160, height: 18, radius: 8),
                    const SizedBox(height: 24),
                    const PremiumSkeleton(height: 12, radius: 6),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 160, height: 12, radius: 6),
              const SizedBox(height: 12),
              for (int i = 0; i < 3; i++) ...[
                _buildCardItem(isDark),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopsSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 220, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 320, height: 16, radius: 6),
              const SizedBox(height: 32),

              // Search bar shimmer
              Container(
                height: 52,
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              for (int i = 0; i < 3; i++) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: shadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const PremiumSkeleton(width: 48, height: 48, radius: 12),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                PremiumSkeleton(width: 140, height: 16, radius: 8),
                                SizedBox(height: 6),
                                PremiumSkeleton(width: 180, height: 12, radius: 6),
                              ],
                            ),
                          ),
                          const PremiumSkeleton(width: 60, height: 22, radius: 10),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: const [
                          PremiumSkeleton(width: 80, height: 36, radius: 10),
                          SizedBox(width: 12),
                          PremiumSkeleton(width: 80, height: 36, radius: 10),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialsSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 220, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 320, height: 16, radius: 6),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Row(
                children: List.generate(3, (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          PremiumSkeleton(width: 70, height: 10, radius: 5),
                          SizedBox(height: 8),
                          PremiumSkeleton(width: 50, height: 18, radius: 9),
                        ],
                      ),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 150, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(height: 52, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 16),
              for (int i = 0; i < 3; i++) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: shadowSm),
                  child: Row(
                    children: [
                      const PremiumSkeleton(width: 48, height: 48, radius: 14),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            PremiumSkeleton(width: 130, height: 16, radius: 8),
                            SizedBox(height: 4),
                            PremiumSkeleton(width: 180, height: 12, radius: 6),
                          ],
                        ),
                      ),
                      const PremiumSkeleton(width: 60, height: 16, radius: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalsSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 200, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 320, height: 16, radius: 6),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                height: 60,
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 28),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSkeleton(width: 200, height: 22, radius: 10),
                    const SizedBox(height: 20),
                    Container(height: 48, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16))),
                    const SizedBox(height: 16),
                    Container(height: 96, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16))),
                    const SizedBox(height: 24),
                    const PremiumSkeleton(height: 52, radius: 16),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              for (int i = 0; i < 2; i++) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      PremiumSkeleton(width: 160, height: 16, radius: 8),
                      SizedBox(height: 6),
                      PremiumSkeleton(height: 12, radius: 6),
                      SizedBox(height: 10),
                      PremiumSkeleton(width: 120, height: 16, radius: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromosSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 220, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 320, height: 16, radius: 6),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        PremiumSkeleton(width: 48, height: 48, radius: 12),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PremiumSkeleton(width: 160, height: 16, radius: 8),
                              SizedBox(height: 4),
                              PremiumSkeleton(width: 200, height: 12, radius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: const [
                        Expanded(child: PremiumSkeleton(height: 36, radius: 12)),
                        SizedBox(width: 16),
                        Expanded(child: PremiumSkeleton(height: 36, radius: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      decoration: const BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              PremiumSkeleton(width: 120, height: 14, radius: 7),
                              PremiumSkeleton(width: 50, height: 18, radius: 8),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              PremiumSkeleton(width: 70, height: 12, radius: 6),
                              PremiumSkeleton(width: 70, height: 12, radius: 6),
                              PremiumSkeleton(width: 70, height: 12, radius: 6),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisputesSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 220, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 320, height: 16, radius: 6),
              const SizedBox(height: 32),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(height: 52, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18))),
              const SizedBox(height: 28),

              const PremiumSkeleton(width: 150, height: 12, radius: 6),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Container(height: 60, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)))),
                  const SizedBox(width: 12),
                  Expanded(child: Container(height: 60, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)))),
                  const SizedBox(width: 12),
                  Expanded(child: Container(height: 60, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)))),
                ],
              ),
              const SizedBox(height: 28),

              const PremiumSkeleton(width: 140, height: 12, radius: 6),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Container(height: 52, decoration: BoxDecoration(color: primary.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)))),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          PremiumSkeleton(width: 120, height: 16, radius: 8),
                          SizedBox(height: 10),
                          PremiumSkeleton(height: 12, radius: 6),
                          SizedBox(height: 16),
                          PremiumSkeleton(height: 36, radius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsSkeleton(Color bgColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 180, height: 28, radius: 10),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 300, height: 16, radius: 6),
              const SizedBox(height: 24),

              // Search bar
              Container(height: 48, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 20),

              // Tabs
              Container(height: 50, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18))),
              const SizedBox(height: 20),

              // Account cards list
              for (int i = 0; i < 3; i++) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), boxShadow: shadowSm),
                  child: Row(
                    children: [
                      const PremiumSkeleton(width: 52, height: 52, radius: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            PremiumSkeleton(width: 130, height: 16, radius: 8),
                            SizedBox(height: 4),
                            PremiumSkeleton(width: 160, height: 12, radius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          PremiumSkeleton(width: 50, height: 14, radius: 7),
                          SizedBox(height: 4),
                          PremiumSkeleton(width: 40, height: 16, radius: 8),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const PremiumSkeleton(width: 24, height: 24, radius: 12),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PremiumSkeleton(width: 40, height: 40, radius: 20),
                  const SizedBox(width: 16),
                  const PremiumSkeleton(width: 180, height: 26, radius: 10),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: shadowSm,
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(32)),
                  child: PremiumSkeleton(height: double.infinity, radius: 32),
                ),
              ),
              const SizedBox(height: 28),
              const PremiumSkeleton(width: 220, height: 24, radius: 10),
              const SizedBox(height: 12),
              const PremiumSkeleton(width: 100, height: 18, radius: 8),
              const SizedBox(height: 24),
              const PremiumSkeleton(height: 12, radius: 6),
              const SizedBox(height: 8),
              const PremiumSkeleton(height: 12, radius: 6),
              const SizedBox(height: 8),
              const PremiumSkeleton(width: 180, height: 12, radius: 6),
              const SizedBox(height: 36),
              Row(
                children: [
                  const Expanded(child: PremiumSkeleton(height: 56, radius: 28)),
                  const SizedBox(width: 16),
                  const PremiumSkeleton(width: 56, height: 56, radius: 28),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                children: [
                  const PremiumSkeleton(width: 40, height: 40, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        PremiumSkeleton(width: 120, height: 16, radius: 8),
                        SizedBox(height: 6),
                        PremiumSkeleton(width: 80, height: 10, radius: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildMessageBubble(true, 140, isDark),
                    const SizedBox(height: 16),
                    _buildMessageBubble(false, 200, isDark),
                    const SizedBox(height: 16),
                    _buildMessageBubble(true, 90, isDark),
                    const SizedBox(height: 16),
                    _buildMessageBubble(false, 160, isDark),
                    const SizedBox(height: 16),
                    _buildMessageBubble(true, 240, isDark),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                children: [
                  const Expanded(child: PremiumSkeleton(height: 48, radius: 24)),
                  const SizedBox(width: 12),
                  const PremiumSkeleton(width: 48, height: 48, radius: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSkeleton(Color bgColor, bool isDark) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSkeleton(width: 150, height: 26, radius: 10),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
                children: List.generate(4, (_) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: shadowSm,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: PremiumSkeleton(radius: 20)),
                      const SizedBox(height: 12),
                      const PremiumSkeleton(width: 100, height: 14, radius: 7),
                      const SizedBox(height: 6),
                      const PremiumSkeleton(width: 60, height: 12, radius: 6),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          PremiumSkeleton(width: 50, height: 18, radius: 9),
                          PremiumSkeleton(width: 32, height: 24, radius: 12),
                        ],
                      ),
                    ],
                  ),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactProductTileSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          const PremiumSkeleton(width: 74, height: 74, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                PremiumSkeleton(width: 180, height: 17, radius: 8),
                SizedBox(height: 7),
                PremiumSkeleton(width: 140, height: 12, radius: 6),
                SizedBox(height: 10),
                PremiumSkeleton(width: 82, height: 18, radius: 9),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const PremiumSkeleton(width: 34, height: 34, radius: 17),
        ],
      ),
    );
  }

  Widget _buildSettingsCardSkeleton(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          const PremiumSkeleton(width: 42, height: 42, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                PremiumSkeleton(width: 150, height: 16, radius: 8),
                SizedBox(height: 6),
                PremiumSkeleton(width: 260, height: 12, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const PremiumSkeleton(width: 22, height: 22, radius: 11),
        ],
      ),
    );
  }

  Widget _buildHistoryItemSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const PremiumSkeleton(width: 56, height: 56, radius: 28),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Expanded(child: PremiumSkeleton(height: 18, radius: 9)),
                    SizedBox(width: 16),
                    PremiumSkeleton(width: 84, height: 18, radius: 9),
                  ],
                ),
                const SizedBox(height: 8),
                const PremiumSkeleton(width: 230, height: 13, radius: 7),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    PremiumSkeleton(width: 120, height: 12, radius: 6),
                    Spacer(),
                    PremiumSkeleton(width: 70, height: 24, radius: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          const PremiumSkeleton(width: 52, height: 52, radius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                PremiumSkeleton(width: 120, height: 16, radius: 8),
                SizedBox(height: 8),
                PremiumSkeleton(width: 180, height: 12, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const PremiumSkeleton(width: 24, height: 24, radius: 12),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(bool isLeft, double width, bool isDark) {
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isLeft
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
              : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0E7FF)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isLeft ? 4 : 16),
            bottomRight: Radius.circular(isLeft ? 16 : 4),
          ),
        ),
        child: const PremiumSkeleton(height: 12, radius: 6),
      ),
    );
  }
}
