import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await soundService.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const DukaanZoneApp());
}

class DukaanZoneApp extends StatelessWidget {
  const DukaanZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'DukaanZone',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          scrollBehavior: const _SmoothScrollBehavior(),
          home: const SplashPage(),
        );
      },
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.iOS;
}
