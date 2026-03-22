import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_plan.dart';

// ── TrainingPeaks API Service ─────────────────────────────────────────────────
//
// Full OAuth 2.0 + REST integration with the TrainingPeaks Public API.
//
// SETUP (one-time, done by you as the developer):
//   1. Apply for API access at https://developer.trainingpeaks.com/
//   2. Register your redirect URIs:
//        Android / iOS / Desktop:  runnercompanion://trainingpeaks-callback
//        Web:                      https://runningcompanion.web.app/tp-callback.html
//   3. Paste your client_id and client_secret into the constants below.
//
// Users never touch credentials — they just tap "Connect TrainingPeaks".
// ─────────────────────────────────────────────────────────────────────────────

// ── Developer credentials (fill in after TP approves your application) ───────
const _kClientId = ''; // ← paste your client_id here
const _kClientSecret = ''; // ← paste your client_secret here

// Redirect URIs registered with TrainingPeaks
const _kRedirectUriMobile = 'runnercompanion://trainingpeaks-callback';
const _kRedirectUriWeb = 'https://runningcompanion.web.app/tp-callback.html';

// OAuth + API base URLs
const _kAuthBase = 'https://oauth.trainingpeaks.com';
const _kApiBase = 'https://api.trainingpeaks.com';

// Scopes needed:
//   workouts:read  → list today's planned workouts
//   workouts:wod   → download TCX structure file
//   athlete:profile → show athlete name in the UI
const _kScopes = 'workouts:read workouts:wod athlete:profile';

// SharedPrefs keys
const _kPrefAccessToken = 'tp_access_token';
const _kPrefRefreshToken = 'tp_refresh_token';
const _kPrefExpiresAt = 'tp_expires_at';
const _kPrefAthleteId = 'tp_athlete_id';
const _kPrefAthleteName = 'tp_athlete_name';

// ── Data objects ──────────────────────────────────────────────────────────────

class TpWorkout {
  final int id;
  final String title;
  final String workoutType; // "Run", "Bike", "Swim", etc.
  final DateTime workoutDay;
  final double distancePlannedM; // metres
  final double totalTimePlannedHours; // decimal hours
  final double velocityPlannedMs; // metres/second
  final bool completed;
  final String? description;
  final String? url;

  const TpWorkout({
    required this.id,
    required this.title,
    required this.workoutType,
    required this.workoutDay,
    this.distancePlannedM = 0,
    this.totalTimePlannedHours = 0,
    this.velocityPlannedMs = 0,
    this.completed = false,
    this.description,
    this.url,
  });

  factory TpWorkout.fromJson(Map<String, dynamic> j) => TpWorkout(
    id: (j['Id'] as num).toInt(),
    title: (j['Title'] as String?) ?? 'Untitled Workout',
    workoutType: (j['WorkoutType'] as String?) ?? '',
    workoutDay:
        DateTime.tryParse(j['WorkoutDay'] as String? ?? '') ?? DateTime.now(),
    distancePlannedM: ((j['DistancePlanned'] as num?) ?? 0).toDouble(),
    totalTimePlannedHours: ((j['TotalTimePlanned'] as num?) ?? 0).toDouble(),
    velocityPlannedMs: ((j['VelocityPlanned'] as num?) ?? 0).toDouble(),
    completed: (j['Completed'] as bool?) ?? false,
    description: j['Description'] as String?,
    url: j['Url'] as String?,
  );

  bool get isRun =>
      workoutType.toLowerCase().contains('run') ||
      workoutType.toLowerCase().contains('walk');

  String get distanceLabel {
    if (distancePlannedM <= 0) return '';
    return distancePlannedM >= 1000
        ? '${(distancePlannedM / 1000).toStringAsFixed(1)} km'
        : '${distancePlannedM.round()} m';
  }

