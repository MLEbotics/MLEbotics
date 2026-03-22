import 'dart:async';
import 'package:flutter/material.dart';
import '../services/robot_service.dart';
import '../services/firestore_service.dart';
import '../services/garmin_service.dart';

// ── Aid Station Screen ────────────────────────────────────────────────────────
//
// The robot acts as a mobile aid station — it waits at the runner's start/
// finish or follows a slow patrol route, carrying the enclosed supply box
// containing hydration, energy gels and extra clothing.
//
// Runners can:
//  • Set a "wait here" GPS location for the robot to hold position
//  • Call the robot to their current GPS position (phone GPS)
//  • Open/close the supply box lid remotely
//  • See what's loaded in the box
//  • Record aid stops in run history

class AidStationScreen extends StatefulWidget {
  const AidStationScreen({super.key});

  @override
  State<AidStationScreen> createState() => _AidStationScreenState();
}

class _AidStationScreenState extends State<AidStationScreen> {
  final _robotService = RobotService();
  final _firestoreService = FirestoreService();
  final _garminService = GarminService();

  bool _isActive = false;
  bool _isConnected = false;
  bool _boxOpen = false;
  RobotStatus? _robotStatus;
  GarminData _garminData = const GarminData();
  bool _garminScanning = false;
  DateTime? _sessionStart;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Box inventory (user-adjustable)
  final Map<String, bool> _inventory = {
    'Water bottle': true,
    'Electrolyte drink': true,
    'Energy gel × 2': true,
    'Energy bar': false,
    'Light jacket': true,
    'Arm warmers': false,
    'Cap / visor': false,
    'Blister kit': false,
  };

  @override
  void initState() {
    super.initState();
    _robotService.statusStream.listen((s) {
      if (mounted) setState(() => _robotStatus = s);
    });
    _garminService.dataStream.listen((d) {
      if (mounted) setState(() => _garminData = d);
    });
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final s = await _robotService.fetchStatus();
    if (mounted) setState(() => _isConnected = s != null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _robotService.dispose();
    _garminService.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
  }

  Future<void> _activate() async {
    setState(() {
      _isActive = true;
      _isConnected = true;
      _sessionStart = DateTime.now();
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_sessionStart!));
      }
    });
    _robotService.startPolling();
    // TODO: send 'aid_station_mode' command to robot firmware
  }

  Future<void> _deactivate() async {
    _timer?.cancel();
    _robotService.stopPolling();
    if (_sessionStart != null) {
      await _firestoreService.saveRunSession(
        mode: 'Aid Station',
        startTime: _sessionStart!,
        duration: _elapsed,
        avgHeartRate: _garminData.heartRate > 0 ? _garminData.heartRate : null,
      );
    }
    setState(() {
      _isActive = false;
      _elapsed = Duration.zero;
      _boxOpen = false;
    });
  }

  void _toggleBox() {
    setState(() => _boxOpen = !_boxOpen);
    // TODO: send 'open_box' / 'close_box' command to robot firmware
  }

  Future<void> _callRobotHere() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Sending your position to the robot…'),
        backgroundColor: Colors.teal,
      ),
    );
    // TODO: get phone GPS position and send to robot
  }

  Future<void> _sendToWaitPoint() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏁 Robot returning to wait point…'),
        backgroundColor: Colors.indigo,
      ),
    );
    // TODO: send pre-set wait-point GPS to robot
  }

  Future<void> _connectGarmin() async {
    if (_garminData.connected) {
      await _garminService.disconnect();
      return;
    }
    setState(() => _garminScanning = true);
    final ok = await _garminService.autoConnect();
    if (mounted) {
      setState(() => _garminScanning = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find Garmin watch. Make sure Bluetooth is on.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text('Aid Station Mode'),
        actions: [
          // Garmin
          _garminScanning
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _garminData.connected ? Icons.watch : Icons.watch_outlined,
                    color: _garminData.connected
                        ? Colors.greenAccent
                        : Colors.white70,
                  ),
                  tooltip: _garminData.connected
                      ? 'Disconnect Garmin'
                      : 'Connect Garmin',
                  onPressed: _connectGarmin,
                ),
          // Robot WiFi
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.greenAccent : Colors.white38,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status / timer banner ─────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isActive
                      ? [const Color(0xFF1565C0), const Color(0xFF0288D1)]
                      : [Colors.grey.shade700, Colors.grey.shade500],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive
                        ? Icons.local_hospital
                        : Icons.local_hospital_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isActive
                              ? 'Aid Station Active'
                              : 'Aid Station Ready',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isActive
                              ? 'Session: ${_fmt(_elapsed)}'
                              : 'Tap Activate to deploy',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_garminData.connected && _garminData.heartRate > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_garminData.heartRate} bpm',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Activate / Deactivate button ──────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isActive
                      ? Colors.red
                      : const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isActive ? _deactivate : _activate,
                icon: Icon(_isActive ? Icons.stop : Icons.play_arrow, size: 26),
                label: Text(
                  _isActive ? 'Deactivate & Save' : 'Activate Aid Station',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Control buttons ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ControlCard(
                    icon: Icons.my_location,
                    label: 'Call Robot\nTo Me',
                    color: Colors.teal,
                    onTap: _isActive ? _callRobotHere : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ControlCard(
                    icon: Icons.flag,
                    label: 'Send To\nWait Point',
                    color: Colors.indigo,
                    onTap: _isActive ? _sendToWaitPoint : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ControlCard(
                    icon: _boxOpen ? Icons.lock_open : Icons.lock,
                    label: _boxOpen ? 'Close\nBox Lid' : 'Open\nBox Lid',
                    color: _boxOpen ? Colors.orange : Colors.blueGrey,
                    onTap: _isActive ? _toggleBox : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Supply box contents ───────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1565C0,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: Color(0xFF1565C0),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'ENCLOSED SUPPLY BOX',
                                style: TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_boxOpen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Text(
                              '🔓 LID OPEN',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Text(
                              '🔒 SEALED',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap items to mark as loaded / empty',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Divider(height: 20),
                    ..._inventory.entries.map((e) {
                      final category = _categoryOf(e.key);
                      return CheckboxListTile(
                        value: e.value,
                        dense: true,
                        activeColor: category.color,
                        secondary: Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                        title: Text(
                          e.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onChanged: (v) =>
                            setState(() => _inventory[e.key] = v ?? false),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Robot status ──────────────────────────────────────────
            if (_isActive && _robotStatus != null)
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.smart_toy, color: Colors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _robotStatus!.gpsFix ? '📍 GPS Fix' : '⚠ No GPS',
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (_robotStatus!.obstacleAhead)
                              const Text(
                                '⛔ Obstacle ahead',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
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
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Category {
  final IconData icon;
  final Color color;
  const _Category(this.icon, this.color);
}

_Category _categoryOf(String item) {
  final lower = item.toLowerCase();
  if (lower.contains('water') ||
      lower.contains('drink') ||
      lower.contains('electrolyte')) {
    return const _Category(Icons.water_drop, Colors.blue);
  }
  if (lower.contains('gel') ||
      lower.contains('bar') ||
      lower.contains('energy')) {
    return const _Category(Icons.bolt, Colors.orange);
  }
  if (lower.contains('jacket') ||
      lower.contains('arm') ||
      lower.contains('cap') ||
      lower.contains('cloth')) {
    return const _Category(Icons.checkroom, Colors.purple);
  }
  return const _Category(Icons.medical_services, Colors.red);
}

class _ControlCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ControlCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade300
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: disabled ? Colors.grey : color),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: disabled ? Colors.grey : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
