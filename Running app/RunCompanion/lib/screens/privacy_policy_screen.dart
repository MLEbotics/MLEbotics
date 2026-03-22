import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card([
              _heading('Privacy Policy'),
              _sub('Effective date: January 1, 2026'),
              const SizedBox(height: 8),
              _body(
                'MLE Inc. ("we", "us", or "our") operates the Running Companion '
                'mobile and web application. This page informs you of our policies '
                'regarding the collection, use, and disclosure of personal data when '
                'you use our service, and the choices you have associated with that data.',
              ),
            ]),
            _card([
              _heading('Information We Collect'),
              _bullet(
                'Account data: name, email address, and password (hashed) when you create an account.',
              ),
              _bullet(
                'Profile data: display name and optional profile photo from Google Sign-In.',
              ),
              _bullet(
                'Run data: workout sessions, distance, duration, pace, and timestamps you record.',
              ),
              _bullet(
                'Device data: device type, operating system, and app version for diagnostics.',
              ),
              _bullet(
                'Payment data: payment is processed by Stripe, Inc. We never store your full card number. We receive only a tokenised reference.',
              ),
              _bullet(
                'Usage data: anonymised analytics to improve features (e.g., which screens are used most).',
              ),
            ]),
            _card([
              _heading('How We Use Your Information'),
              _bullet(
                'To provide, maintain, and improve the Running Companion service.',
              ),
              _bullet('To authenticate you and keep your account secure.'),
              _bullet('To process subscription payments through Stripe.'),
              _bullet(
                'To send account-related emails (password reset, billing receipts).',
              ),
              _bullet(
                'To personalise your in-app AI coaching recommendations.',
              ),
              _bullet('To comply with legal obligations.'),
            ]),
            _card([
              _heading('Third-Party Services'),
              _body(
                'We use the following third-party services, each with their own privacy policy:',
              ),
              const SizedBox(height: 10),
              _link(
                'Firebase (Google LLC)',
                'https://firebase.google.com/support/privacy',
              ),
              _link(
                'Google Sign-In (Google LLC)',
                'https://policies.google.com/privacy',
              ),
              _link('Stripe, Inc. (payments)', 'https://stripe.com/privacy'),
            ]),
            _card([
              _heading('Data Storage & Security'),
              _body(
                'Your data is stored on Google Firebase servers located in the United States '
                '(us-central1). We implement industry-standard security measures including '
                'encrypted connections (HTTPS/TLS), Firebase Security Rules, and minimal '
                'data access principles. No system is 100% secure, and we cannot guarantee '
                'absolute security.',
              ),
            ]),
            _card([
              _heading('Data Retention'),
              _body(
                'We retain your account data for as long as your account is active. '
                'Run history and workout data are retained until you delete them or close '
                'your account. You may delete individual run sessions from within the app '
                'at any time.',
              ),
            ]),
            _card([
              _heading('Your Rights (GDPR & CCPA)'),
              _bullet(
                'Right to access: Request a copy of the data we hold about you.',
              ),
              _bullet(
                'Right to rectification: Correct inaccurate personal data.',
              ),
              _bullet(
                'Right to erasure: Request deletion of your account and data.',
              ),
              _bullet(
                'Right to portability: Receive your data in a machine-readable format.',
              ),
              _bullet(
                'Right to object: Opt out of marketing communications at any time.',
              ),
              _body(
                'To exercise any of these rights, email us at privacy@runningcompanion.run',
              ),
            ]),
            _card([
              _heading('Children\'s Privacy'),
              _body(
                'Our service is not directed to children under 13. We do not knowingly '
                'collect personal information from children under 13. If you are a parent '
                'and believe your child has provided us personal information, contact us '
                'at privacy@runningcompanion.run.',
              ),
            ]),
            _card([
              _heading('Changes to This Policy'),
              _body(
                'We may update this Privacy Policy from time to time. We will notify you '
                'of any material changes by posting the new policy on this page and updating '
                'the effective date above. Continued use of the app after changes constitutes '
                'acceptance of the updated policy.',
              ),
            ]),
            _card([
              _heading('Contact Us'),
              _body('For privacy-related inquiries:'),
              const SizedBox(height: 8),
              _contactRow(Icons.email_outlined, 'privacy@runningcompanion.run'),
              _contactRow(Icons.business, 'MLE Inc., Calgary, Alberta, Canada'),
              _contactRow(Icons.language, 'https://runningcompanion.web.app'),
            ]),
            const SizedBox(height: 20),
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

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF004D40),
        ),
      ),
    );
  }

  Widget _sub(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF00796B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _link(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 14, color: Color(0xFF00796B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF00796B),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00796B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
