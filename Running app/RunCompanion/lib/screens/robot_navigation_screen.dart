import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../models/workout_plan.dart';
import '../screens/workout_upload_screen.dart';
import '../services/robot_service.dart';

// ── RobotNavigationScreen ──────────────────────────────────────────────────
/// Full-screen map where you tap a destination and the robot navigates to it.
///
/// Flow:
///   1. Map shows live robot position + your GPS position.
///   2. Tap anywhere → places a destination pin → OSRM fetches a running
///      route automatically.
///   3. Optionally toggle "Out & Back" so the robot returns to start.
///   4. Optionally link a workout plan — robot adjusts pace per each step.
///   5. Adjust the robot speed with the slider (overridden by linked workout).
///   6. Hit "Send to Robot" → robot starts the route at the workout pace.
///
/// Map tiles: OpenStreetMap (no API key required, works on all platforms).
/// Routing:   OSRM public demo server (foot/running profile, free, no key).
class RobotNavigationScreen extends StatefulWidget {
  const RobotNavigationScreen({super.key});

  @override
  State<RobotNavigationScreen> createState() => _RobotNavigationScreenState();
}

class _RobotNavigationScreenState extends State<RobotNavigationScreen> {
  final RobotService _robot = RobotService();
  final MapController _mapController = MapController();

  // ── State ───────────────────────────────────────────────────────
  ll.LatLng? _robotPos;
  ll.LatLng? _userPos;
  ll.LatLng? _destination;
  List<ll.LatLng> _routePoints = [];

  double _speedKmh = 12; // default ~5 min/km jog
  bool _isNavigating = false;
  bool _isFetchingRoute = false;
  String? _routeError;
  double _routeDistanceKm = 0;
  int _robotWaypoint = 0;
  int _robotTotalWaypoints = 0;
  bool _gpsFix = false;

  // Out & Back / workout options
  bool _returnToStart = false;
  WorkoutPlan? _linkedWorkout;
  int _currentWorkoutStep = 0;

  bool _centeredOnce = false;

  StreamSubscription<RobotStatus>? _robotSub;
  StreamSubscription<Position>? _gpsSub;

