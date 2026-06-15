import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// OxygenOS-inspired cubic-bezier easing constants
// cubic-bezier(0.4, 0, 0.2, 1) = Material standard
// cubic-bezier(0.0, 0.0, 0.2, 1) = Decelerate (enter)
// cubic-bezier(0.4, 0.0, 1.0, 1) = Accelerate (exit)
// ─────────────────────────────────────────────────────────────

const _kEnterCurve = Cubic(0.0, 0.0, 0.2, 1.0);
const _kExitCurve  = Cubic(0.4, 0.0, 1.0, 1.0);
const _kStandardCurve = Cubic(0.4, 0.0, 0.2, 1.0);

const kPageEnterDuration  = Duration(milliseconds: 320);
const kPageExitDuration   = Duration(milliseconds: 240);
const kTapDuration        = Duration(milliseconds: 90);
const kSpringDuration     = Duration(milliseconds: 350);

// ─────────────────────────────────────────────────────────────
// TapScale — Immediate scale-down on press, spring back on release
// GPU-only: uses Transform.scale, no layout changes.
// ─────────────────────────────────────────────────────────────
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kTapDuration);
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: _kStandardCurve),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FadeSlideIn — Single-element entrance animation
// GPU-only: translate + opacity. No height/width changes.
// ─────────────────────────────────────────────────────────────
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = kPageEnterDuration,
    this.offsetY = 20.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: _kEnterCurve);
    _slide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: _kEnterCurve),
    );
    
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        // GPU-accelerated translate. No layout thrashing.
        offset: Offset(0, _slide.value * widget.offsetY),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StaggerGroup — Wraps children and staggers their entrance.
// Each child gets a FadeSlideIn with an increasing delay.
// ─────────────────────────────────────────────────────────────
class StaggerGroup extends StatelessWidget {
  const StaggerGroup({
    super.key,
    required this.children,
    this.staggerMs = 55,
    this.initialDelayMs = 0,
  });

  final List<Widget> children;
  final int staggerMs;
  final int initialDelayMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(children.length, (i) {
        return FadeSlideIn(
          delay: Duration(milliseconds: initialDelayMs + i * staggerMs),
          child: children[i],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ShimmerBox — GPU-accelerated shimmer placeholder
// Uses a gradient + translate animation. Zero layout cost.
// ─────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width = double.infinity, this.height = 20, this.radius = 12});
  final double width;
  final double height;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _ctrl.value * 3, 0),
              end: Alignment(1.0 + _ctrl.value * 3, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF8F8F8),
                Color(0xFFEEEEEE),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AnimatedCounter — Smooth number roll-up animation
// ─────────────────────────────────────────────────────────────
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
  });

  final double value;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: _kEnterCurve,
      builder: (_, v, __) => Text(
        '$prefix${v.toStringAsFixed(0)}',
        style: style,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PressableSurface — Card-level press with shadow depth change
// GPU-only: scale + shadow opacity. No position changes.
// ─────────────────────────────────────────────────────────────
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 24.0,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _ctrl, curve: _kStandardCurve));
    _shadow = Tween<double>(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: _kStandardCurve));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
