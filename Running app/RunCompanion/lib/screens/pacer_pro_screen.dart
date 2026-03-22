import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/garmin_service.dart';
import '../services/firestore_service.dart';
import '../services/voice_service.dart';
import '../services/background_service.dart';
import 'ai_chat_screen.dart';

// ── Heart-rate zones (5-zone model) ─────────────────────────────────────────
class _HrZone {
  final String name;
  final Color color;
  final double minFraction; // fraction of max HR
  final double maxFraction;
  const _HrZone(this.name, this.color, this.minFraction, this.maxFraction);
}

const _hrZones = [
  _HrZone('Z1 Recovery', Color(0xFF64B5F6), 0.50, 0.60),
  _HrZone('Z2 Aerobic', Color(0xFF81C784), 0.60, 0.70),
  _HrZone('Z3 Tempo', Color(0xFFFFD54F), 0.70, 0.80),
  _HrZone('Z4 Threshold', Color(0xFFFF8A65), 0.80, 0.90),
  _HrZone('Z5 Max', Color(0xFFE57373), 0.90, 1.00),
];

_HrZone? _zoneFor(int hr, int maxHr) {
  if (hr <= 0 || maxHr <= 0) return null;
  final f = hr / maxHr;
  for (final z in _hrZones) {
    if (f >= z.minFraction && f < z.maxFraction) return z;
  }
  if (f >= _hrZones.last.maxFraction) return _hrZones.last;
  return null;
}

// ── Interval step model ──────────────────────────────────────────────────────
class IntervalStep {
  final String label; // 'Work' | 'Rest'
  final int durationSeconds;
  final double paceKmh; // 0 = same as base pace
  const IntervalStep({
    required this.label,
    required this.durationSeconds,
    required this.paceKmh,
  });
}

// ── Screen ───────────────────────────────────────────────────────────────────
class PacerProScreen extends StatefulWidget {
  const PacerProScreen({super.key});

  @override
  State<PacerProScreen> createState() => _PacerProScreenState();
}

