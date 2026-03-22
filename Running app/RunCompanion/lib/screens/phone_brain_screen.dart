import 'package:flutter/material.dart';

/// Phone-as-Brain screen.
///
/// The key insight: the robot carries the phone.
/// The phone provides:
///   - GPS  (no separate GPS unit needed)
///   - Gemini AI  (on-device LLM, no cloud API quota leakage)
///   - Mobile data / WiFi  (streaming maps, music, telemetry)
///   - Bluetooth speaker  (music, TTS announcements)
///   - Camera  (obstacle detection in future)
///
/// The robot's microcontroller (Arduino / Raspberry Pi) connects to the phone
/// either via:
///   A) USB-Serial (most reliable — just_a USB OTG cable)
///   B) WiFi softAP / TCP socket  (wireless, ~10 ms latency)
///
/// This screen lets the runner pick a connection mode, see live telemetry,
/// and understand what the phone is doing for the robot.
class PhoneBrainScreen extends StatefulWidget {
  const PhoneBrainScreen({super.key});

  @override
  State<PhoneBrainScreen> createState() => _PhoneBrainScreenState();
}

class _PhoneBrainScreenState extends State<PhoneBrainScreen> {
  _ConnectionMode _connectionMode = _ConnectionMode.wifi;
  bool _robotConnected = false;
  String _robotIp =
      '192.168.4.1'; // default when phone is connected to robot's AP
  int _robotPort = 8888;
  String _serialPort = '/dev/ttyUSB0';

