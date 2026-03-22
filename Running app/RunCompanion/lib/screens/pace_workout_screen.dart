import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/robot_service.dart';
import '../services/camera_recording_service.dart';
import '../services/firestore_service.dart';
import '../services/garmin_service.dart';
import '../services/voice_service.dart';
import '../services/ai_service.dart';
import '../services/background_service.dart';
import '../services/runner_alert_service.dart';
import 'ai_chat_screen.dart';
import 'runner_alert_screen.dart';

class PaceWorkoutScreen extends StatefulWidget {
  const PaceWorkoutScreen({super.key});

  @override
  State<PaceWorkoutScreen> createState() => _PaceWorkoutScreenState();
}

class _PaceWorkoutScreenState extends State<PaceWorkoutScreen> {
  final _robotService = RobotService();
  final _firestoreService = FirestoreService();
  final _garminService = GarminService();
  final _cameraRecording = CameraRecordingService(); // robot camera recorder
  CameraRecordingStatus _cameraStatus = CameraRecordingStatus.idle();

  // Settings
  double _targetPaceKmh = 8.0; // 8 km/h = ~7:30 min/km
  final List<LatLng> _waypoints = [];

  // Live workout state
  bool _isRunning = false;
  bool _isConnected = false;
  RobotStatus? _robotStatus;
  Duration _elapsedTime = Duration.zero;
  Timer? _elapsedTimer;
  DateTime? _startTime;

  // Garmin live data
  GarminData _garminData = const GarminData();
  bool _garminScanning = false;
  // Running heart rate / cadence samples for averaging
  final List<int> _hrSamples = [];
  final List<int> _cadenceSamples = [];

  // Voice & AI
  final _voiceService = VoiceService();
  final _aiService = AiService();
  final _bgService = BackgroundService.instance;
  final _alertService = RunnerAlertService.instance;
  bool _voiceListening = false;
  Timer? _encouragementTimer;
  int _lastKmAnnounced = 0;
  bool _batteryWarnedCritical = false; // prevent repeat critical warnings
  bool _hadObstacleAhead = false; // track obstacle → cleared → say thank you
  bool _wasTipped = false; // track tipped → righted → announce recovery
  bool _halfwayAnnouncedReturn =
      false; // suggest return-to-start once at halfway

