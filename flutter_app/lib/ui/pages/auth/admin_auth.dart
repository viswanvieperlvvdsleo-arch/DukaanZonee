import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminAuthPage extends StatefulWidget {
  const AdminAuthPage({super.key});

  @override
  State<AdminAuthPage> createState() => _AdminAuthPageState();
}

class _AdminAuthPageState extends State<AdminAuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await authService.login(
      _emailController.text,
      _passwordController.text,
      role: Role.admin,
    );
    if (!mounted) return;
    if (success) {
      pushRoot(context, const RoleShell(role: Role.admin));
      return;
    }
    setState(() {
      _loading = false;
      _error = 'Unauthorized admin access attempt.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Secure dark blue/black
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildLogin(),
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Column(
      key: const ValueKey('login'),
      children: [
        const Icon(Icons.security, size: 84, color: Colors.blueAccent),
        const SizedBox(height: 32),
        const Text('Admin Terminal', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Authorized Personnel Only', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
        const SizedBox(height: 48),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: _adminInputDecoration('Admin Email Address', Icons.admin_panel_settings),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _adminInputDecoration(
            'System Password',
            Icons.key,
          ).copyWith(
            suffixIcon: IconButton(
              color: Colors.white54,
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
        const SizedBox(height: 48),
        _loading 
          ? const CircularProgressIndicator(color: Colors.blueAccent)
          : SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('AUTHENTICATE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
      ],
    );
  }

  InputDecoration _adminInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .05),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: .1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
    );
  }
}
