import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shown when the user taps the iOS download button.
/// Collects email for iOS early access notification.
class IosComingSoonScreen extends StatefulWidget {
  const IosComingSoonScreen({super.key});

  @override
  State<IosComingSoonScreen> createState() => _IosComingSoonScreenState();
}

class _IosComingSoonScreenState extends State<IosComingSoonScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _joinWaitlist() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('ios_waitlist').add({
        'email': _emailController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'ios_waitlist',
      });
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Back button ──────────────────────────────────
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
                  child: Column(
                    children: [
                      // Apple icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.apple_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Coming soon badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.6),
                          ),
                        ),
                        child: const Text(
                          '🚀  COMING SOON TO APP STORE',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Running Companion\nfor iOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'The iOS App Store version is currently in beta testing '
                        'and will be submitted for review soon.\n\n'
                        'In the meantime, iPhone users can access the full '
                        'Running Companion web app — no download required.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // What to expect pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _pill(Icons.directions_run, 'Robot Control'),
                          _pill(Icons.speed, 'Pace Workouts'),
                          _pill(Icons.smart_toy, 'RunBot AI'),
                          _pill(Icons.inventory_2, 'Aid Station'),
                          _pill(Icons.campaign, 'Alert Ahead'),
                          _pill(Icons.history, 'Run History'),
                        ],
                      ),
                      const SizedBox(height: 36),

                      if (!_submitted) ...[
                        // ── Waitlist form ────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Get notified when it launches',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Be first in line — we\'ll email you the day it goes live.',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'your@email.com',
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                      color: Colors.white60,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white30,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white30,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white70,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                      ? 'Enter a valid email'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0F3460),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _loading ? null : _joinWaitlist,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Color(0xFF0F3460),
                                            ),
                                          )
                                        : const Text(
                                            'Notify Me  →',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // ── Success state ────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.4),
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                "You're on the list! 🎉",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "We'll email you the moment the iOS app launches on the App Store.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Use web app instead button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/app'),
                        icon: const Icon(Icons.language_rounded, size: 18),
                        label: const Text(
                          'Use the Web App Instead',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
