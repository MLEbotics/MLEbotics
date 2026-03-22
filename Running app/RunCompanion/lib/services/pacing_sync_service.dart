import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'garmin_service.dart';
import 'robot_service.dart';

/// Bridges Garmin watch BLE data to the robot's adaptive pacing system.
///
/// The ROBOT is the pace-setter. It leads at a user-configured target speed.
/// The runner follows. If the runner falls behind, the robot slows down so
/// the runner isn't dropped — then resumes full pace once they catch up.
///
/// This service:
///  1. Reads runner's live pace from their Garmin watch via BLE.
///  2. Pushes that speed to the robot every second via /runner_update.
///     The robot firmware uses it as a secondary adaptive-slowdown signal:
///     robot won't run more than 0.5 km/h faster than the runner's watch pace.
///  3. Exposes `runnerSpeedStream` and `paceGapStream` for UI display.
///  4. Tracks robot's GPS position (phone is mounted on the robot).
///
/// Architecture:
///   Runner wears Garmin watch ──BLE──► Phone (MOUNTED ON ROBOT)
///                                            │  runner speed (km/h) every 1 s
///                                            ▼
///                                      /runner_update on robot ESP32
///                                      → firmware eases off if runner lags
///
/// Primary slowdown signal: back ultrasonic distance (always available).
/// Secondary signal: Garmin watch speed (when BLE is connected).
///
/// Usage:
///   final sync = PacingSyncService(robotService, garminService);
///   await sync.start();
///   sync.stop();
class PacingSyncService {
  final RobotService _robot;
  final GarminService _garmin; // required — watch monitors runner's pace

  StreamSubscription<GarminData>? _garminSub;
  StreamSubscription<Position>? _robotGpsSub;
  Timer? _pushTimer; // sends Garmin speed to robot every second

  // Runner's latest pace from Garmin watch
  double _runnerSpeedKmh = 0;
  bool _watchConnected = false;

  // Robot's current target pace (read from /status polling)
  double _robotTargetKmh = 0;

  // Robot's position from phone GPS (phone is on robot)
  double _robotLat = 0;
  double _robotLng = 0;

  bool _running = false;
  bool get isRunning => _running;

  /// Live stream of runner's actual speed from Garmin watch (km/h).
  /// Use this to display "your pace" in the UI.
  final _runnerSpeedController = StreamController<double>.broadcast();
  Stream<double> get runnerSpeedStream => _runnerSpeedController.stream;

  /// Stream of robot's GPS position (phone mounted on robot).
  final _robotPositionController =
      StreamController<({double lat, double lng})>.broadcast();
  Stream<({double lat, double lng})> get robotPositionStream =>
      _robotPositionController.stream;

  /// Stream of pace gap: runner speed − robot target speed (km/h).
  /// Positive = runner is faster than robot (runner pulling ahead of pacer).
  /// Negative = runner is slower (falling behind the pacer robot).
  /// Zero-ish = runner is on pace.
  final _paceGapController = StreamController<double>.broadcast();
  Stream<double> get paceGapStream => _paceGapController.stream;

  /// Whether the Garmin watch is currently connected over BLE.
  bool get isWatchConnected => _watchConnected;

  /// Latest runner pace from watch (0 if disconnected).
  double get currentRunnerSpeedKmh => _runnerSpeedKmh;

  /// Robot's current target pace (km/h) — set by the user via the app.
  double get robotTargetKmh => _robotTargetKmh;

  PacingSyncService(this._robot, this._garmin);

  /// Start monitoring. Also starts robot GPS tracking (phone is on robot).
  /// Returns false only if robot GPS permission denied.
  Future<bool> start() async {
    if (_running) return true;

    // ── Garmin watch BLE — runner's live pace (read-only) ───────────
    _watchConnected = _garmin.isConnected;
    _garminSub = _garmin.dataStream.listen((data) {
      _watchConnected = data.connected;
      if (data.connected && data.speedKmh > 0) {
        _runnerSpeedKmh = data.speedKmh;
      } else if (!data.connected) {
        _runnerSpeedKmh = 0;
      }
      if (!_runnerSpeedController.isClosed) {
        _runnerSpeedController.add(_runnerSpeedKmh);
      }
      _emitPaceGap();
    });

    // ── Robot status polling — read robot's target pace ─────────────
    // Subscribe to whatever RobotService is already polling so we always
    // know the robot's current set speed without adding extra HTTP calls.
    _robot.statusStream.listen((status) {
      _robotTargetKmh = status.targetPaceKmh;
      _emitPaceGap();
    });

    // ── Phone GPS — robot's own position ────────────────────────────
    // Phone is mounted on the robot. GPS here tracks the robot's route
    // for map display — NOT used to control the robot's speed.
    if (!kIsWeb) {
      final permOk = await _ensureGpsPermission();
      if (permOk) {
        _robotGpsSub =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 2, // update every 2 metres of movement
              ),
            ).listen((pos) {
              _robotLat = pos.latitude;
              _robotLng = pos.longitude;
              if (!_robotPositionController.isClosed) {
                _robotPositionController.add((lat: _robotLat, lng: _robotLng));
              }
            }, onError: (_) {});
      }
    }

    // ── Push runner's Garmin speed to robot every second ───────────
    // Firmware uses this for adaptive slowdown (signal [B]):
    // if robot is faster than watch pace + 0.5 km/h, robot eases off.
    // This does NOT change targetPaceKmH — robot remains the pace-setter.
    _pushTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_watchConnected && _runnerSpeedKmh > 0) {
        _robot.sendRunnerLocation(
          _robotLat,
          _robotLng,
          speedKmh: _runnerSpeedKmh,
        );
      }
    });

    _running = true;
    return true;
  }

  /// Stop monitoring.
  void stop() {
    _running = false;
    _garminSub?.cancel();
    _garminSub = null;
    _robotGpsSub?.cancel();
    _robotGpsSub = null;
    _pushTimer?.cancel();
    _pushTimer = null;
    _runnerSpeedKmh = 0;
    _robotTargetKmh = 0;
  }

  void dispose() {
    stop();
    _runnerSpeedController.close();
    _robotPositionController.close();
    _paceGapController.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  /// Emit the difference between runner's actual pace and robot's target pace.
  void _emitPaceGap() {
    if (!_paceGapController.isClosed) {
      _paceGapController.add(_runnerSpeedKmh - _robotTargetKmh);
    }
  }

  static Future<bool> _ensureGpsPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }
}