  String get durationLabel {
    if (totalTimePlannedHours <= 0) return '';
    final totalMins = (totalTimePlannedHours * 60).round();
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get paceLabel {
    if (velocityPlannedMs <= 0) return '';
    final kmh = velocityPlannedMs * 3.6;
    if (kmh <= 0) return '';
    final mpm = 60.0 / kmh;
    final mins = mpm.floor();
    final secs = ((mpm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}/km';
  }
}

// ── TrainingPeaksService ──────────────────────────────────────────────────────

class TrainingPeaksService {
  TrainingPeaksService._();
  static final TrainingPeaksService instance = TrainingPeaksService._();

  // In-memory cache (populated from SharedPrefs on first use)
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _athleteId;
  String? _athleteName;
  bool _loaded = false;

  // Stream so UI can react to connection changes
  final _stateController =
      StreamController<TrainingPeaksConnectionState>.broadcast();
  Stream<TrainingPeaksConnectionState> get stateStream =>
      _stateController.stream;

  TrainingPeaksConnectionState _state =
      TrainingPeaksConnectionState.disconnected;
  TrainingPeaksConnectionState get state => _state;

  // ── Setup check ────────────────────────────────────────────────────
  bool get isConfigured => _kClientId.isNotEmpty && _kClientSecret.isNotEmpty;

  // ── Connection ──────────────────────────────────────────────────────

  Future<bool> isConnected() async {
    await _loadTokens();
    return _accessToken != null && _athleteId != null;
  }

  String? get athleteName => _athleteName;
  String? get athleteId => _athleteId;

  /// Launch TrainingPeaks OAuth flow and save tokens on success.
  Future<TrainingPeaksConnectResult> connect() async {
    if (!isConfigured) {
      return TrainingPeaksConnectResult.notConfigured;
    }

    final redirectUri = kIsWeb ? _kRedirectUriWeb : _kRedirectUriMobile;

    final authUri = Uri.parse('$_kAuthBase/OAuth/Authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _kClientId,
        'scope': _kScopes,
        'redirect_uri': redirectUri,
      },
    );

    try {
      _emit(TrainingPeaksConnectionState.connecting);

      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: kIsWeb ? 'https' : 'runnercompanion',
        options: const FlutterWebAuth2Options(
          preferEphemeral: true,
          intentFlags: ephemeralIntentFlags,
        ),
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null || code.isEmpty) {
        _emit(TrainingPeaksConnectionState.disconnected);
        return TrainingPeaksConnectResult.cancelled;
      }

      final ok = await _exchangeCode(code, redirectUri);
      if (ok) {
        await _fetchProfile();
        _emit(TrainingPeaksConnectionState.connected);
        return TrainingPeaksConnectResult.success;
      } else {
        _emit(TrainingPeaksConnectionState.disconnected);
        return TrainingPeaksConnectResult.tokenError;
      }
    } on PlatformException catch (e) {
      debugPrint('TP OAuth platform error: ${e.message}');
      _emit(TrainingPeaksConnectionState.disconnected);
      return TrainingPeaksConnectResult.cancelled;
    } catch (e) {
      debugPrint('TP OAuth error: $e');
      _emit(TrainingPeaksConnectionState.disconnected);
      return TrainingPeaksConnectResult.error;
    }
  }

