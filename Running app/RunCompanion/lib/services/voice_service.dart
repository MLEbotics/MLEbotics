import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Voice commands understood by the service ─────────────────────────────────
enum VoiceCommand {
  stop,
  speedUp,
  slowDown,
  pause,
  resume,
  distance,
  pace,
  status,
  openBox,
  closeBox,
  playMusic,
  alertAhead,
  clearLeft,
  clearRight,
  returnToStart,
  unknown,
}

// ── Context injected by the caller so voice knows the workout state ───────────
class WorkoutContext {
  final bool isRunning;
  final Duration elapsed;
  final double paceKmh;
  final double distanceKm;
  final int heartRate;
  final int cadence;
  final int waypointCurrent;
  final int waypointTotal;

  const WorkoutContext({
    this.isRunning = false,
    this.elapsed = Duration.zero,
    this.paceKmh = 0,
    this.distanceKm = 0,
    this.heartRate = 0,
    this.cadence = 0,
    this.waypointCurrent = 0,
    this.waypointTotal = 0,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _ttsReady = false;
  bool _sttAvailable = false;
  bool _isListening = false;
  bool get isListening => _isListening;

  // Callback wire-up
  Function(VoiceCommand)? _onCommand;
  Function(String)? _onTranscript; // raw text → AI pipeline

  // Encouragement pool
  static const _encouragements = [
    "You're doing amazing! Keep those legs moving!",
    "Looking strong! Keep up that pace!",
    "Every step counts — you've got this!",
    "Half way there — dig deep!",
    "Your robot believes in you. Push it!",
    "Great cadence! Keep that rhythm going!",
    "You're faster than yesterday. Stay focused!",
    "Breathe in, breathe out — stay steady!",
    "Champions don't stop. Neither do you!",
    "Almost there — finish strong!",
  ];

  final _random = Random();

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Web doesn't support flutter_tts the same way — guard gracefully
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.05);
      _ttsReady = true;
    } catch (e) {
      debugPrint('VoiceService TTS init error: $e');
    }

