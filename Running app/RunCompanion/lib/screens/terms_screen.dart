import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        title: const Text(
          'Terms of Service',
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
              _heading('Terms of Service'),
              _sub('Last updated: January 1, 2026'),
              const SizedBox(height: 8),
              _body(
                'Please read these Terms of Service ("Terms") carefully before using '
                'the Running Companion application operated by MLE Inc. ("Company", "we", "us", or "our"). '
                'By accessing or using our service, you agree to be bound by these Terms. '
                'If you disagree with any part, you may not access the service.',
              ),
            ]),
            _card([
              _heading('1. Use of Service'),
              _body(
                'Running Companion is a fitness companion application that connects to '
                'the RunBot autonomous running robot and provides features including pace '
                'tracking, AI coaching, hydration reminders, and run history. '
                'You must be at least 13 years old to use this service. '
                'You agree to use the service only for lawful purposes and in accordance '
                'with these Terms.',
              ),
            ]),
            _card([
              _heading('2. Accounts'),
              _bullet(
                'You are responsible for maintaining the confidentiality of your password.',
              ),
              _bullet(
                'You are responsible for all activities that occur under your account.',
              ),
              _bullet(
                'You must notify us immediately at support@runningcompanion.run of any unauthorised account use.',
              ),
              _bullet(
                'We reserve the right to terminate accounts that violate these Terms.',
              ),
            ]),
            _card([
              _heading('3. Subscriptions & Billing'),
              _body(
                'Running Companion offers free and paid subscription plans:',
              ),
              const SizedBox(height: 10),
              _bullet(
                'Free plan: Core features including run history and basic robot control.',
              ),
              _bullet(
                'Premium plan: Advanced AI coaching, unlimited history, priority support.',
              ),
              const SizedBox(height: 8),
              _body(
                'Paid subscriptions are billed in advance on a monthly or annual basis via Stripe. '
                'You may cancel at any time and retain access until the end of your billing period. '
                'We do not offer refunds for partial billing periods unless required by applicable law.',
              ),
            ]),
            _card([
              _heading('4. Acceptable Use'),
              _body('You agree NOT to:'),
              const SizedBox(height: 8),
              _bullet('Use the service for any unlawful purpose.'),
              _bullet(
                'Attempt to gain unauthorised access to any part of the service or its infrastructure.',
              ),
              _bullet(
                'Reverse-engineer, decompile, or disassemble any part of the app.',
              ),
              _bullet(
                'Interfere with or disrupt the integrity or performance of the service.',
              ),
              _bullet(
                'Use the service to transmit harmful, abusive, or offensive content.',
              ),
            ]),
            _card([
              _heading('5. RunBot Hardware'),
              _body(
                'The Running Companion app is designed to work with the RunBot autonomous '
                'running robot. The robot is sold separately. Use of the robot must comply '
                'with all applicable local laws and regulations. You assume all responsibility '
                'for safe operation of the robot in public and private spaces. '
                'MLE Inc. is not liable for accidents, injuries, or property damage resulting '
                'from robot operation.',
              ),
            ]),
            _card([
              _heading('6. Health & Safety Disclaimer'),
              _body(
                'Running Companion provides fitness tracking and pacing tools for informational '
                'purposes only. This app is NOT a medical device. Consult a qualified healthcare '
                'professional before starting any new exercise programme, especially if you have '
                'pre-existing health conditions. MLE Inc. assumes no liability for health outcomes '
                'resulting from use of the app or robot.',
              ),
            ]),
            _card([
              _heading('7. Intellectual Property'),
              _body(
                'The Running Companion name, logo, app design, and all content are the '
                'exclusive property of MLE Inc. and are protected by Canadian and international '
                'copyright and trademark law. You may not reproduce, distribute, or create '
                'derivative works without our express written permission.',
              ),
            ]),
            _card([
              _heading('8. Limitation of Liability'),
              _body(
                'To the maximum extent permitted by applicable law, MLE Inc. shall not be '
                'liable for any indirect, incidental, special, consequential, or punitive damages, '
                'including loss of data, revenue, or profits, arising out of or related to your '
                'use of the service. Our total liability to you for all claims shall not exceed '
                'the amount you paid us in the twelve months preceding the claim.',
              ),
            ]),
            _card([
              _heading('9. Governing Law'),
              _body(
                'These Terms shall be governed by and construed in accordance with the laws '
                'of the Province of Alberta, Canada, without regard to its conflict of law '
                'provisions. Any disputes shall be resolved in the courts of Alberta, Canada.',
              ),
            ]),
            _card([
              _heading('10. Changes to Terms'),
              _body(
                'We reserve the right to modify these Terms at any time. We will notify you '
                'of significant changes via email or an in-app notice. Your continued use of '
                'the service after changes constitutes acceptance of the updated Terms.',
              ),
            ]),
            _card([
              _heading('Contact Us'),
              _body('For questions about these Terms:'),
              const SizedBox(height: 8),
              _contactRow(Icons.email_outlined, 'legal@runningcompanion.run'),
              _contactRow(Icons.business, 'MLE Inc., Calgary, Alberta, Canada'),
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