  // ── Lifecycle ───────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _robot.startPolling();
    _robotSub = _robot.statusStream.listen(_onRobotStatus);
    _startGps();
  }

  @override
  void dispose() {
    _robotSub?.cancel();
    _gpsSub?.cancel();
    _robot.stopPolling();
    _mapController.dispose();
    super.dispose();
  }

  // ── Robot status ────────────────────────────────────────────────
  void _onRobotStatus(RobotStatus s) {
    if (!mounted) return;
    setState(() {
      if (s.gpsFix && (s.lat != 0 || s.lng != 0)) {
        _robotPos = ll.LatLng(s.lat, s.lng);
      }
      _isNavigating = s.isPacing;
      _robotWaypoint = s.waypoint;
      _robotTotalWaypoints = s.totalWaypoints;
      _gpsFix = s.gpsFix;

      // First time robot fix arrives → re-centre map on it if user hasn't moved
      if (!_centeredOnce && _robotPos != null) {
        _centeredOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(_robotPos!, 16);
        });
      }
    });

    // Workout step progression — outside setState so we can call async methods
    if (_linkedWorkout != null && _robotTotalWaypoints > 0 && s.isPacing) {
      _updateWorkoutStep();
    }
  }

  // ── User GPS ────────────────────────────────────────────────────
  Future<void> _startGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _userPos = ll.LatLng(pos.latitude, pos.longitude);
        if (!_centeredOnce) {
          _centeredOnce = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(_userPos!, 16);
          });
        }
      });

      _gpsSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((p) {
            if (!mounted) return;
            setState(() => _userPos = ll.LatLng(p.latitude, p.longitude));
          });
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  // ── Workout step progression ────────────────────────────────
  void _updateWorkoutStep() {
    final plan = _linkedWorkout;
    if (plan == null || _robotTotalWaypoints == 0) return;

    final totalDistM = _routeDistanceKm * 1000 * (_returnToStart ? 2.0 : 1.0);
    final coveredDistM = (_robotWaypoint / _robotTotalWaypoints) * totalDistM;

    // Find which workout step we're currently in by cumulative distance
    double cumDist = 0;
    int newStep = plan.steps.length - 1;
    for (int i = 0; i < plan.steps.length; i++) {
      cumDist += plan.steps[i].estimatedMetres;
      if (coveredDistM < cumDist) {
        newStep = i;
        break;
      }
    }

    if (newStep != _currentWorkoutStep) {
      setState(() => _currentWorkoutStep = newStep);
      final step = plan.steps[newStep];
      if (step.targetPaceKmh > 0) {
        _robot.updatePace(step.targetPaceKmh);
      }
    }
  }

  // ── Routing via OSRM ────────────────────────────────────────────
  Future<void> _fetchRoute() async {
    final origin = _robotPos ?? _userPos;
    if (origin == null || _destination == null) return;

    setState(() {
      _isFetchingRoute = true;
      _routeError = null;
      _routePoints = [];
      _routeDistanceKm = 0;
    });

    try {
      // OSRM public demo: foot profile (running).
      // Coordinates are {longitude},{latitude} — note reversed order.
      final url =
          'https://router.project-osrm.org/route/v1/foot/'
          '${origin.longitude},${origin.latitude};'
          '${_destination!.longitude},${_destination!.latitude}'
          '?overview=full&geometries=geojson';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0] as Map<String, dynamic>;
          final coords = (route['geometry']['coordinates'] as List)
              .cast<List>();
          final distM = (route['distance'] as num).toDouble();

          setState(() {
            _routePoints = coords
                .map(
                  (c) => ll.LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList();
            _routeDistanceKm = distM / 1000;
            _isFetchingRoute = false;
          });

          // Fit map to show the full route
          if (_routePoints.isNotEmpty) _fitRoute();
        } else {
          setState(() {
            _routeError = 'No route found to that location.';
            _isFetchingRoute = false;
          });
        }
      } else {
        setState(() {
          _routeError = 'Routing server error (${res.statusCode}).';
          _isFetchingRoute = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _routeError = 'Routing timed out. Check internet connection.';
        _isFetchingRoute = false;
      });
    } catch (e) {
      setState(() {
        _routeError = 'Could not calculate route.';
        _isFetchingRoute = false;
      });
    }
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;
    for (final p in _routePoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final sw = ll.LatLng(minLat, minLng);
    final ne = ll.LatLng(maxLat, maxLng);
    final bounds = LatLngBounds(sw, ne);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
    );
  }

  // ── Robot commands ──────────────────────────────────────────────
  Future<void> _sendToRobot() async {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No route yet — tap the map to set a destination first.',
          ),
        ),
      );
      return;
    }

    // Build full route: forward (+ reversed for Out & Back)
    List<ll.LatLng> fullRoute = List.of(_routePoints);
    if (_returnToStart && _routePoints.length > 1) {
      // Append reversed route (skip first point = destination to avoid duplicate)
      final returnLeg = _routePoints.reversed.skip(1).toList();
      fullRoute.addAll(returnLeg);
    }

    // Downsample to keep ESP32 payload manageable (≤200 pts)
    final waypoints = _downsample(
      fullRoute,
      maxPoints: 200,
    ).map((p) => LatLng(p.latitude, p.longitude)).toList();

    // Determine starting pace: first workout step or manual slider
    final startPace =
        (_linkedWorkout != null &&
            _linkedWorkout!.steps.isNotEmpty &&
            _linkedWorkout!.steps.first.targetPaceKmh > 0)
        ? _linkedWorkout!.steps.first.targetPaceKmh
        : _speedKmh;

    // Reset workout step counter
    setState(() => _currentWorkoutStep = 0);

    final ok = await _robot.startPacing(
      paceKmh: startPace,
      waypoints: waypoints,
    );
    if (!mounted) return;

    final routeDesc = _returnToStart ? 'Out & Back' : 'One-way';
    final workoutDesc = _linkedWorkout != null
        ? ' · ${_linkedWorkout!.name}'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✓ $routeDesc$workoutDesc — starting at ${startPace.toStringAsFixed(1)} km/h'
              : '✗ Could not reach robot — is it on and connected?',
        ),
        backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
      ),
    );
  }

  /// Open the WorkoutUploadScreen and capture the plan the user builds/imports.
  Future<void> _linkWorkout() async {
    final plan = await Navigator.push<WorkoutPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => const WorkoutUploadScreen(returnPlanOnly: true),
        fullscreenDialog: true,
      ),
    );
    if (plan != null && mounted) {
      setState(() {
        _linkedWorkout = plan;
        // Pre-set speed to first step pace for the slider readout
        if (plan.steps.isNotEmpty && plan.steps.first.targetPaceKmh > 0) {
          _speedKmh = plan.steps.first.targetPaceKmh;
        }
      });
    }
  }

  Future<void> _stopRobot() async {
    await _robot.stopPacing();
    setState(() => _isNavigating = false);
  }

  List<ll.LatLng> _downsample(List<ll.LatLng> pts, {required int maxPoints}) {
    if (pts.length <= maxPoints) return pts;
    final step = pts.length / maxPoints;
    final result = <ll.LatLng>[];
    for (int i = 0; i < maxPoints; i++) {
      result.add(pts[(i * step).round().clamp(0, pts.length - 1)]);
    }
    result.last = pts.last; // always include final point
    return result;
  }

  // ── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final initialCenter = _robotPos ?? _userPos ?? const ll.LatLng(51.5, -0.09);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Navigate Robot'),
        actions: [
          if (_robotPos != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                backgroundColor: _gpsFix
                    ? Colors.green.shade900
                    : Colors.grey.shade800,
                label: Text(
                  _gpsFix ? 'GPS Fix' : 'No GPS',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                avatar: Icon(
                  Icons.gps_fixed,
                  size: 14,
                  color: _gpsFix ? Colors.greenAccent : Colors.grey,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBanner(),
          Expanded(child: _buildMap(initialCenter)),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    if (_isNavigating && _robotTotalWaypoints > 0) {
      final pct = _robotTotalWaypoints > 0
          ? (_robotWaypoint / _robotTotalWaypoints).clamp(0.0, 1.0)
          : 0.0;

      // Workout step strip (shown above progress bar when workout is linked)
      final workoutStrip =
          _linkedWorkout != null && _linkedWorkout!.steps.isNotEmpty
          ? () {
              final step =
                  _linkedWorkout!.steps[_currentWorkoutStep.clamp(
                    0,
                    _linkedWorkout!.steps.length - 1,
                  )];
              final stepColor = Color(step.colorValue);
              return Container(
                color: stepColor.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    Icon(Icons.fitness_center, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Step ${_currentWorkoutStep + 1}/${_linkedWorkout!.steps.length}  ·  ${step.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      step.paceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }()
          : null;

      // Out & Back midpoint indicator
      final midpointLabel = _returnToStart
          ? (_robotWaypoint / _robotTotalWaypoints < 0.5
                ? '→ Outbound'
                : '← Returning to start')
          : null;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (workoutStrip != null) workoutStrip,
          Container(
            color: Colors.green.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.directions_run, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  midpointLabel ??
                      'Navigating — waypoint $_robotWaypoint / $_robotTotalWaypoints',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_destination == null) {
      return Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            Icon(Icons.touch_app, color: Colors.orange, size: 18),
            SizedBox(width: 10),
            Text(
              'Tap anywhere on the map to set a destination',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_isFetchingRoute) {
      return Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Calculating route…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_routeError != null) {
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _routeError!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _fetchRoute,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_routePoints.isNotEmpty) {
      final totalDist = _routeDistanceKm * (_returnToStart ? 2.0 : 1.0);
      final displayPace =
          (_linkedWorkout != null &&
              _linkedWorkout!.steps.isNotEmpty &&
              _linkedWorkout!.steps.first.targetPaceKmh > 0)
          ? _linkedWorkout!.steps.first.targetPaceKmh
          : _speedKmh;
      final etaMins = (totalDist / displayPace * 60).round();
      final routeLabel = _returnToStart ? 'Out & Back' : 'One-way';
      return Container(
        color: const Color(0xFF1565C0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.route, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              '$routeLabel  ${totalDist.toStringAsFixed(2)} km  ·  ~$etaMins min',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _destination = null;
                _routePoints = [];
                _routeDistanceKm = 0;
              }),
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMap(ll.LatLng initialCenter) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 16,
        onTap: (tapPos, point) {
          setState(() {
            _destination = point;
            _routePoints = [];
            _routeDistanceKm = 0;
            _routeError = null;
          });
          _fetchRoute();
        },
        interactionOptions: const InteractionOptions(
          flags:
              InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        // ── Tiles ──────────────────────────────────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.runnercompanion.run_companion',
          maxZoom: 19,
        ),

        // ── Route polyline ──────────────────────────────────────────
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.5,
                color: Colors.blueAccent,
              ),
            ],
          ),

        // ── Markers ─────────────────────────────────────────────────
        MarkerLayer(
          markers: [
            // User position
            if (_userPos != null)
              Marker(
                point: _userPos!,
                width: 40,
                height: 40,
                child: _buildDotMarker(Colors.blue.shade300, Icons.person),
              ),

            // Robot position
            if (_robotPos != null)
              Marker(
                point: _robotPos!,
                width: 44,
                height: 44,
                child: _buildDotMarker(
                  Colors.orangeAccent,
                  Icons.smart_toy_rounded,
                ),
              ),

            // Destination pin
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 40,
                height: 56,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDotMarker(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _buildBottomPanel() {
    final canSend = _routePoints.isNotEmpty && !_isNavigating;
    final totalDist = _routeDistanceKm * (_returnToStart ? 2.0 : 1.0);
    final displayPace =
        (_linkedWorkout != null &&
            _linkedWorkout!.steps.isNotEmpty &&
            _linkedWorkout!.steps.first.targetPaceKmh > 0)
        ? _linkedWorkout!.steps.first.targetPaceKmh
        : _speedKmh;
    final etaMins = (totalDist > 0 && displayPace > 0)
        ? (totalDist / displayPace * 60).round()
        : 0;
    final paceStr = _speedKmh > 0
        ? () {
            final mpm = 60 / _speedKmh;
            final m = mpm.floor();
            final s = ((mpm - m) * 60).round();
            return '$m:${s.toString().padLeft(2, '0')}/km';
          }()
        : '--';

    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Out & Back + Link Workout row ─────────────────────────
          Row(
            children: [
              // Out & Back toggle
              GestureDetector(
                onTap: () => setState(() => _returnToStart = !_returnToStart),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _returnToStart
                        ? Colors.deepPurple.shade700
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _returnToStart
                          ? Colors.deepPurple.shade300
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: _returnToStart
                            ? Colors.deepPurple.shade100
                            : Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Out & Back',
                        style: TextStyle(
                          color: _returnToStart
                              ? Colors.deepPurple.shade100
                              : Colors.white54,
                          fontSize: 13,
                          fontWeight: _returnToStart
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Link Workout button
              Expanded(
                child: GestureDetector(
                  onTap: _linkWorkout,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _linkedWorkout != null
                          ? Colors.teal.shade800
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _linkedWorkout != null
                            ? Colors.tealAccent.shade100
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _linkedWorkout != null
                              ? Icons.check_circle_outline
                              : Icons.fitness_center,
                          color: _linkedWorkout != null
                              ? Colors.tealAccent
                              : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _linkedWorkout != null
                                ? _linkedWorkout!.name
                                : 'Link Workout',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _linkedWorkout != null
                                  ? Colors.tealAccent
                                  : Colors.white54,
                              fontSize: 13,
                              fontWeight: _linkedWorkout != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_linkedWorkout != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _linkedWorkout = null),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white38,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Linked workout step summary
          if (_linkedWorkout != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _linkedWorkout!.steps.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, i) {
                  final step = _linkedWorkout!.steps[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Color(step.colorValue).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${step.name} ${step.paceLabel}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Speed slider (hidden when workout controls pace) ──────
          if (_linkedWorkout == null)
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.white54, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.orangeAccent,
                      thumbColor: Colors.orangeAccent,
                      inactiveTrackColor: Colors.white12,
                      overlayColor: Colors.orange.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _speedKmh,
                      min: 5,
                      max: 30,
                      divisions: 25,
                      onChanged: (v) => setState(() => _speedKmh = v),
                      onChangeEnd: (_) {
                        if (_isNavigating) _robot.updatePace(_speedKmh);
                        if (_routePoints.isNotEmpty) setState(() {});
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_speedKmh.toStringAsFixed(1)} km/h',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        paceStr,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (_linkedWorkout != null) const SizedBox(height: 4),

          // ── Action buttons ────────────────────────────────────────
          Row(
            children: [
              // Centre map on robot
              IconButton(
                tooltip: 'Centre map on robot',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white70,
                ),
                icon: const Icon(Icons.smart_toy_rounded, size: 20),
                onPressed: _robotPos != null
                    ? () => _mapController.move(_robotPos!, 16)
                    : null,
              ),
              const SizedBox(width: 8),

              // Centre map on user
              IconButton(
                tooltip: 'Centre map on me',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white70,
                ),
                icon: const Icon(Icons.my_location, size: 20),
                onPressed: _userPos != null
                    ? () => _mapController.move(_userPos!, 16)
                    : null,
              ),
              const SizedBox(width: 12),

              // Send / Stop
              Expanded(
                child: _isNavigating
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _stopRobot,
                        icon: const Icon(Icons.stop),
                        label: const Text(
                          'Stop Robot',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSend
                              ? Colors.green.shade700
                              : Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: canSend ? _sendToRobot : null,
                        icon: const Icon(Icons.navigation_rounded),
                        label: Text(
                          _destination == null
                              ? 'Tap map to set destination'
                              : _routePoints.isEmpty
                              ? _isFetchingRoute
                                    ? 'Calculating…'
                                    : 'No route yet'
                              : 'Send to Robot${etaMins > 0 ? '  (~$etaMins min)' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
