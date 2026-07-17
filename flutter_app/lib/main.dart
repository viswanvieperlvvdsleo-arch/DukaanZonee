import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/ui/pages/shared/call_screen.dart';

import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init failed (expected if web/desktop without options): $e');
  }
  await soundService.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const DukaanZoneApp());
}

class DukaanZoneApp extends StatefulWidget {
  const DukaanZoneApp({super.key});

  @override
  State<DukaanZoneApp> createState() => _DukaanZoneAppState();
}

class _DukaanZoneAppState extends State<DukaanZoneApp> {
  @override
  void initState() {
    super.initState();
    // Start the global call manager so incoming calls are intercepted app-wide
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalCallManager.instance.init();
    });
  }

  @override
  void dispose() {
    GlobalCallManager.instance.dispose();
    super.dispose();
  }

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
          navigatorKey: navigatorKey,
          home: const SplashPage(),
        );
      },
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.iOS;
}
