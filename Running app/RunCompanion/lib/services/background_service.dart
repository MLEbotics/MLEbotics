import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Wraps flutter_foreground_task to keep the app process alive when the
/// phone screen turns off during a run.
///
/// Android requires a persistent notification to allow a foreground service.
/// We use that notification to show live workout stats (pace, HR, distance)
/// so the runner gets info from the notification shade without waking the phone.
///
/// On web this is a no-op — foreground services are Android/iOS only.
class BackgroundService {
  BackgroundService._();
  static final instance = BackgroundService._();

  bool _initialised = false;

  // ── One-time setup (call from main or first screen) ───────────────────────
  void init() {
    if (_initialised) return;
    _initialised = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'runbot_workout',
        channelName: 'RunBot Workout',
        channelDescription: 'Shows live workout stats while the screen is off.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // No sound / vibration — just a quiet info bar
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000), // every 1 s
        autoRunOnBoot: false,
        allowWakeLock: true, // keep CPU awake — screen can still turn off
        allowWifiLock: true, // keep WiFi (robot comms) awake
      ),
    );
  }

  // ── Start foreground service when workout begins ──────────────────────────
  Future<void> startWorkout({
    required double paceKmh,
    int heartRate = 0,
    double distanceKm = 0,
  }) async {
    init();

    final body = _buildBody(paceKmh: paceKmh, hr: heartRate, km: distanceKm);

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '🏃 RunBot — Workout Active',
      notificationText: body,
      notificationIcon: null,
    );
  }

  // ── Update notification every second with fresh stats ────────────────────
  Future<void> updateStats({
    required double paceKmh,
    required Duration elapsed,
    int heartRate = 0,
    double distanceKm = 0,
    int cadence = 0,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) return;

    final body = _buildBody(
      paceKmh: paceKmh,
      hr: heartRate,
      km: distanceKm,
      cadence: cadence,
      elapsed: elapsed,
    );

    await FlutterForegroundTask.updateService(
      notificationTitle: '🏃 RunBot — ${_fmtElapsed(elapsed)}',
      notificationText: body,
    );
  }

  // ── Stop foreground service when workout ends ─────────────────────────────
  Future<void> stopWorkout() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildBody({
    required double paceKmh,
    int hr = 0,
    double km = 0,
    int cadence = 0,
    Duration elapsed = Duration.zero,
  }) {
    final pace = _paceStr(paceKmh);
    final parts = <String>[pace];
    if (km > 0) parts.add('${km.toStringAsFixed(2)} km');
    if (hr > 0) parts.add('❤ $hr bpm');
    if (cadence > 0) parts.add('$cadence spm');
    return parts.join('  •  ');
  }

  String _paceStr(double kmh) {
    if (kmh < 0.1) return '--:-- /km';
    final minsPerKm = 60.0 / kmh;
    final m = minsPerKm.floor();
    final s = ((minsPerKm - m) * 60).round().toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
