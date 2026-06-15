import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

enum RegisterStep { details, otp, scan, personalize }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  RegisterStep _currentStep = RegisterStep.details;
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isSeller = false;
  bool _loading = false;
  String? _profilePic;

  Future<void> _handleDetails() async {
    setState(() => _loading = true);
    // Simulate initial check
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _currentStep = RegisterStep.otp;
    });
  }

  Future<void> _handleOtp(String code) async {
    setState(() => _loading = true);
    final success = await authService.verifyOtp(code);
    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      if (_isSeller) {
        setState(() => _currentStep = RegisterStep.scan);
      } else {
        setState(() => _currentStep = RegisterStep.personalize);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Try 1234')),
      );
    }
  }

  void _completeRegistration() {
    authService.register(
      name: _nameController.text,
      email: _emailController.text,
      mobile: _mobileController.text,
      password: _passwordController.text,
      isSeller: _isSeller,
    );
    pushRoot(context, RoleShell(role: _isSeller ? Role.seller : Role.user));
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
              child: _buildCurrentStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case RegisterStep.details:
        return _buildDetails();
      case RegisterStep.otp:
        return _buildOtp();
      case RegisterStep.scan:
        return _buildScanner();
      case RegisterStep.personalize:
        return _buildPersonalize();
    }
  }

  Widget _buildDetails() {
    return Column(
      key: const ValueKey('details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(size: 64),
        const SizedBox(height: 32),
        const Text('Join the Network', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 8),
        const Text('Create your global neighborhood account.', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 32),
        
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _mobileController,
          decoration: InputDecoration(labelText: 'Mobile Number', prefixIcon: const Icon(Icons.phone_outlined), prefixText: '+91 ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        const SizedBox(height: 20),
        
        SwitchListTile(
          title: const Text('I am a Shopkeeper', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
          subtitle: const Text('Register to list products globally.', style: TextStyle(fontWeight: FontWeight.w600)),
          value: _isSeller,
          onChanged: (v) => setState(() => _isSeller = v),
          activeColor: primary,
          contentPadding: EdgeInsets.zero,
        ),
        
        const SizedBox(height: 32),
        _loading 
          ? const Center(child: CircularProgressIndicator())
          : GradientButton('Sign Up', Icons.how_to_reg, _handleDetails),
          
        const SizedBox(height: 24),
        SocialButton(label: 'Register with Google', icon: Icons.g_mobiledata, onTap: () {}),
      ],
    );
  }

  Widget _buildOtp() {
    return Column(
      key: const ValueKey('otp'),
      children: [
        const Icon(Icons.sms_outlined, size: 84, color: primary),
        const SizedBox(height: 24),
        const Text('Verify Phone', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 12),
        Text(
          'We sent a code to +91 ${_mobileController.text}.\nEnter 1234.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 48),
        OtpInput(onCompleted: _handleOtp),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildScanner() {
    return Column(
      key: const ValueKey('scan'),
      children: [
        const Icon(Icons.qr_code_scanner, size: 84, color: primary),
        const SizedBox(height: 24),
        const Text('Sync your Shop', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 12),
        const Text(
          'Scan your DukaanZone Store QR to link your inventory.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 48),
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(32)),
          child: const Center(child: Icon(Icons.camera_alt, color: Colors.white24, size: 64)),
        ),
        const SizedBox(height: 32),
        GradientButton('Simulate QR Sync', Icons.sync, () => setState(() => _currentStep = RegisterStep.personalize)),
      ],
    );
  }

  Widget _buildPersonalize() {
    return Column(
      key: const ValueKey('personalize'),
      children: [
        const Text('You\'re in!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 8),
        const Text('Personalize your neighborhood profile.', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 48),
        ProfilePicPicker(
          imageUrl: _profilePic,
          onTap: () => setState(() => _profilePic = 'https://i.pravatar.cc/150?u=aryan'),
        ),
        const SizedBox(height: 48),
        GradientButton('Complete Setup', Icons.check, _completeRegistration),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _completeRegistration,
          child: const Text('Skip for now', style: TextStyle(color: muted, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
