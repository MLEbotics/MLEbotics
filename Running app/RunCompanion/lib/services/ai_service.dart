import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_service.dart';

// ── Chat message model ────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

// ── AI Service ────────────────────────────────────────────────────────────────
class AiService {
  static const _prefKeyApiKey = 'gemini_api_key';

  GenerativeModel? _model;
  ChatSession? _chat;
  String? _apiKey;
  bool get isReady => _model != null;

  static const _systemPrompt = '''
You are RunBot, an enthusiastic and knowledgeable AI running companion built into a robot that physically runs alongside a human runner. You have a warm, encouraging personality — like a personal coach and best friend combined.

Your capabilities and context:
- You run physically alongside the runner via a robot companion
- The robot carries an enclosed supply box with hydration, energy gels, light jackets, and extra clothing
- You can read live data: heart rate, cadence, speed, distance from the runner's Garmin watch (connected to the phone)
- The phone IS the robot's brain — GPS, AI, network and Garmin BLE all run on the phone mounted on the robot
- You know the runner's current pace, elapsed time, waypoints, and workout type
- The runner controls the robot via voice commands and this app
- You give spoken announcements: km milestones, pace alerts, direction, motivation

ROBOT CONTROL COMMANDS:
When the runner asks you to control the robot, or to play music, include a command tag ANYWHERE in your response. The app will extract and execute it silently and strip the tag before speaking your reply aloud.

Available commands:
  [CMD:follow_me]   — robot starts following the runner
  [CMD:stop]        — robot stops moving
  [CMD:pause]       — robot pauses temporarily
  [CMD:open_box]    — opens the supply box lid
  [CMD:close_box]   — closes the supply box lid
  [CMD:return_home]    — robot goes back to start position
  [CMD:return_to_start] — robot reverses the planned route and drives the runner back to the start point
  [CMD:speed_up]    — increase pace by 1 km/h
  [CMD:slow_down]   — decrease pace by 1 km/h
  [CMD:play_music]  — opens YouTube Music on the phone (played via BT speaker on robot)
  [CMD:alert_ahead] — sends SMS to all registered ahead-contacts + announces on speaker + sounds robot horn
  [CMD:clear_left]  — robot detects more space on left; announces "on your left" + directional horn + SMS (move right)
  [CMD:clear_right] — robot detects more space on right; announces "on your right" + directional horn + SMS (move left)

Examples:
  Runner: "play some music" → "[CMD:play_music] Opening YouTube Music now — let's get those legs moving!"
  Runner: "stop the robot" → "[CMD:stop] Stopping now. Take your time."
  Runner: "open the box I need a gel" → "[CMD:open_box] Box is open! Grab your gel — you've earned it!"
  Runner: "follow me" → "[CMD:follow_me] I'm right behind you!"
  Runner: "slow down a bit" → "[CMD:slow_down] Easing off the pace — breathe easy."
  Runner: "alert people ahead" → "[CMD:alert_ahead] Alerting your contacts and announcing on the speaker now!"
  Runner: "let people know I'm coming" → "[CMD:alert_ahead] Done! Your contacts are being notified that you're on your way."
  Runner: "clear the path" → "[CMD:clear_left] Checking sensors — calling on your left!"
  Runner: "tell them to move" → "[CMD:clear_right] Got it — announcing on your right side!"
  Runner: "head back" → "[CMD:return_to_start] On our way back! You’re doing great — same pace all the way home!"
  Runner: "I want to go back to start" → "[CMD:return_to_start] Reversing the route now. Let’s bring you home strong!"

When answering:
- BE CONCISE for spoken answers (the answer will be read aloud) — aim for 1-3 sentences unless asked for detail
- Be motivating, positive, and supportive
- Use running/fitness terminology naturally
- If asked about the current workout, use the context injected at the start of the message
- For medical advice, recommend consulting a professional but give general guidance
- You can chat casually, tell jokes, discuss training plans, nutrition, race strategy, injury prevention
- Always stay safe — recommend stopping if the runner describes chest pain, dizziness, or severe pain
''';

  // ── Init / API key management ─────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefKeyApiKey);
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _initModel(_apiKey!);
    }
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyApiKey, _apiKey!);
    _initModel(_apiKey!);
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyApiKey);
  }

  void _initModel(String key) {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: key,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.75,
          maxOutputTokens: 512,
        ),
      );
      _chat = _model!.startChat();
    } catch (e) {
      debugPrint('AiService init model error: $e');
      _model = null;
      _chat = null;
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Send a message and get a response. Optionally inject live workout context.
  Future<String> chat(String userMessage, {WorkoutContext? context}) async {
    if (_model == null || _chat == null) {
      return "I'm not connected yet — please add your Gemini API key in Settings.";
    }

    // Inject live workout context as a prefix the model can see
    String fullMessage = userMessage;
    if (context != null && context.isRunning) {
      final mins = context.elapsed.inMinutes;
      final secs = context.elapsed.inSeconds % 60;
      final ctx =
          '[LIVE WORKOUT DATA: '
          'Running=${context.isRunning}, '
          'Time=${mins}m${secs}s, '
          'Pace=${context.paceKmh.toStringAsFixed(1)}km/h, '
          'Distance=${context.distanceKm.toStringAsFixed(2)}km, '
          'HR=${context.heartRate}bpm, '
          'Cadence=${context.cadence}spm, '
          'Waypoint=${context.waypointCurrent}/${context.waypointTotal}'
          ']\n\nRunner asks: $userMessage';
      fullMessage = ctx;
    }

    try {
      final response = await _chat!.sendMessage(Content.text(fullMessage));
      return response.text ??
          "Sorry, I didn't catch that. Could you ask again?";
    } catch (e) {
      debugPrint('AiService chat error: $e');
      if (e.toString().contains('API_KEY') || e.toString().contains('403')) {
        return "Invalid Gemini API key. Please check your key in Settings.";
      }
      return "I had trouble connecting. Please check your internet connection.";
    }
  }

  /// Start a fresh conversation (clears chat history)
  void resetChat() {
    if (_model != null) {
      _chat = _model!.startChat();
    }
  }

  void dispose() {
    _model = null;
    _chat = null;
  }
}
