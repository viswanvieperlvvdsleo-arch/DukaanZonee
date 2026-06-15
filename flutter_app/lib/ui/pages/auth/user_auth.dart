import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

enum UserAuthStep { login, register, forgotPassword }

class UserAuthPage extends StatefulWidget {
  const UserAuthPage({super.key, this.isRegister = false});
  final bool isRegister;

  @override
  State<UserAuthPage> createState() => _UserAuthPageState();
}

class _UserAuthPageState extends State<UserAuthPage> {
  late UserAuthStep _currentStep;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.isRegister
        ? UserAuthStep.register
        : UserAuthStep.login;
  }

  Future<void> _handleAction() async {
    if (!_validateForm()) return;
    setState(() => _loading = true);

    if (_currentStep == UserAuthStep.register) {
      final success = await authService.register(
        name: _nameController.text,
        email: _emailController.text,
        mobile: _mobileController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (success) {
        pushRoot(context, const RoleShell(role: Role.user));
      } else {
        _showError(
          _authErrorMessage(
            'Could not create account. Check backend and try again.',
          ),
        );
      }
      return;
    }

    final success = await authService.login(
      _emailController.text,
      _passwordController.text,
      role: Role.user,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      pushRoot(context, const RoleShell(role: Role.user));
    } else {
      _showError(_authErrorMessage('Invalid email or password'));
    }
  }

  bool _validateForm() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter a valid email address.');
      return false;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return false;
    }
    if (_currentStep == UserAuthStep.register) {
      if (_nameController.text.trim().length < 2) {
        _showError('Enter your full name.');
        return false;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Passwords do not match.');
        return false;
      }
    }
    return true;
  }

  String _authErrorMessage(String fallback) {
    final service = authService;
    if (service is BackendAuthService && service.lastError != null) {
      return service.lastError!;
    }
    return fallback;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep != UserAuthStep.login
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: ink),
                onPressed: () =>
                    setState(() => _currentStep = UserAuthStep.login),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case UserAuthStep.login:
        return _buildLogin();
      case UserAuthStep.register:
        return _buildRegister();
      case UserAuthStep.forgotPassword:
        return _buildForgotPassword();
    }
  }

  Widget _buildLogin() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(size: 64),
        const SizedBox(height: 32),
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to your neighborhood world.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
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
          obscureText: !_showPassword,
          decoration: _passwordDecoration(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                setState(() => _currentStep = UserAuthStep.forgotPassword),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: primary, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : GradientButton('Login', Icons.login, _handleAction),
        const SizedBox(height: 24),
        SocialButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New here?',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _currentStep = UserAuthStep.register),
              child: const Text(
                'Create Account',
                style: TextStyle(color: primary, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegister() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(size: 64),
        const SizedBox(height: 32),
        const Text(
          'Join DukaanZone',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create your global user account.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
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
          controller: _mobileController,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            prefixIcon: const Icon(Icons.phone_outlined),
            prefixText: '+91 ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: _passwordDecoration(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_showConfirmPassword,
          decoration: _confirmPasswordDecoration(),
        ),
        const SizedBox(height: 32),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : GradientButton('Get Started', Icons.arrow_forward, _handleAction),
        const SizedBox(height: 24),
        SocialButton(
          label: 'Sign up with Google',
          icon: Icons.g_mobiledata,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Column(
      key: const ValueKey('forgot'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_reset_outlined, size: 64, color: primary),
        const SizedBox(height: 24),
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your email to receive a reset link.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 32),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : GradientButton('Send Reset Link', Icons.send_outlined, () async {
                setState(() => _loading = true);
                await Future.delayed(const Duration(seconds: 1));
                if (!mounted) return;
                setState(() {
                  _loading = false;
                  _currentStep = UserAuthStep.login;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reset link sent to your email!'),
                  ),
                );
              }),
      ],
    );
  }

  InputDecoration _passwordDecoration() {
    return InputDecoration(
      labelText: 'Password',
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _showPassword ? 'Hide password' : 'Show password',
        icon: Icon(
          _showPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _showPassword = !_showPassword),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  InputDecoration _confirmPasswordDecoration() {
    return InputDecoration(
      labelText: 'Confirm Password',
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _showConfirmPassword ? 'Hide password' : 'Show password',
        icon: Icon(
          _showConfirmPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
        onPressed: () =>
            setState(() => _showConfirmPassword = !_showConfirmPassword),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