  // For adding a simple destination (lat/lng)
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _robotService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _robotStatus = status);

        // ── Self-righting ─────────────────────────────────────────
        if (status.needsSelfRighting && !_wasTipped) {
          _wasTipped = true;
          _robotService.sendCommand('self_right');
          _voiceService.speak(
            'Oh no, the robot has tipped over! Attempting to self-right now. Please stand by.',
          );
        } else if (!status.needsSelfRighting && _wasTipped) {
          _wasTipped = false;
          _voiceService.speak(
            'Great news! The robot has righted itself and is back on track. Let\'s keep going!',
          );
        }

        // ── Thank you after obstacle clears ───────────────────────
        if (_isRunning) {
          if (status.obstacleAhead) {
            _hadObstacleAhead = true;
          } else if (_hadObstacleAhead) {
            _hadObstacleAhead = false;
            _voiceService.speak(
              'Thank you so much for making way! Really appreciate it. Keep it up!',
            );
          }
        }

        // ── Halfway suggestion ──────────────────────────────────
        if (_isRunning &&
            !_halfwayAnnouncedReturn &&
            status.progress >= 0.5 &&
            _waypoints.length >= 2) {
          _halfwayAnnouncedReturn = true;
          _voiceService.speak(
            'Great work! You have reached the halfway mark. '
            'Would you like to head back to the start? '
            'Just say \'head back\' and I will guide you home!',
          );
        }

        // ── Battery critical warning ──────────────────────────────
        if (_isRunning && status.isBatteryCritical && !_batteryWarnedCritical) {
          _batteryWarnedCritical = true;
          _announceBattery(status, forceWarn: true);
        }
      }
    });
    _garminService.dataStream.listen((data) {
      if (mounted) {
        setState(() => _garminData = data);
        if (_isRunning) {
          if (data.heartRate > 0) _hrSamples.add(data.heartRate);
          if (data.cadence > 0) _cadenceSamples.add(data.cadence);
        }
      }
    });
    // Try connecting immediately
    _checkConnection();
    _voiceService.init();
    _aiService.init();
    // Camera recording status
    _cameraRecording.statusStream.listen((s) {
      if (mounted) setState(() => _cameraStatus = s);
      if (s.state == CameraRecordingState.saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u2713 Run video saved to gallery (${s.duration}s)'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (s.state == CameraRecordingState.error) {
        debugPrint('[Camera] ${s.message}');
      }
    });
  }

  Future<void> _checkConnection() async {
    final status = await _robotService.fetchStatus();
    if (mounted) {
      setState(() => _isConnected = status != null);
      if (status != null) {
        // Small delay so the voice service is fully initialised before speaking
        await Future.delayed(const Duration(milliseconds: 600));
        await _announceBattery(status);
      }
    }
  }

  @override
  void dispose() {
    _robotService.dispose();
    _garminService.dispose();
    _cameraRecording.dispose();
    _voiceService.dispose();
    _encouragementTimer?.cancel();
    _elapsedTimer?.cancel();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // ── Pace helpers ─────────────────────────────────────────────────

  String _kmhToPaceString(double kmh) {
    if (kmh < 0.1) return '--:--';
    double minPerKm = 60.0 / kmh;
    int mins = minPerKm.floor();
    int secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  // ── Start / Stop ─────────────────────────────────────────────────

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
        _showError(
          'Could not find a Garmin watch.\nMake sure Bluetooth is on and your watch is nearby.',
        );
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_waypoints.isEmpty) {
      _showError('Add at least one destination waypoint first.');
      return;
    }

    final ok = await _robotService.startPacing(
      paceKmh: _targetPaceKmh,
      waypoints: _waypoints,
    );

    if (!ok) {
      _showError(
        'Could not reach robot.\nMake sure your phone is connected to the "RunnerCompanion" WiFi.',
      );
      return;
    }

    _hrSamples.clear();
    _cadenceSamples.clear();
    _lastKmAnnounced = 0;
    _batteryWarnedCritical = false;
    _halfwayAnnouncedReturn = false; // reset for this run
    // Announce battery level before the run starts
    final currentStatus = _robotStatus;
    if (currentStatus != null) await _announceBattery(currentStatus);
    _startTime = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
        // Km milestone announcements
        final kmDone = (_targetPaceKmh * _elapsedTime.inSeconds / 3600).floor();
        if (kmDone > _lastKmAnnounced && kmDone > 0) {
          _lastKmAnnounced = kmDone;
          _voiceService.announceKmMilestone(kmDone);
        }
        // Update background notification with live stats
        _bgService.updateStats(
          paceKmh: _targetPaceKmh,
          elapsed: _elapsedTime,
          heartRate: _garminData.heartRate,
          distanceKm: _garminData.distanceKm > 0
              ? _garminData.distanceKm
              : (_targetPaceKmh * _elapsedTime.inSeconds / 3600.0),
          cadence: _garminData.cadence,
        );
      }
    });
    // Encouragement every 3 minutes
    _encouragementTimer?.cancel();
    _encouragementTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (_isRunning) _voiceService.randomEncouragement();
    });
    // Announce start
    _voiceService.announceWorkoutStart(_targetPaceKmh);

    // Start background foreground service (keeps app alive + shows notification)
    _bgService.startWorkout(paceKmh: _targetPaceKmh);

    // Start camera recording automatically if the robot camera is available
    if (_robotStatus?.cameraOk == true) {
      unawaited(_cameraRecording.startRecording());
      debugPrint('[Camera] Recording started');
    }

    _robotService.startPolling();

    setState(() {
      _isRunning = true;
      _isConnected = true;
    });
  }

  Future<void> _stopWorkout() async {
    // Stop camera recording first — begins encoding while the rest shuts down
    if (_cameraRecording.isRecording) {
      unawaited(_cameraRecording.stopRecording());
    }

    await _robotService.stopPacing();
    _robotService.stopPolling();
    _elapsedTimer?.cancel();

    final avgHr = _hrSamples.isNotEmpty
        ? (_hrSamples.reduce((a, b) => a + b) ~/ _hrSamples.length)
        : null;
    final avgCadence = _cadenceSamples.isNotEmpty
        ? (_cadenceSamples.reduce((a, b) => a + b) ~/ _cadenceSamples.length)
        : null;
    final distKm = _garminData.distanceKm > 0
        ? _garminData.distanceKm
        : (_targetPaceKmh * _elapsedTime.inSeconds / 3600.0);

    // Save to Firestore
    await _firestoreService.saveRunSession(
      mode: 'Pace — ${_kmhToPaceString(_targetPaceKmh)}',
      startTime: _startTime ?? DateTime.now(),
      duration: _elapsedTime,
      distanceKm: distKm,
      avgHeartRate: avgHr,
      maxHeartRate: _hrSamples.isNotEmpty
          ? _hrSamples.reduce((a, b) => a > b ? a : b)
          : null,
      avgCadence: avgCadence,
      paceKmh: _targetPaceKmh,
      notes: 'Duration: ${_formatDuration(_elapsedTime)}',
    );

    _hrSamples.clear();
    _cadenceSamples.clear();

    final distKmFinal = _garminData.distanceKm > 0
        ? _garminData.distanceKm
        : (_targetPaceKmh * _elapsedTime.inSeconds / 3600.0);
    _voiceService.announceWorkoutStop(_elapsedTime, distKmFinal);
    _encouragementTimer?.cancel();

    // Stop background foreground service
    _bgService.stopWorkout();

    setState(() {
      _isRunning = false;
      _elapsedTime = Duration.zero;
    });
  }

  Future<void> _updatePace(double newPace) async {
    // Cap at robot's maximum supported speed (2 min/km = 30 km/h)
    setState(
      () => _targetPaceKmh = newPace.clamp(4.0, RobotStatus.maxSpeedKmh),
    );
    if (_isRunning) {
      await _robotService.updatePace(_targetPaceKmh);
    }
  }

  void _addWaypoint() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      _showError('Enter valid latitude and longitude numbers.');
      return;
    }
    setState(() => _waypoints.add(LatLng(lat, lng)));
    _latController.clear();
    _lngController.clear();
  }

  WorkoutContext get _workoutContext => WorkoutContext(
    isRunning: _isRunning,
    elapsed: _elapsedTime,
    paceKmh: _targetPaceKmh,
    distanceKm: _garminData.distanceKm > 0
        ? _garminData.distanceKm
        : (_targetPaceKmh * _elapsedTime.inSeconds / 3600.0),
    heartRate: _garminData.heartRate,
    cadence: _garminData.cadence,
    waypointCurrent: _robotStatus?.waypoint ?? 0,
    waypointTotal: _robotStatus?.totalWaypoints ?? _waypoints.length,
  );

  Future<void> _toggleVoiceListen() async {
    if (_voiceListening) {
      await _voiceService.stopListening();
      setState(() => _voiceListening = false);
      return;
    }
    setState(() => _voiceListening = true);
    final ok = await _voiceService.startListening(
      onCommand: (cmd) {
        if (!mounted) return;
        setState(() => _voiceListening = false);
        switch (cmd) {
          case VoiceCommand.stop:
            _stopWorkout();
            break;
          case VoiceCommand.speedUp:
            _updatePace(
              (_targetPaceKmh + 1.0).clamp(4.0, RobotStatus.maxSpeedKmh),
            );
            _voiceService.speak(
              'Speeding up to ${_targetPaceKmh.toStringAsFixed(1)} kilometres per hour.',
            );
            break;
          case VoiceCommand.slowDown:
            _updatePace(
              (_targetPaceKmh - 1.0).clamp(4.0, RobotStatus.maxSpeedKmh),
            );
            _voiceService.speak(
              'Slowing down to ${_targetPaceKmh.toStringAsFixed(1)} kilometres per hour.',
            );
            break;
          case VoiceCommand.distance:
          case VoiceCommand.pace:
          case VoiceCommand.status:
            _voiceService.announceStatus(_workoutContext);
            break;
          case VoiceCommand.playMusic:
            _voiceService.speak('Opening YouTube Music now.');
            launchUrl(
              Uri.parse('https://music.youtube.com'),
              mode: LaunchMode.externalApplication,
            );
            break;
          case VoiceCommand.alertAhead:
            _triggerAheadAlert();
            break;
          case VoiceCommand.clearLeft:
            _triggerClearPath('left');
            break;
          case VoiceCommand.clearRight:
            _triggerClearPath('right');
            break;
          case VoiceCommand.returnToStart:
            _returnToStart();
            break;
          default:
            break;
        }
      },
      onTranscript: (text) async {
        if (!mounted) return;
        setState(() => _voiceListening = false);
        final reply = await _aiService.chat(text, context: _workoutContext);
        // Execute any [CMD:xxx] tags Gemini embedded in the reply
        await _executeAiCommands(reply);
        // Strip tags before speaking
        final spokenReply = reply
            .replaceAll(RegExp(r'\[CMD:[^\]]+\]'), '')
            .trim();
        if (spokenReply.isNotEmpty) await _voiceService.speak(spokenReply);
      },
    );
    if (!ok && mounted) setState(() => _voiceListening = false);
  }

  void _openAiChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiChatScreen(workoutContext: _workoutContext),
      ),
    );
  }

  /// Reverse the waypoint list and send it to the robot to drive back to start.
  Future<void> _returnToStart() async {
    if (_waypoints.length < 2) {
      _voiceService.speak(
        'I need at least two waypoints to plan a return route. Please add more waypoints.',
      );
      return;
    }
    final reversed = _waypoints.reversed.toList();
    final ok = await _robotService.returnToStart(
      paceKmh: _targetPaceKmh,
      reversedWaypoints: reversed,
    );
    if (ok) {
      _halfwayAnnouncedReturn = true; // don't re-announce halfway
      await _voiceService.speak(
        'Heading back to the start! Great run so far. '
        'I will guide you all the way home at the same pace. Keep it up!',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🏠 Returning to start — reversed route sent to robot',
            ),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      _voiceService.speak(
        'Sorry, I could not reach the robot to set the return route. Please check the connection.',
      );
    }
  }

  /// Announce + SMS + robot horn with an auto-detected direction from sensors.
  Future<void> _triggerAheadAlert() async {
    // Use lateral sensors to pick the clearer side for the runner to pass
    final side = _robotStatus?.clearerSide ?? 'both';
    await _triggerClearPath(side);
  }

  /// Directional alert: announce on BT speaker, sound horn, SMS contacts.
  /// [direction] is 'left', 'right', or 'both' (generic).
  Future<void> _triggerClearPath(String direction) async {
    // 1. Polite spoken announcement on BT speaker
    String speech;
    String hornCmd;
    if (direction == 'left') {
      // More room on the LEFT — runner passes on the left — announce "on your left"
      speech = 'On your left, please! Runner coming through. Thank you!';
      hornCmd = 'horn_left';
    } else if (direction == 'right') {
      // More room on the RIGHT — runner passes on the right — announce "on your right"
      speech = 'On your right, please! Runner coming through. Thank you!';
      hornCmd = 'horn_right';
    } else {
      speech =
          'Excuse me, runner coming through! Please make way. Thank you so much!';
      hornCmd = 'sound_horn';
    }
    await _voiceService.speak(speech);
    // 2. Directional robot horn signal
    _robotService.sendCommand(hornCmd);
    // 3. SMS all registered ahead-contacts with direction hint
    final distKm = _garminData.distanceKm > 0
        ? _garminData.distanceKm
        : (_targetPaceKmh * _elapsedTime.inSeconds / 3600.0);
    final dir = (direction == 'both') ? null : direction;
    await _alertService.sendAlert(
      distanceKm: distKm,
      paceKmh: _targetPaceKmh,
      direction: dir,
    );
    if (mounted) {
      final label = direction == 'left'
          ? '← Left'
          : direction == 'right'
          ? 'Right →'
          : 'Clear path';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔔 $label alert sent — contacts notified!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Speak the robot battery level and estimated range on the BT speaker.
  /// [forceWarn] makes the message urgent even if battery is only low, not critical.
  Future<void> _announceBattery(
    RobotStatus status, {
    bool forceWarn = false,
  }) async {
    if (status.batteryPct < 0) return; // no battery data from robot
    final pct = status.batteryPct;
    // Use current target pace for runtime calculation
    final mins = status.batteryRuntimeMinsAtPace(_targetPaceKmh);

    // Express remaining time in a natural spoken form
    String timeStr;
    if (mins >= 120) {
      final h = mins ~/ 60;
      final m = mins % 60;
      timeStr = m == 0 ? '$h hours' : '$h hours and $m minutes';
    } else if (mins >= 60) {
      final m = mins % 60;
      timeStr = m == 0 ? '1 hour' : '1 hour and $m minutes';
    } else {
      timeStr = '$mins minutes';
    }

    final km = status.batteryRangeKm;
    final kmStr = km >= 1
        ? '${km.toStringAsFixed(1)} kilometres'
        : '${(km * 1000).round()} metres';

    String msg;
    if (status.isBatteryCritical || (forceWarn && status.isBatteryLow)) {
      msg =
          'CRITICAL BATTERY WARNING! Robot battery is at only $pct percent. '
          'That is roughly $timeStr or about $kmStr of running left. '
          'Please head back to base or find a charging point immediately!';
    } else if (status.isBatteryLow) {
      msg =
          'Battery warning: robot is at $pct percent. '
          'About $timeStr of running remaining. '
          'Consider wrapping up your run soon.';
    } else {
      msg =
          'Robot connected and ready. Battery at $pct percent — '
          'approximately $timeStr of running available. '
          'That is around $kmStr. Let\'s go!';
    }
    await _voiceService.speak(msg);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  /// Parse and execute all [CMD:xxx] tags that Gemini embedded in its reply.
  Future<void> _executeAiCommands(String reply) async {
    final regex = RegExp(r'\[CMD:([^\]]+)\]');
    for (final match in regex.allMatches(reply)) {
      final cmd = match.group(1)?.trim().toLowerCase() ?? '';
      switch (cmd) {
        case 'follow_me':
          _robotService.sendCommand('follow_me');
          break;
        case 'stop':
          if (_isRunning) _stopWorkout();
          _robotService.sendCommand('stop');
          break;
        case 'pause':
          _robotService.sendCommand('pause');
          break;
        case 'open_box':
          _robotService.sendCommand('open_box');
          break;
        case 'close_box':
          _robotService.sendCommand('close_box');
          break;
        case 'return_home':
          _robotService.sendCommand('return_home');
          break;
        case 'return_to_start':
          _returnToStart();
          break;
        case 'speed_up':
          _updatePace((_targetPaceKmh + 1.0).clamp(4.0, 16.0));
          break;
        case 'slow_down':
          _updatePace((_targetPaceKmh - 1.0).clamp(4.0, 16.0));
          break;
        case 'play_music':
          // Opens YouTube Music — played via BT speaker on the robot
          final uri = Uri.parse('https://music.youtube.com');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          break;
        case 'alert_ahead':
          _triggerAheadAlert();
          break;
        case 'clear_left':
          _triggerClearPath('left');
          break;
        case 'clear_right':
          _triggerClearPath('right');
          break;
      }
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = _robotStatus;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pace Workout'),
        actions: [
          // Alert ahead button
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Alert contacts: runner approaching',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RunnerAlertScreen(
                  distanceKm: _garminData.distanceKm > 0
                      ? _garminData.distanceKm
                      : (_targetPaceKmh * _elapsedTime.inSeconds / 3600.0),
                  paceKmh: _targetPaceKmh,
                ),
              ),
            ),
          ),
          // AI Chat button
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'Chat with RunBot AI',
            onPressed: _openAiChat,
          ),
          // Voice command mic button
          IconButton(
            icon: Icon(
              _voiceListening ? Icons.mic : Icons.mic_none,
              color: _voiceListening ? Colors.redAccent : null,
            ),
            tooltip: _voiceListening ? 'Stop listening' : 'Voice command',
            onPressed: _toggleVoiceListen,
          ),
          // Garmin connect button
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
                      : 'Connect Garmin Watch',
                  onPressed: _connectGarmin,
                ),
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Garmin live data card ─────────────────────────────────
            if (_garminData.connected) ...[
              _GarminCard(data: _garminData),
              const SizedBox(height: 12),
            ],

            // ── Live stats card ──────────────────────────────────────
            if (_isRunning) ...[
              _LiveStatsCard(
                elapsed: _formatDuration(_elapsedTime),
                robotPace: status?.paceString ?? '--:--',
                targetPace: _kmhToPaceString(_targetPaceKmh),
                runnerDistance: status?.runnerDistanceBehind ?? 0,
                waypointProgress: status?.progress ?? 0,
                obstacleAhead: status?.obstacleAhead ?? false,
                runnerLost: status?.runnerLost ?? false,
                gpsFix: status?.gpsFix ?? false,
                currentWaypoint: status?.waypoint ?? 0,
                totalWaypoints: status?.totalWaypoints ?? 0,
              ),
              const SizedBox(height: 12),
              // ── Camera recording status ───────────────────────────
              _CameraRecordingCard(
                cameraOk: status?.cameraOk ?? false,
                cameraStatus: _cameraStatus,
                isRecording: _cameraRecording.isRecording,
                frameCount: _cameraRecording.frameCount,
                onToggle: () {
                  if (_cameraRecording.isRecording) {
                    unawaited(_cameraRecording.stopRecording());
                  } else {
                    unawaited(_cameraRecording.startRecording());
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Not connected warning ────────────────────────────────
            if (!_isConnected && !_isRunning)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Not connected to robot',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Go to phone WiFi settings → connect to "RunnerCompanion"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _checkConnection,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Target pace slider ───────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Pace',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _kmhToPaceString(_targetPaceKmh),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_targetPaceKmh.toStringAsFixed(1)} km/h',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    Slider(
                      value: _targetPaceKmh,
                      min: 4.0,
                      max: 16.0,
                      divisions: 24,
                      activeColor: Colors.teal,
                      label: _kmhToPaceString(_targetPaceKmh),
                      onChanged: _updatePace,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '4 km/h\nWalk',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '8 km/h\nJog',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '12 km/h\nRun',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '16 km/h\nFast',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Waypoints ────────────────────────────────────────────
            if (!_isRunning) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Destination Waypoints',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter GPS coordinates for your route (get from Google Maps → long press → copy coordinates)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _lngController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addWaypoint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      if (_waypoints.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._waypoints.asMap().entries.map(
                          (e) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.teal,
                              child: Text(
                                '${e.key + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(
                              '${e.value.lat.toStringAsFixed(5)}, ${e.value.lng.toStringAsFixed(5)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _waypoints.removeAt(e.key)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Start / Stop button ──────────────────────────────────
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.red : Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isRunning ? _stopWorkout : _startWorkout,
                icon: Icon(
                  _isRunning ? Icons.stop : Icons.play_arrow,
                  size: 28,
                ),
                label: Text(_isRunning ? 'Stop Workout' : 'Start Pacing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live stats card ────────────────────────────────────────────────
class _LiveStatsCard extends StatelessWidget {
  final String elapsed;
  final String robotPace;
  final String targetPace;
  final double runnerDistance;
  final double waypointProgress;
  final bool obstacleAhead;
  final bool runnerLost;
  final bool gpsFix;
  final int currentWaypoint;
  final int totalWaypoints;

  const _LiveStatsCard({
    required this.elapsed,
    required this.robotPace,
    required this.targetPace,
    required this.runnerDistance,
    required this.waypointProgress,
    required this.obstacleAhead,
    required this.runnerLost,
    required this.gpsFix,
    required this.currentWaypoint,
    required this.totalWaypoints,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal.shade700,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Timer
            Text(
              elapsed,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),

            // Pace row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(
                  label: 'Target',
                  value: targetPace,
                  color: Colors.white70,
                ),
                _Stat(
                  label: 'Robot Speed',
                  value: robotPace,
                  color: Colors.greenAccent,
                ),
                _Stat(
                  label: 'Behind',
                  value: '${runnerDistance.toStringAsFixed(1)}m',
                  color: runnerLost
                      ? Colors.redAccent
                      : runnerDistance > 4
                      ? Colors.orangeAccent
                      : Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Waypoint progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waypoint $currentWaypoint / $totalWaypoints',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: waypointProgress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.greenAccent,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Status indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Badge(
                  label: gpsFix ? 'GPS Fix' : 'No GPS',
                  color: gpsFix ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                if (obstacleAhead)
                  const _Badge(label: '⚠ Obstacle', color: Colors.orangeAccent),
                if (runnerLost) ...[
                  const SizedBox(width: 8),
                  const _Badge(
                    label: '🛑 Runner Lost — Waiting',
                    color: Colors.redAccent,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ── Garmin live-data card ──────────────────────────────────────────
class _GarminCard extends StatelessWidget {
  final GarminData data;
  const _GarminCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A237E),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.watch, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Garmin',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            _GarminStat(
              icon: Icons.favorite,
              value: data.heartRate > 0 ? '${data.heartRate}' : '--',
              unit: 'bpm',
              color: Colors.redAccent,
            ),
            const SizedBox(width: 16),
            _GarminStat(
              icon: Icons.accessibility_new,
              value: data.cadence > 0 ? '${data.cadence}' : '--',
              unit: 'spm',
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 16),
            _GarminStat(
              icon: Icons.speed,
              value: data.speedKmh > 0
                  ? data.speedKmh.toStringAsFixed(1)
                  : '--',
              unit: 'km/h',
              color: Colors.greenAccent,
            ),
            const SizedBox(width: 16),
            _GarminStat(
              icon: Icons.straighten,
              value: data.distanceKm > 0
                  ? data.distanceKm.toStringAsFixed(2)
                  : '--',
              unit: 'km',
              color: Colors.cyanAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class _GarminStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;
  const _GarminStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }
}
// ── Camera Recording Card ─────────────────────────────────────────────────────

class _CameraRecordingCard extends StatelessWidget {
  final bool cameraOk;
  final CameraRecordingStatus cameraStatus;
  final bool isRecording;
  final int frameCount;
  final VoidCallback onToggle;

  const _CameraRecordingCard({
    required this.cameraOk,
    required this.cameraStatus,
    required this.isRecording,
    required this.frameCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // If no camera on the robot, show a muted placeholder
    if (!cameraOk && !isRecording) {
      return Card(
        color: const Color(0xFF1A1A2E),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: const [
              Icon(Icons.videocam_off, color: Colors.white24, size: 18),
              SizedBox(width: 10),
              Text(
                'Camera not available on this robot',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final Color accentColor = switch (cameraStatus.state) {
      CameraRecordingState.recording => Colors.redAccent,
      CameraRecordingState.saving => Colors.orangeAccent,
      CameraRecordingState.saved => Colors.greenAccent,
      CameraRecordingState.error => Colors.red,
      _ => Colors.white54,
    };

    final String label = switch (cameraStatus.state) {
      CameraRecordingState.recording =>
        'Recording  •  $frameCount frames  (${(frameCount / 10).toStringAsFixed(0)}s)',
      CameraRecordingState.saving => 'Encoding video…',
      CameraRecordingState.saved => cameraStatus.message,
      CameraRecordingState.error => cameraStatus.message,
      _ => 'Camera ready',
    };

    return Card(
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accentColor.withOpacity(0.4), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Pulsing dot for active recording
            if (cameraStatus.state == CameraRecordingState.recording)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.videocam, color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight:
                      cameraStatus.state == CameraRecordingState.recording
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Toggle button — only available when camera is present and not encoding
            if (cameraOk &&
                cameraStatus.state != CameraRecordingState.saving) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRecording
                        ? Colors.redAccent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRecording ? Colors.redAccent : Colors.white24,
                    ),
                  ),
                  child: Text(
                    isRecording ? 'Stop' : 'Record',
                    style: TextStyle(
                      color: isRecording ? Colors.redAccent : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
