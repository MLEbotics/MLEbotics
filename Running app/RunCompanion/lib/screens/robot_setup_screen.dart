import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Guides the user through connecting the robot to their phone's hotspot.
///
/// Two modes:
///  - [isFirstTime] = true  → full 3-step wizard (robot is in setup AP mode)
///  - [isFirstTime] = false → quick change-WiFi form (robot already connected)
class RobotSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const RobotSetupScreen({super.key, this.isFirstTime = true});

  @override
  State<RobotSetupScreen> createState() => _RobotSetupScreenState();
}

class _RobotSetupScreenState extends State<RobotSetupScreen> {
  // Step indexes: 0 = instructions, 1 = enter credentials, 2 = sending/result
  int _step = 0;

  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePass = true;
  bool _sending = false;
  String? _errorMsg;
  bool _success = false;

  // In setup mode the robot's AP IP is 192.168.4.1.
  // In change mode the robot is already on the hotspot, use mDNS hostname.
  String get _robotBase => widget.isFirstTime
      ? 'http://192.168.4.1'
      : 'http://runner-companion.local';

  @override
  void initState() {
    super.initState();
    // Skip straight to form if just changing WiFi (not first time)
    if (!widget.isFirstTime) _step = 1;
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _sendCredentials() async {
    final ssid = _ssidController.text.trim();
    final pass = _passController.text;
    if (ssid.isEmpty) {
      setState(() => _errorMsg = 'Please enter your hotspot name.');
      return;
    }
    setState(() {
      _sending = true;
      _errorMsg = null;
      _step = 2;
    });

    try {
      final res = await http
          .post(
            Uri.parse('$_robotBase/configure'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ssid': ssid, 'password': pass}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        setState(() {
          _success = true;
          _sending = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Robot returned error ${res.statusCode}.';
          _sending = false;
          _step = 1;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg =
            'Could not reach robot.\n'
            'Make sure your phone WiFi is connected to "${_robotBase.contains('192') ? 'RunnerCompanion-Setup' : 'your hotspot'}".\n'
            'Then try again.';
        _sending = false;
        _step = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Robot WiFi Setup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildInstructionsStep();
      case 1:
        return _buildFormStep();
      case 2:
        return _buildResultStep();
      default:
        return const SizedBox();
    }
  }

  // ── Step 0: First-time instructions ──────────────────────────────

  Widget _buildInstructionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.wifi_tethering,
          title: 'Connect to Robot',
          subtitle: 'One-time setup — takes about 1 minute',
        ),
        const SizedBox(height: 28),
        _instructionCard(
          step: '1',
          title: 'Turn on the robot',
          body: 'Power it on. The LED will blink — it is waiting for setup.',
        ),
        _instructionCard(
          step: '2',
          title: 'Connect your phone WiFi to the robot',
          body:
              'Go to your phone\u2019s WiFi settings and connect to:\n\n'
              '  Network:  RunnerCompanion-Setup\n'
              '  Password: setup1234\n\n'
              'Your phone\u2019s internet will pause for ~30 seconds while you do this.',
          highlight: true,
        ),
        _instructionCard(
          step: '3',
          title: 'Come back here and tap Next',
          body:
              'You\u2019ll enter your Personal Hotspot name and password so the '
              'robot can connect to it automatically on every future run.',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text(
              'I am connected to RunnerCompanion-Setup',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () => setState(() => _step = 1),
          ),
        ),
      ],
    );
  }

  Widget _instructionCard({
    required String step,
    required String title,
    required String body,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.teal.withOpacity(0.15)
            : Colors.white.withOpacity(0.06),
        border: Border.all(
          color: highlight ? Colors.teal : Colors.white12,
          width: highlight ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 14, top: 2),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Enter credentials form ───────────────────────────────

  Widget _buildFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.smartphone,
          title: widget.isFirstTime
              ? 'Your Phone Hotspot'
              : 'Change Robot WiFi',
          subtitle: widget.isFirstTime
              ? 'Enter your Personal Hotspot details'
              : 'Robot will reboot and connect to the new hotspot',
        ),
        const SizedBox(height: 28),
        _infoBox(
          icon: Icons.info_outline,
          text: widget.isFirstTime
              ? 'The robot will save these details and auto-connect every time you enable your Personal Hotspot. Your phone keeps its full internet connection.'
              : 'After saving, the robot reboots. Enable your phone\u2019s hotspot before turning the robot on.',
        ),
        const SizedBox(height: 24),
        _label('Hotspot Name (SSID)'),
        const SizedBox(height: 8),
        _textField(
          controller: _ssidController,
          hint: 'e.g.  Eddie\'s iPhone  or  Samsung Galaxy S24',
          icon: Icons.wifi,
        ),
        const SizedBox(height: 16),
        _label('Hotspot Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passController,
          obscureText: _obscurePass,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Leave blank if your hotspot has no password',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              border: Border.all(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMsg!,
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
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.save_rounded),
            label: const Text(
              'Save & Connect Robot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _sendCredentials,
          ),
        ),
        if (widget.isFirstTime) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _step = 0),
            icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white54),
            label: const Text(
              'Back to instructions',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 2: Sending / result ──────────────────────────────────────

  Widget _buildResultStep() {
    if (_sending) {
      return const _SendingIndicator();
    }
    if (_success) {
      return _buildSuccessStep();
    }
    return const SizedBox(); // error handled in step 1
  }

  Widget _buildSuccessStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 80),
        const SizedBox(height: 24),
        const Text(
          'WiFi Saved!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'The robot has saved your hotspot and is rebooting.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 15),
        ),
        const SizedBox(height: 32),
        _infoBox(
          icon: Icons.check_circle_outline,
          text:
              'From now on:\n\n'
              '1. Enable your phone\'s Personal Hotspot\n'
              '2. Turn on the robot\n'
              '3. Robot auto-connects — no setup needed\n'
              '4. Your phone keeps full internet',
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      prefixIcon: Icon(icon, color: Colors.teal),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.teal, width: 2),
      ),
    ),
  );

  Widget _infoBox({required IconData icon, required String text}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.teal.withOpacity(0.1),
      border: Border.all(color: Colors.teal.withOpacity(0.4)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.tealAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Sub-widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.tealAccent, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SendingIndicator extends StatelessWidget {
  const _SendingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal, strokeWidth: 3),
          SizedBox(height: 28),
          Text(
            'Sending to robot...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'The robot will reboot after saving.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
