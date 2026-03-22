import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const String _appVersion = '1.0.0 (build 1)';

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App identity card ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_run,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Running Companion',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $_appVersion',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'By MLE Inc., Calgary, Canada',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ── Contact section ────────────────────────────────
            _sectionLabel('GET IN TOUCH'),
            const SizedBox(height: 10),
            _actionTile(
              context,
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF00796B),
              title: 'Email Support',
              subtitle: 'support@runningcompanion.run',
              onTap: () => _openUrl('mailto:support@runningcompanion.run'),
            ),
            _actionTile(
              context,
              icon: Icons.language,
              iconColor: const Color(0xFF1565C0),
              title: 'Website',
              subtitle: 'runningcompanion.web.app',
              onTap: () => _openUrl('https://runningcompanion.web.app'),
            ),

            const SizedBox(height: 20),

            // ── FAQ section ────────────────────────────────────
            _sectionLabel('FREQUENTLY ASKED QUESTIONS'),
            const SizedBox(height: 10),
            _faq(
              'How do I connect my RunBot robot?',
              'Tap the Bluetooth icon in the top bar. Make sure your RunBot is powered on and within 10 metres. '
                  'The app will scan and connect automatically. If it doesn\'t appear, restart the robot and try again.',
            ),
            _faq(
              'Does the app work without the robot?',
              'Yes! You can use AI coaching, run history, aid station planning, pace workout planning, '
                  'and alert features without connecting a robot. Robot connection is only needed for '
                  'Follow Me and robot control modes.',
            ),
            _faq(
              'How do I cancel my subscription?',
              'Go to Account → Plans & Billing and tap "Cancel Plan". You will retain premium '
                  'access until the end of your current billing period. No partial refunds are issued.',
            ),
            _faq(
              'Is my data backed up?',
              'Yes. All run history and account data is securely backed up to Firebase (Google Cloud). '
                  'Your data is available on any device you sign in to.',
            ),
            _faq(
              'Can I use the app on multiple devices?',
              'Yes. Sign in with the same account on any Android, iOS, Windows, or web device. '
                  'Your run history and settings sync automatically.',
            ),
            _faq(
              'How do I reset my password?',
              'On the sign-in screen, tap "Forgot password?" and enter your email address. '
                  'You will receive a reset link within a few minutes. Check your spam folder if it doesn\'t arrive.',
            ),
            _faq(
              'Is my payment information secure?',
              'All payments are processed by Stripe, Inc., a leading payment processor trusted '
                  'by millions of businesses. We never store your card number — only a Stripe-issued token.',
            ),
            _faq(
              'When will the iOS app be available?',
              'The iOS App Store version is currently in development and will be submitted for review soon. '
                  'In the meantime, iPhone users can access the full web app at runningcompanion.web.app.',
            ),

            const SizedBox(height: 20),

            // ── Legal section ──────────────────────────────────
            _sectionLabel('LEGAL'),
            const SizedBox(height: 10),
            _actionTile(
              context,
              icon: Icons.privacy_tip_outlined,
              iconColor: const Color(0xFF7B1FA2),
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            _actionTile(
              context,
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFF37474F),
              title: 'Terms of Service',
              subtitle: 'Rules for using Running Companion',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
            ),

            const SizedBox(height: 20),

            // ── Footer ─────────────────────────────────────────
            Center(
              child: Text(
                '© 2026 Running Companion — MLE Inc., Calgary, Canada',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF9E9E9E),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _faq(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            color: Color(0xFF00796B),
            size: 18,
          ),
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1A1A2E),
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
