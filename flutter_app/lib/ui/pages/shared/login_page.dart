import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

enum LoginStep { credentials, otp }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialRole = Role.user});
  final Role initialRole;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late Role _selectedRole;
  LoginStep _currentStep = LoginStep.credentials;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  Future<void> _handleCredentials() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await authService.login(
      _emailController.text,
      _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      setState(() => _currentStep = LoginStep.otp);
    } else {
      setState(() => _error = 'Invalid credentials for this role.');
    }
  }

  Future<void> _handleOtp(String code) async {
    setState(() => _loading = true);
    final success = await authService.verifyOtp(code);
    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => RoleShell(role: _selectedRole),
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.0, 0.0, 0.2, 1.0),
            );
            return AnimatedBuilder(
              animation: curved,
              builder: (_, c) => Transform.translate(
                offset: Offset(0, (1.0 - curved.value) * 30.0),
                child: Opacity(opacity: curved.value.clamp(0.0, 1.0), child: c),
              ),
              child: child,
            );
          },
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Try 1234')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentStep == LoginStep.credentials 
                ? _buildCredentials() 
                : _buildOtp(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentials() {
    return Column(
      key: const ValueKey('credentials'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(size: 64),
        const SizedBox(height: 32),
        Text(
          _selectedRole == Role.admin ? 'Admin Access' : 'Welcome Back',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedRole == Role.admin 
            ? 'Restricted to authorized administrators only.' 
            : 'Sign in to your global neighborhood account.',
          style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        
        if (_selectedRole != Role.admin) ...[
          _buildRoleSelector(),
          const SizedBox(height: 24),
        ],

        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        ],

        const SizedBox(height: 32),
        _loading 
          ? const Center(child: CircularProgressIndicator())
          : GradientButton('Continue', Icons.arrow_forward, _handleCredentials),
          
        if (_selectedRole != Role.admin) ...[
          const SizedBox(height: 24),
          const Center(child: Text('OR', style: TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 12))),
          const SizedBox(height: 24),
          SocialButton(label: 'Continue with Google', icon: Icons.g_mobiledata, onTap: () {}),
        ],
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: shadowSm),
      child: Row(
        children: [
          Expanded(
            child: _RoleTab(
              label: 'Shopper',
              icon: Icons.person_outline,
              active: _selectedRole == Role.user,
              onTap: () => setState(() => _selectedRole = Role.user),
            ),
          ),
          Expanded(
            child: _RoleTab(
              label: 'Shopkeeper',
              icon: Icons.storefront,
              active: _selectedRole == Role.seller,
              onTap: () => setState(() => _selectedRole = Role.seller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtp() {
    return Column(
      key: const ValueKey('otp'),
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 84, color: primary),
        const SizedBox(height: 24),
        const Text('Verify your account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 12),
        const Text(
          'We sent a 4-digit code to your mobile.\nEnter 1234 to proceed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 48),
        OtpInput(onCompleted: _handleOtp),
        const SizedBox(height: 48),
        _loading 
          ? const CircularProgressIndicator()
          : TextButton(
              onPressed: () => setState(() => _currentStep = LoginStep.credentials),
              child: const Text('Change Details', style: TextStyle(color: muted, fontWeight: FontWeight.w800)),
            ),
      ],
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.white : muted, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: active ? Colors.white : ink, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
