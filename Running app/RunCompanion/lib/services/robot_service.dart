import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Talks to the ESP32 robot over WiFi.
/// Enable your phone's Personal Hotspot — the robot connects to it automatically.
/// Your phone keeps full cellular internet. No manual WiFi switching needed.
class RobotService {
  // Robot advertises itself via mDNS as runner-companion.local
  static const String _robotIp = 'http://runner-companion.local';
  static const Duration _timeout = Duration(seconds: 3);

  // ── Status polling ──────────────────────────────────────────────
  Timer? _statusTimer;
  final _statusController = StreamController<RobotStatus>.broadcast();
  Stream<RobotStatus> get statusStream => _statusController.stream;

  void startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      fetchStatus();
    });
  }

  void stopPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<RobotStatus?> fetchStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_robotIp/status'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final status = RobotStatus.fromJson(jsonDecode(res.body));
        _statusController.add(status);
        return status;
      }
    } catch (_) {
      // Robot not reachable
    }
    return null;
  }

  // ── Pacing control ──────────────────────────────────────────────

  /// Start pacing: set target pace (km/h) and list of GPS waypoints
  Future<bool> startPacing({
    required double paceKmh,
    required List<LatLng> waypoints,
  }) async {
    try {
      final body = jsonEncode({
        'pace': paceKmh,
        'waypoints': waypoints
            .map((w) => {'lat': w.lat, 'lng': w.lng})
            .toList(),
      });
      final res = await http
          .post(
            Uri.parse('$_robotIp/start'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopPacing() async {
    try {
      final res = await http
          .post(Uri.parse('$_robotIp/stop'))
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send the reversed waypoint list so the robot drives back to the start.
  /// The ESP32 handles the reversed route under POST /return_start.
  Future<bool> returnToStart({
    required double paceKmh,
    required List<LatLng> reversedWaypoints,
  }) async {
    try {
      final body = jsonEncode({
        'pace': paceKmh,
        'waypoints': reversedWaypoints
            .map((w) => {'lat': w.lat, 'lng': w.lng})
            .toList(),
      });
      final res = await http
          .post(
            Uri.parse('$_robotIp/return_start'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Update pace mid-run (runner adjusting target pace)
  Future<bool> updatePace(double paceKmh) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_robotIp/pace'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pace': paceKmh}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Push the runner's live GPS location to the robot every second.
  /// The robot uses this to know exactly where the runner is so it can
  /// maintain the correct distance ahead and stay on the right path.
  Future<bool> sendRunnerLocation(
    double lat,
    double lng, {
    double speedKmh = 0,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_robotIp/runner_update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'lat': lat, 'lng': lng, 'speedKmh': speedKmh}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Manual commands ─────────────────────────────────────────────
  Future<void> sendCommand(String cmd) async {
    try {
      await http
          .post(
            Uri.parse('$_robotIp/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'cmd': cmd}),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  void dispose() {
    stopPolling();
    _statusController.close();
  }
}

// ── Data models ──────────────────────────────────────────────────────

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class RobotStatus {
  final double lat;
  final double lng;
  final double speedKmh;
  final bool isPacing;
  final int waypoint;
  final int totalWaypoints;
  final bool gpsFix;
  final double frontCm;
  final double backCm;

  /// Side clearance from lateral ultrasonic sensors (cm). 0 = no sensor data.
  final double leftCm;
  final double rightCm;

  /// Battery level 0–100 %. Sent by ESP32 as 'bat' in the status JSON. -1 = no data.
  final int batteryPct;

  /// Raw voltage from the battery sensor (volts). Optional field 'batV'.
  final double batteryVolts;
  final bool avoiding;
  final bool runnerLost;

  /// True when the IMU detects the robot has tipped over (pitch or roll > threshold).
  /// Sent by ESP32 as 'tipped': true/false in the status JSON.
  final bool isTipped;

  /// IMU pitch angle in degrees (positive = nose up, negative = nose down).
  final double pitchDeg;

  /// IMU roll angle in degrees (positive = right lean, negative = left lean).
  final double rollDeg;

  /// The pace the robot is currently targeting (km/h), as set via startPacing()
  /// or updatePace(). This is the robot's set leader speed — not the runner's.
  final double targetPaceKmh;

  /// True when the ESP32 camera is initialised and streaming on port 81.
  final bool cameraOk;

  /// Target full-charge range in km.
  /// Physics: wheeled robot energy is distance-based (rolling resistance).
  /// 60 km gives ~2 h at 30 km/h (2 min/km elite pace) and
  ///          ~4 h at 15 km/h (4 min/km training pace).
  static const double maxRangeKm = 60.0;

  /// Maximum supported robot speed in km/h (2 min/km = 30 km/h).
  static const double maxSpeedKmh = 30.0;

  const RobotStatus({
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.isPacing,
    required this.waypoint,
    required this.totalWaypoints,
    required this.gpsFix,
    required this.frontCm,
    required this.backCm,
    this.leftCm = 0,
    this.rightCm = 0,
    this.batteryPct = -1, // -1 = no data from robot
    this.batteryVolts = 0,
    this.avoiding = false,
    this.runnerLost = false,
    this.isTipped = false,
    this.pitchDeg = 0,
    this.rollDeg = 0,
    this.targetPaceKmh = 0,
    this.cameraOk = false,
  });

  factory RobotStatus.fromJson(Map<String, dynamic> j) => RobotStatus(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    speedKmh: (j['speedKmh'] as num).toDouble(),
    isPacing: j['isPacing'] as bool,
    waypoint: j['waypoint'] as int,
    totalWaypoints: j['totalWaypoints'] as int,
    gpsFix: j['gpsFix'] as bool,
    frontCm: (j['frontCm'] as num).toDouble(),
    backCm: (j['backCm'] as num).toDouble(),
    leftCm: ((j['leftCm'] as num?) ?? 0).toDouble(),
    rightCm: ((j['rightCm'] as num?) ?? 0).toDouble(),
    batteryPct: ((j['bat'] as num?) ?? -1).toInt(),
    batteryVolts: ((j['batV'] as num?) ?? 0).toDouble(),
    avoiding: (j['avoiding'] as bool? ?? false),
    runnerLost: (j['runnerLost'] as bool? ?? false),
    isTipped: (j['tipped'] as bool? ?? false),
    pitchDeg: ((j['pitch'] as num?) ?? 0).toDouble(),
    rollDeg: ((j['roll'] as num?) ?? 0).toDouble(),
    targetPaceKmh: ((j['targetPaceKmH'] as num?) ?? 0).toDouble(),
    cameraOk: (j['cameraOk'] as bool? ?? false),
  );

  /// Distance behind robot (metres) from back ultrasonic sensor
  double get runnerDistanceBehind => backCm / 100.0;

  /// Estimated km remaining based on battery percentage.
  double get batteryRangeKm =>
      batteryPct >= 0 ? (batteryPct / 100.0 * maxRangeKm) : -1;

  /// Estimated runtime remaining in minutes at a given pace (km/h).
  /// Faster pace = shorter runtime; slower pace = longer runtime.
  int batteryRuntimeMinsAtPace(double paceKmh) {
    if (batteryPct < 0 || paceKmh <= 0) return -1;
    final rangeKm = batteryPct / 100.0 * maxRangeKm;
    return (rangeKm / paceKmh * 60).round();
  }

  /// Battery is dangerously low (robot has <6 km / ~12 min at 30 km/h remaining).
  bool get isBatteryCritical => batteryPct >= 0 && batteryPct <= 10;

  /// Battery is low (<12 km / ~24 min at 30 km/h remaining).
  bool get isBatteryLow => batteryPct >= 0 && batteryPct <= 20;

  /// Human-readable battery string, e.g. "72% (~43.2 km remaining)".
  String get batteryLabel {
    if (batteryPct < 0) return 'unknown';
    final km = batteryRangeKm;
    final kmStr = km >= 1
        ? '~${km.toStringAsFixed(1)} km'
        : '~${(km * 1000).round()} m';
    return '$batteryPct% ($kmStr remaining)';
  }

  /// Which side has more clearance based on lateral sensors.
  /// Returns 'left', 'right', or 'both' (when no sensor data or equal).
  String get clearerSide {
    if (leftCm <= 0 && rightCm <= 0) return 'both';
    if (leftCm <= 0) return 'right';
    if (rightCm <= 0) return 'left';
    if ((leftCm - rightCm).abs() < 20) return 'both'; // within 20 cm → same
    return leftCm > rightCm ? 'left' : 'right';
  }

  /// Obstacle ahead or active avoidance maneuver
  bool get obstacleAhead => avoiding || (frontCm > 0 && frontCm < 50);

  /// Robot has fallen and needs to self-right (IMU tilt > ~45°)
  bool get needsSelfRighting =>
      isTipped || pitchDeg.abs() > 45 || rollDeg.abs() > 45;

  /// Progress through waypoints (0.0–1.0)
  double get progress =>
      totalWaypoints == 0 ? 0 : waypoint / totalWaypoints.toDouble();

  // Speed as pace string (min:sec per km)
  String get paceString {
    if (speedKmh < 0.5) return '--:--';
    double minPerKm = 60.0 / speedKmh;
    int mins = minPerKm.floor();
    int secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
