import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;
  bool _success = false;
  String? _errorMessage;
  String? _emailForCode;
  int _countdown = 4;
  Timer? _redirectTimer;

  // ── requirement flags ───────────────────────────────────────────────────
  bool get _hasLength => _passwordCtrl.text.length >= 8;
  bool get _hasUpper => _passwordCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => _passwordCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _passwordCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _passwordCtrl.text.contains(
    RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]'),
  );
  bool get _allMet =>
      _hasLength && _hasUpper && _hasLower && _hasDigit && _hasSpecial;

  @override
  void initState() {
    super.initState();
    _verifyCode();
    _passwordCtrl.addListener(() => setState(() {}));
  }

  void _startRedirectTimer() {
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (r) => r.isFirst);
        } else {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    });
  }

  Future<void> _verifyCode() async {
    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(
        widget.oobCode,
      );
      if (mounted) setState(() => _emailForCode = email);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.code == 'expired-action-code'
              ? 'This reset link has expired. Please request a new one.'
              : 'This reset link is invalid or has already been used.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allMet) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _passwordCtrl.text,
      );
      if (mounted) {
        setState(() => _success = true);
        _startRedirectTimer();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.code == 'expired-action-code'
            ? 'This reset link has expired. Please request a new one.'
            : e.code == 'weak-password'
            ? 'Password is too weak. Please meet all requirements.'
            : 'An error occurred: ${e.message}';
      });
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────
  Widget _reqRow(bool met, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: met ? const Color(0xFF00796B) : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: met ? const Color(0xFF00695C) : Colors.grey.shade600,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 40,
                ),
                child: _success ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── success state ────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_open_rounded,
            size: 38,
            color: Color(0xFF00796B),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Password Updated!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your password has been successfully reset. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        // ── countdown indicator ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _countdown / 4.0,
                  strokeWidth: 2.5,
                  color: const Color(0xFF00796B),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Redirecting to sign in in $_countdown second${_countdown == 1 ? '' : 's'}...',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF00695C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              _redirectTimer?.cancel();
              if (Navigator.canPop(context)) {
                Navigator.popUntil(context, (r) => r.isFirst);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            child: const Text(
              'Go to Sign In now',
              style: TextStyle(color: Color(0xFF00796B), fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── form state ────────────────────────────────────────────────────────────
  Widget _buildForm() {
    // Invalid / expired code
    if (_errorMessage != null && _emailForCode == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 20),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(color: Color(0xFF00796B)),
            ),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── header ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFF00796B),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          if (_emailForCode != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'for $_emailForCode',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // ── new password ─────────────────────────────────────────────
          const Text(
            'New Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              hintText: 'Enter a strong password',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF00796B),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (!_allMet) return 'Password does not meet all requirements';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── requirements box ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password Requirements',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _reqRow(_hasLength, 'At least 8 characters'),
                _reqRow(_hasUpper, 'One uppercase letter (A–Z)'),
                _reqRow(_hasLower, 'One lowercase letter (a–z)'),
                _reqRow(_hasDigit, 'One number (0–9)'),
                _reqRow(_hasSpecial, 'One special character (!@#\$%^&*)'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── confirm password ─────────────────────────────────────────
          const Text(
            'Confirm New Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF00796B),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 10),

          // ── server error ─────────────────────────────────────────────
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── submit ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _allMet
                    ? const Color(0xFF00796B)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: _allMet ? 2 : 0,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Set New Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              child: const Text(
                'Back to Sign In',
                style: TextStyle(color: Color(0xFF00796B), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
