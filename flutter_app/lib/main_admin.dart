import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Admin is dark themed
  ));
  runApp(const DukaanZoneAdminApp());
}

class DukaanZoneAdminApp extends StatelessWidget {
  const DukaanZoneAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'DukaanZone Admin Command',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode, // Dynamic theme mode!
          scrollBehavior: const _SmoothScrollBehavior(),
          home: const AdminBootstrapPage(),
        );
      },
    );
  }
}

class AdminBootstrapPage extends StatefulWidget {
  const AdminBootstrapPage({super.key});

  @override
  State<AdminBootstrapPage> createState() => _AdminBootstrapPageState();
}

class _AdminBootstrapPageState extends State<AdminBootstrapPage> {
  @override
  void initState() {
    super.initState();
    _restoreAdmin();
  }

  Future<void> _restoreAdmin() async {
    final restored = await authService.restoreSession();
    if (!mounted) return;
    final role = authService.currentRole.value;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => restored && role == Role.admin
            ? const RoleShell(role: Role.admin)
            : const AdminAuthPage(),
        transitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
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