class _PacerProScreenState extends State<PacerProScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final _garminService = GarminService();
  final _firestoreService = FirestoreService();
  final _voiceService = VoiceService();
  final _bgService = BackgroundService.instance;

  // ── Settings ───────────────────────────────────────────────────────────────
  double _targetPaceKmh = 10.0; // default: 10 km/h = 6:00 /km
  int _maxHeartRate = 190; // used for HR zone calculation
  bool _intervalMode = false;
  // Work / Rest intervals (seconds + pace multiplier)
  int _workSecs = 240; // 4 min work
  double _workPaceKmh = 12.0; // work pace
  int _restSecs = 60; // 1 min rest
  double _restPaceKmh = 7.0; // rest jog pace

  // ── Workout state ──────────────────────────────────────────────────────────
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  Timer? _clockTimer;

  // GPS
  StreamSubscription<Position>? _gpsSub;
  double _currentSpeedKmh = 0; // from GPS
  double _distanceKm = 0;
  Position? _lastPos;

  // Garmin
  GarminData _garminData = const GarminData();
  bool _garminScanning = false;

  // Heart rate samples
  final List<int> _hrSamples = [];
  final List<int> _maxHrSamples = [];
  final List<int> _cadenceSamples = [];

  // Interval tracking
  int _intervalStepIndex = 0;
  Duration _intervalElapsed = Duration.zero;
  List<IntervalStep> get _intervalSteps => [
    IntervalStep(label: 'Work', durationSeconds: _workSecs, paceKmh: _workPaceKmh),
    IntervalStep(label: 'Rest', durationSeconds: _restSecs, paceKmh: _restPaceKmh),
  ];
  IntervalStep get _currentStep =>
      _intervalSteps[_intervalStepIndex % _intervalSteps.length];
  double get _activePaceKmh =>
      _intervalMode ? _currentStep.paceKmh : _targetPaceKmh;

  // Km announcements
  int _lastKmAnnounced = 0;

  // Pace gauge animation
  late final AnimationController _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _gaugeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _voiceService.init();
    _garminService.dataStream.listen((data) {
      if (mounted) {
        setState(() => _garminData = data);
        if (_isRunning && !_isPaused) {
          if (data.heartRate > 0) {
            _hrSamples.add(data.heartRate);
            _maxHrSamples.add(data.heartRate);
          }
          if (data.cadence > 0) _cadenceSamples.add(data.cadence);
        }
      }
    });
  }

  @override
  void dispose() {
    _gaugeAnim.dispose();
    _voiceService.dispose();
    _garminService.dispose();
    _gpsSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<bool> _ensureGpsPermission() async {
    if (kIsWeb) return false; // GPS via JS geolocation — not needed here
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showSnack('Please enable location services.', color: Colors.red);
      return false;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showSnack('Location permission required.', color: Colors.red);
      return false;
    }
    return true;
  }

  void _startGps() {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // update every 3 m
      ),
    ).listen((pos) {
      if (!mounted || !_isRunning || _isPaused) return;
      setState(() {
        _currentSpeedKmh = pos.speed * 3.6; // m/s → km/h
        if (_lastPos != null) {
          _distanceKm += Geolocator.distanceBetween(
                _lastPos!.latitude,
                _lastPos!.longitude,
                pos.latitude,
                pos.longitude,
              ) /
              1000.0;
        }
        _lastPos = pos;
      });
    }, onError: (_) {});
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _currentSpeedKmh = 0;
  }

  // ── Garmin ─────────────────────────────────────────────────────────────────

  Future<void> _toggleGarmin() async {
    if (_garminData.connected) {
      await _garminService.disconnect();
      return;
    }
    setState(() => _garminScanning = true);
    final ok = await _garminService.autoConnect();
    if (mounted) {
      setState(() => _garminScanning = false);
      if (!ok) {
        _showSnack(
          'Could not find a Garmin watch. Make sure\nBluetooth is on and your watch is nearby.',
          color: Colors.orange,
        );
      }
    }
  }

  // ── Workout start / stop / pause ──────────────────────────────────────────

  Future<void> _startWorkout() async {
    final gpsOk = await _ensureGpsPermission();
    if (!gpsOk && !kIsWeb) return;

    _hrSamples.clear();
    _maxHrSamples.clear();
    _cadenceSamples.clear();
    _distanceKm = 0;
    _lastPos = null;
    _lastKmAnnounced = 0;
    _intervalStepIndex = 0;
    _intervalElapsed = Duration.zero;
    _startTime = DateTime.now();

    _startGps();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() {
        _elapsedTime = DateTime.now().difference(_startTime!);

        // ── Interval step advancement ────────────────────────────
        if (_intervalMode) {
          _intervalElapsed += const Duration(seconds: 1);
          final stepSecs = _currentStep.durationSeconds;
          if (_intervalElapsed.inSeconds >= stepSecs) {
            _intervalElapsed = Duration.zero;
            _intervalStepIndex++;
            final next = _currentStep;
            _voiceService.speak(
              '${next.label} interval — '
              '${_kmhToPaceStr(next.paceKmh)} for '
              '${_secsToMinStr(next.durationSeconds)}. Go!',
            );
          }
        }

        // ── Km milestone announcements ───────────────────────────
        final kmDone = _distanceKm.floor();
        if (kmDone > _lastKmAnnounced && kmDone > 0) {
          _lastKmAnnounced = kmDone;
          _voiceService.announceKmMilestone(kmDone);
        }

        // ── Background notification ──────────────────────────────
        final liveHr = _garminData.heartRate;
        final dist = _garminData.distanceKm > 0
            ? _garminData.distanceKm
            : _distanceKm;
        _bgService.updateStats(
          paceKmh: _activePaceKmh,
          elapsed: _elapsedTime,
          heartRate: liveHr,
          distanceKm: dist,
          cadence: _garminData.cadence,
        );
      });
    });

    _bgService.startWorkout(paceKmh: _activePaceKmh);
    _voiceService.announceWorkoutStart(_activePaceKmh);

    setState(() {
      _isRunning = true;
      _isPaused = false;
      _elapsedTime = Duration.zero;
    });

    _gaugeAnim.repeat(reverse: true);
  }

  void _pauseWorkout() {
    setState(() => _isPaused = true);
    _gaugeAnim.stop();
    _voiceService.speak('Workout paused.');
  }

  void _resumeWorkout() {
    setState(() {
      _isPaused = false;
      // Adjust start time so elapsed doesn't jump
      _startTime = DateTime.now().subtract(_elapsedTime);
    });
    _gaugeAnim.repeat(reverse: true);
    _voiceService.speak('Resuming — keep it up!');
  }

  Future<void> _stopWorkout() async {
    _clockTimer?.cancel();
    _stopGps();
    _gaugeAnim.stop();

    final avgHr = _hrSamples.isNotEmpty
        ? (_hrSamples.reduce((a, b) => a + b) ~/ _hrSamples.length)
        : null;
    final maxHr = _maxHrSamples.isNotEmpty
        ? _maxHrSamples.reduce((a, b) => a > b ? a : b)
        : null;
    final avgCadence = _cadenceSamples.isNotEmpty
        ? (_cadenceSamples.reduce((a, b) => a + b) ~/ _cadenceSamples.length)
        : null;
    final dist = _garminData.distanceKm > 0
        ? _garminData.distanceKm
        : _distanceKm;

    await _firestoreService.saveRunSession(
      mode: _intervalMode
          ? 'Pacer Pro — Intervals'
          : 'Pacer Pro — ${_kmhToPaceStr(_targetPaceKmh)}',
      startTime: _startTime ?? DateTime.now(),
      duration: _elapsedTime,
      distanceKm: dist,
      avgHeartRate: avgHr,
      maxHeartRate: maxHr,
      avgCadence: avgCadence,
      paceKmh: _targetPaceKmh,
    );

    _voiceService.announceWorkoutStop(_elapsedTime, dist);
    _bgService.stopWorkout();

    setState(() {
      _isRunning = false;
      _isPaused = false;
      _elapsedTime = Duration.zero;
      _distanceKm = 0;
      _currentSpeedKmh = 0;
      _intervalStepIndex = 0;
      _intervalElapsed = Duration.zero;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _kmhToPaceStr(double kmh) {
    if (kmh < 0.5) return '--:--';
    final minsPerKm = 60.0 / kmh;
    final m = minsPerKm.floor();
    final s = ((minsPerKm - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  String _secsToMinStr(int secs) {
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60;
    final s = secs % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  void _showSnack(String msg, {Color color = Colors.teal}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.timer_rounded, color: Color(0xFF58A6FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Pacer Pro',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            SizedBox(width: 8),
            _ProBadge(),
          ],
        ),
        actions: [
          // Garmin connect toggle
          GestureDetector(
            onTap: _toggleGarmin,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _garminData.connected
                    ? const Color(0xFF00C853).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _garminData.connected
                      ? const Color(0xFF00C853)
                      : Colors.white30,
                  width: 1.2,
                ),
              ),
              child: _garminScanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.watch_rounded,
                          size: 13,
                          color: _garminData.connected
                              ? const Color(0xFF00C853)
                              : Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _garminData.connected ? 'Watch' : 'Watch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _garminData.connected
                                ? const Color(0xFF00C853)
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          // AI coach button
          if (_isRunning)
            IconButton(
              icon: const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF58A6FF)),
              tooltip: 'AI Coach',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiChatScreen(
                    workoutContext: WorkoutContext(
                      isRunning: _isRunning,
                      elapsed: _elapsedTime,
                      paceKmh: _activePaceKmh,
                      distanceKm: _distanceKm,
                      heartRate: _garminData.heartRate,
                      cadence: _garminData.cadence,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isRunning ? _buildRunningView() : _buildSetupView(),
    );
  }

  // ── Setup View ─────────────────────────────────────────────────────────────

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Target pace card ───────────────────────────────────
          _SectionCard(
            title: 'Target Pace',
            icon: Icons.speed,
            child: Column(
              children: [
                Text(
                  _kmhToPaceStr(_targetPaceKmh),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF58A6FF),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '${_targetPaceKmh.toStringAsFixed(1)} km/h',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF58A6FF),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: const Color(0xFF58A6FF),
                    overlayColor:
                        const Color(0xFF58A6FF).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    min: 4,
                    max: 25,
                    divisions: 42,
                    value: _targetPaceKmh,
                    onChanged: (v) =>
                        setState(() => _targetPaceKmh = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PaceButton(
                      label: '−0.5',
                      onTap: () => setState(() => _targetPaceKmh =
                          (_targetPaceKmh - 0.5).clamp(4.0, 25.0)),
                    ),
                    const SizedBox(width: 12),
                    _PaceButton(
                      label: '+0.5',
                      onTap: () => setState(() => _targetPaceKmh =
                          (_targetPaceKmh + 0.5).clamp(4.0, 25.0)),
                    ),
                    const SizedBox(width: 12),
                    _PaceButton(
                      label: '−1',
                      onTap: () => setState(() => _targetPaceKmh =
                          (_targetPaceKmh - 1.0).clamp(4.0, 25.0)),
                    ),
                    const SizedBox(width: 12),
                    _PaceButton(
                      label: '+1',
                      onTap: () => setState(() => _targetPaceKmh =
                          (_targetPaceKmh + 1.0).clamp(4.0, 25.0)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Interval mode card ─────────────────────────────────
          _SectionCard(
            title: 'Interval Training',
            icon: Icons.repeat_rounded,
            trailing: Switch(
              value: _intervalMode,
              onChanged: (v) => setState(() => _intervalMode = v),
              activeColor: const Color(0xFF58A6FF),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _intervalMode
                  ? _buildIntervalEditor()
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Max HR card ────────────────────────────────────────
          _SectionCard(
            title: 'Max Heart Rate',
            icon: Icons.favorite_rounded,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_maxHeartRate bpm',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B6B),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFF6B6B),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: const Color(0xFFFF6B6B),
                    overlayColor:
                        const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    min: 150,
                    max: 220,
                    divisions: 70,
                    value: _maxHeartRate.toDouble(),
                    onChanged: (v) =>
                        setState(() => _maxHeartRate = v.round()),
                  ),
                ),
                const Text(
                  'Used for heart rate zone display',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── HR zone legend ─────────────────────────────────────
          _buildHrZoneLegend(),
          const SizedBox(height: 32),

          // ── Start button ───────────────────────────────────────
          FilledButton.icon(
            onPressed: _startWorkout,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 26),
            label: Text(
              _intervalMode ? 'Start Intervals' : 'Start Run',
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildIntervalEditor() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          _IntervalRow(
            label: 'Work',
            color: const Color(0xFF58A6FF),
            durationSecs: _workSecs,
            paceKmh: _workPaceKmh,
            paceStr: _kmhToPaceStr(_workPaceKmh),
            onDurationChanged: (v) => setState(() => _workSecs = v),
            onPaceChanged: (v) => setState(() => _workPaceKmh = v),
          ),
          const SizedBox(height: 8),
          _IntervalRow(
            label: 'Rest',
            color: const Color(0xFF56D364),
            durationSecs: _restSecs,
            paceKmh: _restPaceKmh,
            paceStr: _kmhToPaceStr(_restPaceKmh),
            onDurationChanged: (v) => setState(() => _restSecs = v),
            onPaceChanged: (v) => setState(() => _restPaceKmh = v),
          ),
        ],
      ),
    );
  }

  Widget _buildHrZoneLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HEART RATE ZONES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _hrZones
              .map(
                (z) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: z.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: z.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          z.name.split(' ').first,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: z.color,
                          ),
                        ),
                        Text(
                          '${(z.minFraction * _maxHeartRate).round()}–'
                          '${(z.maxFraction * _maxHeartRate).round()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ── Running View ───────────────────────────────────────────────────────────

  Widget _buildRunningView() {
    final liveKmh = _garminData.connected && _garminData.speedKmh > 0
        ? _garminData.speedKmh
        : _currentSpeedKmh;
    final activeTarget = _activePaceKmh;
    final paceGap = liveKmh - activeTarget; // + = ahead, - = behind
    final zone = _zoneFor(_garminData.heartRate, _maxHeartRate);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Big pace gauge ─────────────────────────────────────────
          Container(
            color: const Color(0xFF161B22),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                _PaceGauge(
                  currentKmh: liveKmh,
                  targetKmh: activeTarget,
                  paceGap: paceGap,
                  paceStr: _kmhToPaceStr(liveKmh),
                  targetPaceStr: _kmhToPaceStr(activeTarget),
                ),
                const SizedBox(height: 16),
                // Pace deviation indicator
                _PaceDeviationBar(paceGap: paceGap),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Live stats strip ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: 'Time',
                  value: _formatDuration(_elapsedTime),
                  color: const Color(0xFF58A6FF),
                ),
                _StatChip(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: _distanceKm < 1
                      ? '${(_distanceKm * 1000).round()} m'
                      : '${_distanceKm.toStringAsFixed(2)} km',
                  color: const Color(0xFF56D364),
                ),
                _StatChip(
                  icon: Icons.favorite_rounded,
                  label: 'HR',
                  value: _garminData.heartRate > 0
                      ? '${_garminData.heartRate} bpm'
                      : '--',
                  color: zone?.color ?? const Color(0xFFFF6B6B),
                ),
                _StatChip(
                  icon: Icons.accessibility_new,
                  label: 'Cadence',
                  value: _garminData.cadence > 0
                      ? '${_garminData.cadence} spm'
                      : '--',
                  color: const Color(0xFFE2B714),
                ),
              ],
            ),
          ),

          // ── HR zone banner ─────────────────────────────────────────
          if (zone != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: zone.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: zone.color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: zone.color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    zone.name,
                    style: TextStyle(
                      color: zone.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_garminData.heartRate / _maxHeartRate * 100).toStringAsFixed(0)}% max',
                    style: TextStyle(color: zone.color, fontSize: 13),
                  ),
                ],
              ),
            ),

          // ── Interval progress ──────────────────────────────────────
          if (_intervalMode) _buildIntervalProgress(),

          const SizedBox(height: 16),

          // ── Controls ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                // Pause / Resume
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPaused ? _resumeWorkout : _pauseWorkout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                          color: Colors.white30, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      _isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 22,
                    ),
                    label: Text(_isPaused ? 'Resume' : 'Pause'),
                  ),
                ),
                const SizedBox(width: 12),
                // Stop
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirmStop,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDA3633),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 22),
                    label: const Text('Finish'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Pace adjustment ────────────────────────────────────────
          if (!_intervalMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PaceAdjustRow(
                targetPaceKmh: _targetPaceKmh,
                paceStr: _kmhToPaceStr(_targetPaceKmh),
                onAdjust: (delta) => setState(
                  () => _targetPaceKmh =
                      (_targetPaceKmh + delta).clamp(4.0, 25.0),
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntervalProgress() {
    final step = _currentStep;
    final stepTotal = step.durationSeconds;
    final stepElapsed = _intervalElapsed.inSeconds;
    final progress = (stepTotal > 0 ? stepElapsed / stepTotal : 0.0).clamp(
      0.0,
      1.0,
    );
    final remaining = Duration(
      seconds: (stepTotal - stepElapsed).clamp(0, stepTotal),
    );
    final color = step.label == 'Work'
        ? const Color(0xFF58A6FF)
        : const Color(0xFF56D364);
    final round = (_intervalStepIndex ~/ 2) + 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                step.label == 'Work'
                    ? Icons.bolt_rounded
                    : Icons.self_improvement_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${step.label}  •  Round $round',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(remaining),
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Target: ${_kmhToPaceStr(step.paceKmh)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Finish run?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Distance: ${_distanceKm.toStringAsFixed(2)} km\n'
          'Time: ${_formatDuration(_elapsedTime)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going',
                style: TextStyle(color: Color(0xFF58A6FF))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDA3633)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (ok == true) await _stopWorkout();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProBadge extends StatelessWidget {
  const _ProBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF58A6FF), Color(0xFF388BFD)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF58A6FF), size: 16),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PaceButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PaceButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF58A6FF),
        side: const BorderSide(color: Color(0xFF30363D)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label,
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final String label;
  final Color color;
  final int durationSecs;
  final double paceKmh;
  final String paceStr;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<double> onPaceChanged;

  const _IntervalRow({
    required this.label,
    required this.color,
    required this.durationSecs,
    required this.paceKmh,
    required this.paceStr,
    required this.onDurationChanged,
    required this.onPaceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Label
        Container(
          width: 50,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        // Duration chip
        Expanded(
          child: Column(
            children: [
              Text(
                _secsLabel(durationSecs),
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              Slider(
                min: 30,
                max: 1800,
                divisions: 59,
                value: durationSecs.toDouble(),
                activeColor: color,
                inactiveColor: Colors.white12,
                onChanged: (v) => onDurationChanged(v.round()),
              ),
              const Text(
                'Duration',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        // Pace chip
        Expanded(
          child: Column(
            children: [
              Text(
                paceStr,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              Slider(
                min: 4,
                max: 25,
                divisions: 42,
                value: paceKmh,
                activeColor: color,
                inactiveColor: Colors.white12,
                onChanged: onPaceChanged,
              ),
              const Text(
                'Pace',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _secsLabel(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    return r == 0 ? '${m}m' : '${m}m${r}s';
  }
}

// ── Pace gauge (big circular display) ────────────────────────────────────────

class _PaceGauge extends StatelessWidget {
  final double currentKmh;
  final double targetKmh;
  final double paceGap;
  final String paceStr;
  final String targetPaceStr;

  const _PaceGauge({
    required this.currentKmh,
    required this.targetKmh,
    required this.paceGap,
    required this.paceStr,
    required this.targetPaceStr,
  });

  @override
  Widget build(BuildContext context) {
    final onPace = paceGap.abs() < 0.5;
    final tooFast = paceGap > 0.5;
    final ringColor = onPace
        ? const Color(0xFF56D364)
        : tooFast
            ? const Color(0xFFE2B714)
            : const Color(0xFFFF6B6B);

    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _GaugePainter(
          currentKmh: currentKmh,
          targetKmh: targetKmh,
          ringColor: ringColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentKmh > 0 ? paceStr : '--:--',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: ringColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                'CURRENT PACE',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '⦿ $targetPaceStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double currentKmh;
  final double targetKmh;
  final Color ringColor;

  const _GaugePainter({
    required this.currentKmh,
    required this.targetKmh,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    // Progress arc (fill based on ratio current/target)
    final ratio = targetKmh > 0
        ? (currentKmh / targetKmh).clamp(0.0, 1.5)
        : 0.0;
    final sweep = 2 * pi * ratio.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.currentKmh != currentKmh ||
      old.targetKmh != targetKmh ||
      old.ringColor != ringColor;
}

// ── Pace deviation bar ────────────────────────────────────────────────────────

class _PaceDeviationBar extends StatelessWidget {
  final double paceGap; // + = runner faster than target, - = slower

  const _PaceDeviationBar({required this.paceGap});

  @override
  Widget build(BuildContext context) {
    final clamped = paceGap.clamp(-5.0, 5.0);
    final fraction = (clamped + 5.0) / 10.0; // 0–1
    final onPace = paceGap.abs() < 0.5;
    final barColor = onPace
        ? const Color(0xFF56D364)
        : paceGap > 0
            ? const Color(0xFFE2B714)
            : const Color(0xFFFF6B6B);
    final label = onPace
        ? 'On Pace'
        : paceGap > 0
            ? '+${paceGap.toStringAsFixed(1)} km/h (too fast)'
            : '${paceGap.toStringAsFixed(1)} km/h (too slow)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                onPace
                    ? Icons.check_circle_outline
                    : paceGap > 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                color: barColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: barColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              // Track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Center marker
              Positioned(
                left: MediaQuery.of(context).size.width / 2 - 24 - 1,
                child: Container(
                  width: 2,
                  height: 8,
                  color: Colors.white30,
                ),
              ),
              // Indicator
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Slow', style: TextStyle(color: Colors.white30, fontSize: 10)),
              Text('On Target', style: TextStyle(color: Colors.white30, fontSize: 10)),
              Text('Fast', style: TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Pace adjust row ───────────────────────────────────────────────────────────

class _PaceAdjustRow extends StatelessWidget {
  final double targetPaceKmh;
  final String paceStr;
  final ValueChanged<double> onAdjust;

  const _PaceAdjustRow({
    required this.targetPaceKmh,
    required this.paceStr,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _AdjBtn(label: '−1', onTap: () => onAdjust(-1.0)),
          _AdjBtn(label: '−0.5', onTap: () => onAdjust(-0.5)),
          Column(
            children: [
              Text(
                paceStr,
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Target',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          _AdjBtn(label: '+0.5', onTap: () => onAdjust(0.5)),
          _AdjBtn(label: '+1', onTap: () => onAdjust(1.0)),
        ],
      ),
    );
  }
}

class _AdjBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AdjBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF58A6FF),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
