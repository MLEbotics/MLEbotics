import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../utils/download_helper.dart';
import '../widgets/evening_river_scene.dart';
import 'ios_coming_soon_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

const _kStaySignedInKey = 'stay_signed_in';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  GlobalKey<FormState> get _activeFormKey =>
      _isLogin ? _loginFormKey : _signupFormKey;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _staySignedIn = true;
  String? _errorMessage;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadStaySignedIn();
    // Check if already signed in
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _loadStaySignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _staySignedIn = prefs.getBool(_kStaySignedInKey) ?? true;
    });
  }

  Future<void> _forgotPassword(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email address above first.'),
          backgroundColor: Color(0xFF00796B),
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _submitGoogle(BuildContext context) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final cred = await _authService.signInWithGoogle();
      if (!mounted || cred == null) return;
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/app');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google sign-in failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(BuildContext context) async {
    if (!_activeFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      if (_isLogin) {
        await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        final cred = await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text,
        );
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        final fullName = [
          firstName,
          lastName,
        ].where((s) => s.isNotEmpty).join(' ');
        if (fullName.isNotEmpty) {
          await cred.user?.updateDisplayName(fullName);
        }
      }
      // Persist the stay-signed-in preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStaySignedInKey, _staySignedIn);
      // Navigate to the app — home screen stays at '/' for all visitors
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/app');
        return;
      }
    } catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('invalid-credential') || raw.contains('wrong-password')) {
      return 'Incorrect email or password.';
    } else if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    } else if (raw.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    } else if (raw.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sign-up: simple, full-screen, always works
    if (!_isLogin) return _signUpPage(context);

    // Sign-in: beautiful split-panel layout
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: EveningRiverScene()),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xCC02030A),
                    Color(0xB30A0B12),
                    Color(0xCC0A0B11),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: isWide ? _wideLayout(context) : _narrowLayout(context),
          ),
        ],
      ),
    );
  }

  // ── Sign-up page ──────────────────────────────────────────────
  Widget _signUpPage(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: EveningRiverScene()),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xCC02030A),
                    Color(0xB30A0B12),
                    Color(0xCC0A0B11),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F141B),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF121D2A),
                                Color(0xFF331A2A),
                                Color(0xFF7A2A10),
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _logoWidget(size: 26),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Running Companion',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your robot running buddy 🤖🏃',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Paces you, follows you, and carries your gear\n'
                                'in a sleek enclosed box built for long runs.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _statPill(Icons.gps_fixed, 'GPS pacing'),
                                  _statPill(
                                    Icons.directions_run,
                                    'Follows you',
                                  ),
                                  _statPill(Icons.water_drop, 'Hydration'),
                                  _statPill(Icons.bolt, 'Energy gels'),
                                  _statPill(Icons.smart_toy, 'RunBot AI'),
                                  _statPill(Icons.history, 'Run history'),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Form ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                          child: Form(
                            key: _signupFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel(
                                  'WHO ARE YOU?',
                                  const Color(0xFF00D6A2),
                                ),
                                const SizedBox(height: 10),

                                // First + Last name row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _colorField(
                                        controller: _firstNameController,
                                        label: 'First name',
                                        icon: Icons.person_outline,
                                        color: const Color(0xFF00D6A2),
                                        keyboardType: TextInputType.name,
                                        caps: TextCapitalization.words,
                                        dark: true,
                                        validator:
                                            (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _colorField(
                                        controller: _lastNameController,
                                        label: 'Last name',
                                        icon: Icons.badge_outlined,
                                        color: const Color(0xFF3AA7FF),
                                        keyboardType: TextInputType.name,
                                        caps: TextCapitalization.words,
                                        dark: true,
                                        validator:
                                            (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                _sectionLabel(
                                  'CONTACT',
                                  const Color(0xFF3AA7FF),
                                ),
                                const SizedBox(height: 10),

                                _colorField(
                                  controller: _emailController,
                                  label: 'Email address',
                                  icon: Icons.email_outlined,
                                  color: const Color(0xFF3AA7FF),
                                  keyboardType: TextInputType.emailAddress,
                                  dark: true,
                                  validator:
                                      (v) =>
                                          (v == null || !v.contains('@'))
                                              ? 'Enter a valid email'
                                              : null,
                                ),
                                const SizedBox(height: 20),

                                _sectionLabel(
                                  'SECURITY',
                                  const Color(0xFFFF9F5A),
                                ),
                                const SizedBox(height: 10),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: _fieldDecoration(
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    color: const Color(0xFFFF9F5A),
                                    dark: true,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFFFF9F5A),
                                      ),
                                      onPressed:
                                          () => setState(
                                            () =>
                                                _obscurePassword =
                                                    !_obscurePassword,
                                          ),
                                    ),
                                  ),
                                  validator:
                                      (v) =>
                                          (v == null || v.length < 6)
                                              ? 'Min. 6 characters'
                                              : null,
                                ),
                                const SizedBox(height: 14),

                                // Confirm Password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  decoration: _fieldDecoration(
                                    label: 'Confirm password',
                                    icon: Icons.lock_person_outlined,
                                    color: const Color(0xFFB177FF),
                                    dark: true,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFFB177FF),
                                      ),
                                      onPressed:
                                          () => setState(
                                            () =>
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword,
                                          ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (v != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),

                                // Error box
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.redAccent.withOpacity(
                                          0.4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 28),

                                // Gradient Create Account button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF004D40),
                                          Color(0xFF00897B),
                                          Color(0xFF26C6DA),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF00796B,
                                          ).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed:
                                          _loading
                                              ? null
                                              : () => _submit(context),
                                      child:
                                          _loading
                                              ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                              : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.rocket_launch_rounded,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Create Account',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Back to Sign In
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Back to Sign In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () {
                                      _emailController.clear();
                                      _passwordController.clear();
                                      _confirmPasswordController.clear();
                                      setState(() {
                                        _isLogin = true;
                                        _errorMessage = null;
                                        _obscurePassword = true;
                                        _obscureConfirmPassword = true;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap:
                                                () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            const PrivacyPolicyScreen(),
                                                  ),
                                                ),
                                            child: const Text(
                                              'Privacy Policy',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '  |  ',
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap:
                                                () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            const TermsScreen(),
                                                  ),
                                                ),
                                            child: const Text(
                                              'Terms of Service',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '© 2026 Running Companion — MLE Inc., Calgary, Canada',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _colorField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none,
    String? Function(String?)? validator,
    bool dark = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: caps,
      style: TextStyle(color: dark ? Colors.white : const Color(0xFF0F141B)),
      decoration: _fieldDecoration(
        label: label,
        icon: icon,
        color: color,
        dark: dark,
      ),
      validator: validator,
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required Color color,
    Widget? suffix,
    bool dark = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: dark ? Colors.white70 : color.withOpacity(0.8),
      ),
      prefixIcon: Icon(icon, color: dark ? Colors.white70 : color),
      suffixIcon: suffix,
      filled: true,
      fillColor: dark ? const Color(0xFF0F141B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? Colors.white24 : color.withOpacity(0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? Colors.white24 : color.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Colors.white70 : color, width: 2),
      ),
    );
  }

  // ── Wide layout (desktop / web) ─────────────────────────────────
  Widget _wideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x660B0F14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _logoWidget(size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Running\nCompanion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A robot that runs with you.\nSet your pace. Follow the leader.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 17,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'FREE DOWNLOAD',
                      style: TextStyle(
                        color: Color(0xFF80CBC4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _bigDownloadButton(
                          icon: Icons.android_rounded,
                          label: 'Android APK',
                          url:
                              'https://storage.googleapis.com/running-companion-a935f.firebasestorage.app/public/downloads/runner_companion.apk',
                          color: const Color(0xFF66BB6A),
                          isFileDownload: true,
                        ),
                        _bigDownloadButton(
                          icon: Icons.apple_rounded,
                          label: 'iOS App',
                          url: 'https://runningcompanion.web.app/download',
                          color: const Color(0xFF90CAF9),
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const IosComingSoonScreen(),
                                ),
                              ),
                        ),
                        _bigDownloadButton(
                          icon: Icons.language_rounded,
                          label: 'Web App',
                          url: 'https://runningcompanion.web.app',
                          color: const Color(0xFF80CBC4),
                          onTap: () => Navigator.pushNamed(context, '/app'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _statPill(Icons.gps_fixed, 'GPS Pacing'),
                        _statPill(Icons.speed, 'Smart Pace'),
                        _statPill(Icons.sensors, 'Obstacle Avoidance'),
                        _statPill(Icons.history, 'Run History'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 420,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCC0F141B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 32,
                ),
                child:
                    _currentUser != null
                        ? _signedInPanel(context, dark: true)
                        : _loginForm(context, dark: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout (mobile) ──────────────────────────────────────
  Widget _narrowLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x660B0F14),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _logoWidget(size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'Running\nCompanion',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      height: 1.05,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'A robot that runs with you.\nSet your pace. Follow the leader.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'FREE DOWNLOAD',
                    style: TextStyle(
                      color: Color(0xFF80CBC4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _bigDownloadButton(
                    icon: Icons.android_rounded,
                    label: 'Android APK',
                    url:
                        'https://storage.googleapis.com/running-companion-a935f.firebasestorage.app/public/downloads/runner_companion.apk',
                    color: const Color(0xFF66BB6A),
                    isFileDownload: true,
                  ),
                  const SizedBox(height: 10),
                  _bigDownloadButton(
                    icon: Icons.apple_rounded,
                    label: 'iOS App',
                    url: 'https://runningcompanion.web.app/download',
                    color: const Color(0xFF90CAF9),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IosComingSoonScreen(),
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  _bigDownloadButton(
                    icon: Icons.language_rounded,
                    label: 'Web App',
                    url: 'https://runningcompanion.web.app',
                    color: const Color(0xFF80CBC4),
                    onTap: () => Navigator.pushNamed(context, '/app'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xCC0F141B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child:
                _currentUser != null
                    ? _signedInPanel(context, dark: true)
                    : _loginForm(context, dark: true),
          ),
        ],
      ),
    );
  }

  // ── Already signed-in panel ─────────────────────────────────────
  Widget _signedInPanel(BuildContext context, {required bool dark}) {
    final user = _currentUser!;
    final displayName =
        user.displayName?.isNotEmpty == true
            ? user.displayName!
            : user.email ?? 'there';
    final initials =
        displayName.trim().isNotEmpty
            ? displayName.trim()[0].toUpperCase()
            : '?';
    final panelAccent =
        dark ? const Color(0xFF00D6A2) : const Color(0xFF00796B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + greeting
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: panelAccent,
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child:
                  user.photoURL == null
                      ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Go to App button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/app'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text(
              'Go to App',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: panelAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              setState(() => _currentUser = null);
            },
            icon: const Icon(Icons.logout, size: 16, color: Colors.white54),
            label: Text(
              'Sign out',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero panel ──────────────────────────────────────────────────
  Widget _bigDownloadButton({
    required IconData icon,
    required String label,
    required String url,
    required Color color,
    bool isFileDownload = false,
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap:
            onTap ??
            (isFileDownload
                ? () => triggerDownload(url, label)
                : () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                  webOnlyWindowName: '_blank',
                )),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.7), width: 1.8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoWidget({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      child: Icon(Icons.directions_run, color: Colors.white, size: size * 0.55),
    );
  }

  // ── Login / signup form ─────────────────────────────────────────
  Widget _loginForm(BuildContext context, {required bool dark}) {
    final accent = dark ? const Color(0xFF00D6A2) : const Color(0xFF00796B);
    final textPrimary = dark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = dark ? Colors.white70 : Colors.grey.shade600;
    final borderColor = dark ? Colors.white24 : Colors.grey.shade300;
    final fillColor = dark ? const Color(0xFF0F141B) : Colors.grey.shade50;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _isLogin ? 'Welcome back 👋' : 'Create account 🏃',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isLogin
                ? 'Sign in to your Running Companion account'
                : 'Join thousands of runners using the app',
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 32),
          // Separate keys force a full form rebuild when switching modes
          Form(
            key: _activeFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Email ──────────────────────────────────────────
                _inputField(
                  controller: _emailController,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  dark: dark,
                  validator:
                      (v) =>
                          (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                ),
                const SizedBox(height: 16),

                // ── Password ────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.lock_outline, color: accent),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: accent,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent, width: 2),
                    ),
                    filled: true,
                    fillColor: fillColor,
                  ),
                  validator:
                      (v) =>
                          (v == null || v.length < 6)
                              ? 'Min. 6 characters'
                              : null,
                ),

                // ── Forgot password (login only) ────────────────────
                if (_isLogin) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _forgotPassword(context),
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Confirm Password (sign-up only) ─────────────────
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('confirm_password'),
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      hintText: 'Re-enter your password',
                      labelStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(
                        Icons.lock_person_outlined,
                        color: accent,
                      ),
                      suffixIcon: IconButton(
                        tooltip:
                            _obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: accent,
                        ),
                        onPressed:
                            () => setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent, width: 2),
                      ),
                      filled: true,
                      fillColor: fillColor,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],

                // ── Error message ───────────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          dark
                              ? Colors.red.withOpacity(0.12)
                              : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            dark
                                ? Colors.redAccent.withOpacity(0.4)
                                : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: dark ? Colors.redAccent : Colors.red.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color:
                                  dark ? Colors.redAccent : Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Stay signed in ──────────────────────────────────
                if (_isLogin)
                  InkWell(
                    onTap: () => setState(() => _staySignedIn = !_staySignedIn),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _staySignedIn,
                          activeColor: accent,
                          onChanged:
                              (v) => setState(() => _staySignedIn = v ?? true),
                        ),
                        Text(
                          'Stay signed in',
                          style: TextStyle(
                            fontSize: 14,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message:
                              'When checked, you only need to log in once. '
                              'Anyone who unlocks the phone can use the app.',
                          child: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: dark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Submit button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : () => _submit(context),
                    child:
                        _loading
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Text(
                              _isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Divider ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: dark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: dark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: dark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Continue with Google ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          dark ? Colors.white : const Color(0xFF3C3C3C),
                      side: BorderSide(
                        color: dark ? Colors.white24 : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      backgroundColor:
                          dark ? const Color(0xFF121820) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : () => _submitGoogle(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google "G" logo using coloured spans
                        const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sign in with Google Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Toggle sign in / sign up ────────────────────────
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dark ? Colors.white70 : accent,
                    side: BorderSide(color: dark ? Colors.white24 : accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: () {
                    _emailController.clear();
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                      _obscurePassword = true;
                      _obscureConfirmPassword = true;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? "Don't have an account?  Sign up →"
                        : '← Back to Sign In',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: dark ? Colors.white70 : Colors.teal.shade300,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '  |  ',
                      style: TextStyle(
                        color: dark ? Colors.white38 : Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsScreen(),
                            ),
                          ),
                      child: Text(
                        'Terms of Service',
                        style: TextStyle(
                          color: dark ? Colors.white70 : Colors.teal.shade300,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 Running Companion — MLE Inc., Calgary, Canada',
                  style: TextStyle(
                    color: dark ? Colors.white38 : Colors.grey.shade400,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool dark = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: dark ? Colors.white : const Color(0xFF0F141B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: dark ? Colors.white70 : Colors.grey.shade700,
        ),
        prefixIcon: Icon(
          icon,
          color: dark ? const Color(0xFF00D6A2) : const Color(0xFF00796B),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF00D6A2) : const Color(0xFF00796B),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: dark ? const Color(0xFF0F141B) : Colors.grey.shade50,
      ),
      validator: validator,
    );
  }
}