    try {
      _sttAvailable = await _stt.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            _isListening = false;
          }
        },
      );
    } catch (e) {
      debugPrint('VoiceService STT init error: $e');
    }
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  Future<void> speak(String text) async {
    if (!_ttsReady) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakImmediate(String text) async {
    if (!_ttsReady) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  void stopSpeaking() => _tts.stop();

  // ── Workout announcements ─────────────────────────────────────────────────

  Future<void> announceWorkoutStart(double paceKmh) async {
    final pace = _paceStr(paceKmh);
    await speak(
      'Workout started! Running at $pace pace. Your robot companion is ready. Let\'s go!',
    );
  }

  Future<void> announceWorkoutStop(Duration elapsed, double distKm) async {
    final mins = elapsed.inMinutes;
    final dist = distKm.toStringAsFixed(2);
    await speak(
      'Great run! You ran for $mins minutes covering $dist kilometres. Excellent work!',
    );
  }

  Future<void> announceKmMilestone(int km) async {
    final msgs = [
      '$km kilometre done! Keep it up!',
      'That\'s $km k! You\'re on fire!',
      '$km kilometre marker — strong work!',
    ];
    await speak(msgs[_random.nextInt(msgs.length)]);
  }

  Future<void> announceDistance(double donekm, double totalKm) async {
    final remaining = (totalKm - donekm).clamp(0, totalKm);
    await speak(
      'You have run ${donekm.toStringAsFixed(1)} kilometres. '
      '${remaining.toStringAsFixed(1)} kilometres remaining.',
    );
  }

  Future<void> announcePace(double currentKmh, double targetKmh) async {
    if (currentKmh < targetKmh - 0.5) {
      await speak(
        'You\'re running a little slow. Try to pick up the pace to ${_paceStr(targetKmh)}.',
      );
    } else if (currentKmh > targetKmh + 0.5) {
      await speak(
        'You\'re ahead of pace — great, but ease back slightly to ${_paceStr(targetKmh)} to conserve energy.',
      );
    } else {
      await speak('Perfect pace! Keep it at ${_paceStr(targetKmh)}.');
    }
  }

  Future<void> announceHeartRate(int hr) async {
    String zone;
    if (hr < 120) {
      zone = 'Zone 1 — easy effort';
    } else if (hr < 140)
      zone = 'Zone 2 — aerobic';
    else if (hr < 160)
      zone = 'Zone 3 — tempo';
    else if (hr < 175)
      zone = 'Zone 4 — hard effort';
    else
      zone = 'Zone 5 — maximum effort';
    await speak('Heart rate $hr beats per minute. $zone.');
  }

  Future<void> announceNextWaypoint(
    int current,
    int total,
    int metersAway,
  ) async {
    await speak(
      'Approaching waypoint $current of $total, in approximately $metersAway metres.',
    );
  }

  Future<void> announceObstacle() async {
    await speakImmediate('Obstacle detected ahead! Robot is slowing down.');
  }

  Future<void> randomEncouragement() async {
    await speak(_encouragements[_random.nextInt(_encouragements.length)]);
  }

  Future<void> announceStatus(WorkoutContext ctx) async {
    if (!ctx.isRunning) {
      await speak('No workout is currently active.');
      return;
    }
    final mins = ctx.elapsed.inMinutes;
    final secs = ctx.elapsed.inSeconds % 60;
    final dist = ctx.distanceKm.toStringAsFixed(2);
    final pace = _paceStr(ctx.paceKmh);
    var msg =
        'Workout time: $mins minutes and $secs seconds. '
        'Distance: $dist kilometres. '
        'Current pace: $pace. ';
    if (ctx.heartRate > 0) msg += 'Heart rate: ${ctx.heartRate} bpm. ';
    if (ctx.waypointTotal > 0) {
      msg += 'Waypoint ${ctx.waypointCurrent} of ${ctx.waypointTotal}.';
    }
    await speak(msg);
  }

  Future<void> announceNextInterval(
    String intervalType,
    int durationSeconds,
  ) async {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    final timeStr = mins > 0 ? '$mins minutes $secs seconds' : '$secs seconds';
    await speak('Next interval: $intervalType for $timeStr. Get ready!');
  }

  // ── STT — owner-only voice commands ──────────────────────────────────────

  /// Only the signed-in owner can trigger voice commands.
  Future<bool> startListening({
    required Function(VoiceCommand) onCommand,
    Function(String)? onTranscript,
  }) async {
    if (!_sttAvailable) return false;

    // Security: only accept voice commands when signed in
    if (FirebaseAuth.instance.currentUser == null) {
      await speak('Voice control is only available to the registered owner.');
      return false;
    }

    if (_isListening) return true;

    _onCommand = onCommand;
    _onTranscript = onTranscript;
    _isListening = true;

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          final text = result.recognizedWords.toLowerCase().trim();
          if (onTranscript != null) onTranscript(text);
          final cmd = _parseCommand(text);
          if (cmd != VoiceCommand.unknown) onCommand(cmd);
        }
      },
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );

    return true;
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _stt.stop();
  }

  // ── Command parser ────────────────────────────────────────────────────────

  VoiceCommand _parseCommand(String text) {
    if (_anyOf(text, ['stop', 'halt', 'end', 'finish', 'quit'])) {
      return VoiceCommand.stop;
    }
    if (_anyOf(text, ['speed up', 'faster', 'go faster', 'speed up please'])) {
      return VoiceCommand.speedUp;
    }
    if (_anyOf(text, ['slow down', 'slower', 'too fast', 'ease off'])) {
      return VoiceCommand.slowDown;
    }
    if (_anyOf(text, ['pause', 'wait', 'hold on', 'hold'])) {
      return VoiceCommand.pause;
    }
    if (_anyOf(text, [
      'resume',
      'continue',
      'go',
      'start again',
      'keep going',
    ])) {
      return VoiceCommand.resume;
    }
    if (_anyOf(text, [
      'how far',
      'distance',
      'how long',
      'how many kilometres',
      'how many kilometers',
      'how much',
    ])) {
      return VoiceCommand.distance;
    }
    if (_anyOf(text, [
      'pace',
      'how am i doing',
      'what is my pace',
      'what pace',
      'am i on pace',
    ])) {
      return VoiceCommand.pace;
    }
    if (_anyOf(text, [
      'status',
      'what is happening',
      "what's happening",
      'workout status',
      'update',
    ])) {
      return VoiceCommand.status;
    }
    if (_anyOf(text, [
      'open box',
      'open lid',
      'open the box',
      'open compartment',
    ])) {
      return VoiceCommand.openBox;
    }
    if (_anyOf(text, ['close box', 'close lid', 'close the box', 'lock box'])) {
      return VoiceCommand.closeBox;
    }
    if (_anyOf(text, [
      'play music',
      'play some music',
      'music please',
      'put on some music',
      'start music',
      'turn on music',
    ])) {
      return VoiceCommand.playMusic;
    }
    if (_anyOf(text, [
      'alert ahead',
      'alert people',
      'warn people',
      'people ahead',
      'let them know',
      'send alert',
      'notify ahead',
      'runner coming',
    ])) {
      return VoiceCommand.alertAhead;
    }
    if (_anyOf(text, [
      'on your left',
      'move right',
      'go right',
      'pass on the left',
      'coming on the left',
      'left side',
    ])) {
      return VoiceCommand.clearLeft;
    }
    if (_anyOf(text, [
      'on your right',
      'move left',
      'go left',
      'pass on the right',
      'coming on the right',
      'right side',
    ])) {
      return VoiceCommand.clearRight;
    }
    if (_anyOf(text, [
      'head back',
      'go back',
      'return to start',
      'turn around',
      'back to start',
      'return home',
      'go home',
      'head home',
      'take me back',
    ])) {
      return VoiceCommand.returnToStart;
    }
    return VoiceCommand.unknown;
  }

  bool _anyOf(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _paceStr(double kmh) {
    if (kmh < 0.1) return 'unknown pace';
    final minPerKm = 60.0 / kmh;
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins minutes ${secs.toString().padLeft(2, '0')} per kilometre';
  }

  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}
