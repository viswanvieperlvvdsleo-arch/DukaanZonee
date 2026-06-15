import 'package:flutter/material.dart';

const primary = Color(0xFF5D83B4);
const ink = Color(0xFF172033);
const muted = Color(0xFF8A94A6);
const success = Color(0xFF059669);
const bgLight = Color(0xFFF9FAFB);
const bgDark = Color(0xFF0B0F19);
const bg = bgLight;

final navGradient = const LinearGradient(
  colors: [primary, Color(0xFF404040)], 
  begin: Alignment.topLeft, 
  end: Alignment.bottomRight
);

final neonGlow = [
  BoxShadow(
    color: primary.withOpacity(0.3),
    blurRadius: 20,
    spreadRadius: 2,
  )
];

final shadowSm = [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))];
final shadowLg = [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 20, offset: const Offset(0, 12))];

/// OxygenOS-style GPU-only page transition.
/// translate-Y + opacity only. No layout changes. Buttery smooth.
class _PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.0, 0.0, 0.2, 1.0),
      reverseCurve: const Cubic(0.4, 0.0, 1.0, 1.0),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (1.0 - curved.value) * 20.0),
        child: Opacity(opacity: curved.value.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

const _premiumTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _PremiumPageTransitionsBuilder(),
    TargetPlatform.iOS: _PremiumPageTransitionsBuilder(),
    TargetPlatform.linux: _PremiumPageTransitionsBuilder(),
    TargetPlatform.macOS: _PremiumPageTransitionsBuilder(),
    TargetPlatform.windows: _PremiumPageTransitionsBuilder(),
  },
);

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgLight,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
    ),
    pageTransitionsTheme: _premiumTransitions,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark, background: bgDark),
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1F2B),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
    ),
    pageTransitionsTheme: _premiumTransitions,
  );
}
