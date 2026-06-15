import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AppPage extends StatefulWidget {
  const AppPage({super.key, required this.children, this.maxWidth = 980});
  final List<Widget> children;
  final double maxWidth;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Cap stagger at 8 slots = max 280ms delay, keeping FPS high.
                    // GPU path: Transform.translate + Opacity only (no layout changes).
                    final cappedIndex = index.clamp(0, 8);
                    final staggeredAnim = CurvedAnimation(
                      parent: _ctrl,
                      curve: Interval(
                        (cappedIndex * 35 / 420).clamp(0.0, 0.85),
                        1.0,
                        curve: const Cubic(0.0, 0.0, 0.2, 1.0),
                      ),
                    );
                    return AnimatedBuilder(
                      animation: staggeredAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (1.0 - staggeredAnim.value) * 18.0),
                        child: Opacity(opacity: staggeredAnim.value, child: child),
                      ),
                      child: widget.children[index],
                    );
                  },
                  childCount: widget.children.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: ink, letterSpacing: -.6)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted, fontWeight: FontWeight.w700))]);
}
