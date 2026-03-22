import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/evening_river_scene.dart';

/// Shown once on the very first app launch.
/// Stores `onboarding_seen = true` in SharedPreferences when dismissed.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.smart_toy_rounded,
      gradient: [Color(0xFF004D40), Color(0xFF00897B)],
      title: 'Your Robot Running Buddy',
      subtitle:
          'Running Companion connects to your RunBot — an autonomous robot that '
          'follows you, carries your gear, and keeps you on pace.',
    ),
    _OnboardPage(
      icon: Icons.speed,
      gradient: [Color(0xFF1A237E), Color(0xFF283593)],
      title: 'Smart Pacing & Workouts',
      subtitle:
          'Set your target pace and let the AI coach you through intervals, '
          'long runs, and races. The robot slows down when you fall behind.',
    ),
    _OnboardPage(
      icon: Icons.inventory_2_rounded,
      gradient: [Color(0xFF1565C0), Color(0xFF1976D2)],
      title: 'Aid Station on Wheels',
      subtitle:
          'The robot\'s enclosed box holds your water, energy gels, jacket, '
          'and extra gear — always within arm\'s reach no matter how far you run.',
    ),
    _OnboardPage(
      icon: Icons.campaign_rounded,
      gradient: [Color(0xFF7B1FA2), Color(0xFF8E24AA)],
      title: 'Safety & Alerts',
      subtitle:
          'Alert Ahead notifies your contacts when you start a run, and sends '
          'your GPS position if you don\'t check in on time.',
    ),
    _OnboardPage(
      icon: Icons.rocket_launch_rounded,
      gradient: [Color(0xFFE65100), Color(0xFFF4511E)],
      title: 'Ready to Run?',
      subtitle:
          'Create your free account and try the full app today. '
          'Pre-order your RunBot to be first in line when it ships.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _PageView(page: _pages[i]),
          ),
          // ── Page indicator ──
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentPage ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        i == _currentPage
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // ── Bottom buttons ──
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              children: [
                // Skip
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 15)),
                  )
                else
                  const SizedBox(width: 72),
                const Spacer(),
                // Next / Get Started
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF004D40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                  child: Text(
                    _currentPage < _pages.length - 1
                        ? 'Next  →'
                        : 'Get Started',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;

  const _OnboardPage({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
  });
}

class _PageView extends StatelessWidget {
  final _OnboardPage page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCC0F141B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: page.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.gradient.last.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(page.icon, color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    page.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