  // Simulated telemetry (replace with real data from robot socket)
  final double _batteryPercent = 87;
  final double _motorLeftRpm = 0;
  final double _motorRightRpm = 0;
  String _robotStatus = 'Idle';
  final bool _obstacleDetected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1E),
        foregroundColor: Colors.white,
        title: const Text(
          'Phone-as-Brain',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Connection indicator
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _robotConnected
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _robotConnected ? Icons.link : Icons.link_off,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  _robotConnected ? 'Robot Online' : 'Not Connected',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── How it works banner ─────────────────────────────────────────
            _SectionCard(
              color: const Color(0xFF0D47A1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Phone IS the Robot Brain',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _BrainFeatureRow(
                    Icons.gps_fixed,
                    'GPS',
                    'Phone GPS guides the robot — no extra GPS hardware needed',
                  ),
                  _BrainFeatureRow(
                    Icons.smart_toy,
                    'Gemini AI',
                    'Gemini controls the robot via voice — say "open the box", "slow down", "stop"',
                  ),
                  _BrainFeatureRow(
                    Icons.watch,
                    'Garmin Watch',
                    'Phone receives live HR, cadence & pace from Garmin via BT — robot never needs to pair',
                  ),
                  _BrainFeatureRow(
                    Icons.speaker,
                    'BT Speaker',
                    'Run\'s music + TTS through robot\'s Bluetooth speaker — ask Gemini to play music',
                  ),
                  _BrainFeatureRow(
                    Icons.wifi,
                    'Mobile Data',
                    'Map streaming, YouTube Music, weather — all via phone\'s network',
                  ),
                  _BrainFeatureRow(
                    Icons.camera_alt,
                    'Camera',
                    'Phone camera faces forward for obstacle detection (future)',
                  ),
                  _BrainFeatureRow(
                    Icons.battery_charging_full,
                    'Power',
                    'Robot battery charges the phone while running — phone never dies',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Connection Mode ─────────────────────────────────────────────
            _SectionCard(
              color: const Color(0xFF1B1B3A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: 'WiFi / TCP',
                          icon: Icons.wifi,
                          selected: _connectionMode == _ConnectionMode.wifi,
                          onTap: () => setState(
                            () => _connectionMode = _ConnectionMode.wifi,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeChip(
                          label: 'USB Cable',
                          icon: Icons.usb,
                          selected: _connectionMode == _ConnectionMode.usb,
                          onTap: () => setState(
                            () => _connectionMode = _ConnectionMode.usb,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // WiFi settings
                  if (_connectionMode == _ConnectionMode.wifi) ...[
                    const Text(
                      'Robot creates a WiFi hotspot. Phone connects to it.\n'
                      'Robot IP is usually 192.168.4.1 (ESP32 default).',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _DarkTextField(
                            label: 'Robot IP',
                            initial: _robotIp,
                            onChanged: (v) => _robotIp = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _DarkTextField(
                            label: 'Port',
                            initial: '$_robotPort',
                            onChanged: (v) =>
                                _robotPort = int.tryParse(v) ?? 8888,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // USB settings
                  if (_connectionMode == _ConnectionMode.usb) ...[
                    const Text(
                      'Connect phone to robot controller via USB OTG cable.\n'
                      'Requires USB serial permission on Android.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    _DarkTextField(
                      label: 'Serial port (Android)',
                      initial: _serialPort,
                      onChanged: (v) => _serialPort = v,
                    ),
                  ],

                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _robotConnected
                          ? Colors.red
                          : Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: _toggleConnection,
                    icon: Icon(_robotConnected ? Icons.link_off : Icons.link),
                    label: Text(
                      _robotConnected ? 'Disconnect Robot' : 'Connect to Robot',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Live Telemetry ──────────────────────────────────────────────
            _SectionCard(
              color: const Color(0xFF1B1B3A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Robot Telemetry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TelemetryTile(
                          icon: Icons.battery_full,
                          label: 'Battery',
                          value: '${_batteryPercent.round()}%',
                          color: _batteryPercent > 30
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TelemetryTile(
                          icon: Icons.settings,
                          label: 'Status',
                          value: _robotStatus,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TelemetryTile(
                          icon: Icons.rotate_left,
                          label: 'Motor L',
                          value: '${_motorLeftRpm.round()} rpm',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TelemetryTile(
                          icon: Icons.rotate_right,
                          label: 'Motor R',
                          value: '${_motorRightRpm.round()} rpm',
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  if (_obstacleDetected) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'OBSTACLE DETECTED — Robot Paused',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Hardware Guide ──────────────────────────────────────────────
            _SectionCard(
              color: const Color(0xFF0D2D1A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.build, color: Colors.greenAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Recommended Robot Hardware',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _HardwareRow(
                    '🧠',
                    'Controller',
                    'ESP32 (WiFi/BT) or Raspberry Pi Zero 2 W',
                  ),
                  _HardwareRow(
                    '⚡',
                    'Motors',
                    '2× brushless DC hub motors with encoder feedback',
                  ),
                  _HardwareRow(
                    '🔋',
                    'Battery',
                    '4S LiPo 5000 mAh + USB-C PD for phone charging',
                  ),
                  _HardwareRow(
                    '🔊',
                    'Speaker',
                    'Bluetooth speaker (Sony SRS-XB13 or similar)',
                  ),
                  _HardwareRow(
                    '📡',
                    'Phone Mount',
                    'Vibration-damped cradle with USB OTG / WiFi link',
                  ),
                  _HardwareRow(
                    '📦',
                    'Supply Box',
                    'Lock servo on lid, NFC tag inside for inventory',
                  ),
                  _HardwareRow(
                    '👁️',
                    'Eyes',
                    'Phone camera + optional ultrasonic sensors (HC-SR04)',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'With this setup, the total extra electronics cost is ~£40–80 '
                    '(ESP32 + motor drivers + chassis). The phone does everything else.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Quick commands ──────────────────────────────────────────────
            if (_robotConnected) ...[
              const Text(
                'Quick Commands',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CommandButton(
                    'Follow Me',
                    Icons.directions_run,
                    Colors.teal,
                    () => _send('follow_me'),
                  ),
                  _CommandButton(
                    'Stop',
                    Icons.stop_circle,
                    Colors.red,
                    () => _send('stop'),
                  ),
                  _CommandButton(
                    'Return Home',
                    Icons.home,
                    Colors.green,
                    () => _send('return_home'),
                  ),
                  _CommandButton(
                    'Open Box',
                    Icons.lock_open,
                    Colors.orange,
                    () => _send('open_box'),
                  ),
                  _CommandButton(
                    'Close Box',
                    Icons.lock,
                    Colors.blueGrey,
                    () => _send('close_box'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _toggleConnection() {
    setState(() {
      _robotConnected = !_robotConnected;
      _robotStatus = _robotConnected ? 'Connected' : 'Idle';
    });
    // TODO: Open TCP socket to _robotIp:_robotPort or USB serial to _serialPort.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _robotConnected
              ? 'Robot connected via ${_connectionMode.name.toUpperCase()}'
              : 'Robot disconnected',
        ),
        backgroundColor: _robotConnected ? Colors.teal : Colors.grey,
      ),
    );
  }

  void _send(String cmd) {
    setState(() => _robotStatus = cmd.replaceAll('_', ' ').toUpperCase());
    // TODO: Write cmd to open TCP socket or serial port.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent: $cmd'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

enum _ConnectionMode { wifi, usb }

class _SectionCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const _SectionCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _BrainFeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  const _BrainFeatureRow(this.icon, this.label, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.tealAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.white12,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: Colors.tealAccent, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _TelemetryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HardwareRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  const _HardwareRow(this.emoji, this.label, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  const _DarkTextField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.teal),
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _CommandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _CommandButton(this.label, this.icon, this.color, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
