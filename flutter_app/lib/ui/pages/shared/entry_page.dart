import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  bool _simulatedLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate premium loading phase if the user is already logged in
    if (authService.isLoggedIn.value) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _simulatedLoading = false;
          });
        }
      });
    } else {
      _simulatedLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: authService.isLoggedIn,
      builder: (context, isLoggedIn, child) {
        Widget body;
        if (isLoggedIn) {
          if (_simulatedLoading) {
            body = const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Spacer(),
                  Center(child: PremiumSkeleton(width: 84, height: 84, radius: 42)),
                  SizedBox(height: 20),
                  Center(child: PremiumSkeleton(width: 220, height: 28)),
                  SizedBox(height: 32),
                  PremiumSkeleton(height: 58, radius: 28),
                  SizedBox(height: 14),
                  PremiumSkeleton(height: 58, radius: 28),
                  Spacer(),
                  Center(child: PremiumSkeleton(width: 80, height: 16)),
                ],
              ),
            );
          } else {
            body = _buildRoleSelection(context);
          }
        } else {
          body = _buildLanding(context);
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: body,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanding(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const Brand(size: 96),
        const SizedBox(height: 26),
        const Text('DukaanZone', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: ink, letterSpacing: -.5)),
        const SizedBox(height: 8),
        const Text(
          'Connecting the world through local shopkeepers.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.45, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        GradientButton('Shop with Us', Icons.person_outline, () => push(context, const UserAuthPage())),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => push(context, const SellerAuthPage()),
          icon: const Icon(Icons.storefront),
          label: const Text('Partner with Us', style: TextStyle(fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            foregroundColor: primary,
            side: const BorderSide(color: Color(0x33628ECB), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelection(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const Brand(size: 84),
        const SizedBox(height: 20),
        const Text('Choose your journey', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 32),
        GradientButton('Shop as User', Icons.storefront, () => pushRoot(context, const RoleShell(role: Role.user))),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => pushRoot(context, const RoleShell(role: Role.seller)),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Continue as Seller', style: TextStyle(fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            foregroundColor: primary,
            side: const BorderSide(color: Color(0x33628ECB), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            authService.logout();
            pushRoot(context, const EntryPage());
          },
          child: const Text('SIGN OUT', style: TextStyle(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: muted)),
        ),
      ],
    );
  }
}