  Future<void> disconnect() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _athleteId = null;
    _athleteName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefAccessToken);
    await prefs.remove(_kPrefRefreshToken);
    await prefs.remove(_kPrefExpiresAt);
    await prefs.remove(_kPrefAthleteId);
    await prefs.remove(_kPrefAthleteName);
    _emit(TrainingPeaksConnectionState.disconnected);
  }

  // ── Today's workouts ────────────────────────────────────────────────

  /// Returns today's planned workouts (all types).
  Future<List<TpWorkout>> getTodaysWorkouts() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final today = _dateStr(DateTime.now());
    final uri = Uri.parse(
      '$_kApiBase/v2/workouts/$today/$today',
    ).replace(queryParameters: {'includeDescription': 'true'});

    try {
      final resp = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List)
            .cast<Map<String, dynamic>>();
        return list.map(TpWorkout.fromJson).toList()
          ..sort((a, b) => a.workoutDay.compareTo(b.workoutDay));
      } else if (resp.statusCode == 401) {
        // Token likely expired even after refresh attempt; re-prompt
        await disconnect();
      }
    } catch (e) {
      debugPrint('TP get workouts error: $e');
    }
    return [];
  }

  /// Downloads the structured TCX for a workout and parses it into a
  /// [WorkoutPlan] the robot can execute.  Falls back to text description.
  Future<WorkoutPlan?> fetchWorkoutPlan(TpWorkout workout) async {
    final token = await _getValidToken();
    if (token == null) return null;

    // 1) Try downloading the structured TCX file
    try {
      final uri = Uri.parse(
        '$_kApiBase/v2/workouts/wod/file/${workout.id}/',
      ).replace(queryParameters: {'format': 'tcx'});

      final resp = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 &&
          resp.body.contains('TrainingCenterDatabase')) {
        final parsed = WorkoutPlan.fromTcx(resp.body);
        // Use the TP title instead of whatever was in the TCX
        return WorkoutPlan(
          name: workout.title,
          source: 'TrainingPeaks',
          steps: parsed.steps,
        );
      }
    } catch (e) {
      debugPrint('TP TCX fetch error: $e');
    }

    // 2) Fall back to text description (coaches often write detailed notes)
    if (workout.description != null && workout.description!.trim().isNotEmpty) {
      try {
        return WorkoutPlan.fromText(workout.description!, name: workout.title);
      } catch (_) {}
    }

    // 3) Last resort: build a single-step plan from the metadata alone
    if (workout.velocityPlannedMs > 0 ||
        workout.distancePlannedM > 0 ||
        workout.totalTimePlannedHours > 0) {
      final paceKmh = workout.velocityPlannedMs > 0
          ? workout.velocityPlannedMs * 3.6
          : 10.0; // fallback 10 km/h easy jog

      final step = WorkoutStep(
        name: workout.title,
        type: StepType.active,
        durationType: workout.distancePlannedM > 0
            ? DurationType.distance
            : DurationType.time,
        duration: workout.distancePlannedM > 0
            ? workout.distancePlannedM
            : workout.totalTimePlannedHours * 3600,
        targetPaceKmh: paceKmh,
      );

      return WorkoutPlan(
        name: workout.title,
        source: 'TrainingPeaks',
        steps: [step],
      );
    }

    return null;
  }

  // ── Internal OAuth helpers ───────────────────────────────────────────

  Future<bool> _exchangeCode(String code, String redirectUri) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_kAuthBase/oauth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'client_id': _kClientId,
              'client_secret': _kClientSecret,
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': redirectUri,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        await _saveTokens(
          accessToken: json['access_token'] as String,
          refreshToken: json['refresh_token'] as String,
          expiresIn: (json['expires_in'] as num).toInt(),
        );
        return true;
      } else {
        debugPrint('TP code exchange failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('TP code exchange error: $e');
    }
    return false;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$_kAuthBase/oauth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'client_id': _kClientId,
              'client_secret': _kClientSecret,
              'grant_type': 'refresh_token',
              'refresh_token': _refreshToken!,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        await _saveTokens(
          accessToken: json['access_token'] as String,
          refreshToken: json['refresh_token'] as String,
          expiresIn: (json['expires_in'] as num).toInt(),
        );
        return true;
      }
    } catch (e) {
      debugPrint('TP token refresh error: $e');
    }
    return false;
  }

  /// Returns a valid (non-expired) access token, refreshing if needed.
  Future<String?> _getValidToken() async {
    await _loadTokens();
    if (_accessToken == null) return null;

    // Refresh 60 s before expiry
    final expiry = _expiresAt;
    if (expiry != null &&
        DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)))) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        await disconnect();
        return null;
      }
    }
    return _accessToken;
  }

  Future<void> _fetchProfile() async {
    final token = await _getValidToken();
    if (token == null) return;
    try {
      final resp = await http
          .get(
            Uri.parse('$_kApiBase/v1/athlete/profile'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final id = j['Id']?.toString() ?? '';
        final first = (j['FirstName'] as String?) ?? '';
        final last = (j['LastName'] as String?) ?? '';
        final name = '$first $last'.trim();
        _athleteId = id;
        _athleteName = name.isNotEmpty ? name : id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPrefAthleteId, id);
        await prefs.setString(_kPrefAthleteName, _athleteName!);
      }
    } catch (e) {
      debugPrint('TP fetch profile error: $e');
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────

  Future<void> _loadTokens() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kPrefAccessToken);
    _refreshToken = prefs.getString(_kPrefRefreshToken);
    final expiresMs = prefs.getInt(_kPrefExpiresAt);
    _expiresAt = expiresMs != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
        : null;
    _athleteId = prefs.getString(_kPrefAthleteId);
    _athleteName = prefs.getString(_kPrefAthleteName);
    _state = (_accessToken != null && _athleteId != null)
        ? TrainingPeaksConnectionState.connected
        : TrainingPeaksConnectionState.disconnected;
  }

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefAccessToken, accessToken);
    await prefs.setString(_kPrefRefreshToken, refreshToken);
    await prefs.setInt(_kPrefExpiresAt, _expiresAt!.millisecondsSinceEpoch);
  }

  void _emit(TrainingPeaksConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'User-Agent': 'RunnerCompanion/1.0',
  };

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void dispose() {
    _stateController.close();
  }
}

enum TrainingPeaksConnectionState { disconnected, connecting, connected }

enum TrainingPeaksConnectResult {
  success,
  cancelled,
  notConfigured,
  tokenError,
  error,
}
