import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

/// Premium splash screen:
/// 1. Logo fades + scales in to center (large)
/// 2. Logo shrinks and flies to the top-left corner
/// 3. Routes to EntryPage
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Exit: shrink + move to top-left
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;
  late final Animation<Alignment> _alignment;

  @override
  void initState() {
    super.initState();

    // Phase 1 – fade in (0 → 600ms)
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoScale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack));
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));

    // Phase 2 – shrink + glide (800ms after enter)
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _exitScale = Tween<double>(
      begin: 1.0,
      end: 0.42,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );
    _alignment = AlignmentTween(
      begin: Alignment.center,
      end: const Alignment(-0.92, -0.94),
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOutCubic));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _enterCtrl.forward();
    final restored = await authService.restoreSession();
    await Future.delayed(const Duration(milliseconds: 900));
    await _exitCtrl.forward();
    if (mounted) {
      final restoredRole = authService.currentRole.value;
      final nextPage = restored && restoredRole != null
          ? RoleShell(role: restoredRole)
          : const EntryPage();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextPage,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      body: AnimatedBuilder(
        animation: Listenable.merge([_enterCtrl, _exitCtrl]),
        builder: (context, _) {
          return Stack(
            children: [
              // Subtle radial gradient backdrop
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        primary.withOpacity(isDark ? 0.12 : 0.07),
                        isDark ? bgDark : bgLight,
                      ],
                    ),
                  ),
                ),
              ),
              // Logo in its animated position
              Align(
                alignment: _alignment.value,
                child: Opacity(
                  opacity: _logoOpacity.value * _exitOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value * _exitScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandLockup(markSize: 70),
                        const SizedBox(height: 18),
                        // Only show tagline while in center phase.
                        if (_exitCtrl.value < 0.15)
                          Opacity(
                            opacity: (1.0 - _exitCtrl.value / 0.15).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Text(
                              'Connecting the world through\nlocal shopkeepers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: muted,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
