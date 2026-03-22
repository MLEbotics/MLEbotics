import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/training_peaks_service.dart';
import 'workout_upload_screen.dart';

// ── TrainingPeaksScreen ───────────────────────────────────────────────────────
//
// Connects the app to TrainingPeaks via OAuth 2.0 and shows today's planned
// workouts. Tap "Run with Robot" to send any planned run straight to the robot
// without manually uploading a file.
//
// First-time setup (developer):
//   See the constants in lib/services/training_peaks_service.dart
//   (_kClientId / _kClientSecret). Apply at https://developer.trainingpeaks.com/
// ─────────────────────────────────────────────────────────────────────────────

class TrainingPeaksScreen extends StatefulWidget {
  const TrainingPeaksScreen({super.key});

  @override
  State<TrainingPeaksScreen> createState() => _TrainingPeaksScreenState();
}

class _TrainingPeaksScreenState extends State<TrainingPeaksScreen> {
  final _svc = TrainingPeaksService.instance;

  bool _loading = true;
  bool _connected = false;
  String? _athleteName;

  List<TpWorkout> _workouts = [];
  bool _fetchingWorkouts = false;
  String? _workoutsError;

  // Per-workout loading state (for "Run with Robot")
  final Map<int, bool> _loadingPlan = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final connected = await _svc.isConnected();
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _athleteName = _svc.athleteName;
      _loading = false;
    });
    if (connected) await _refreshWorkouts();
  }

  Future<void> _connect() async {
    final result = await _svc.connect();
    if (!mounted) return;
    switch (result) {
      case TrainingPeaksConnectResult.success:
        setState(() {
          _connected = true;
          _athleteName = _svc.athleteName;
        });
        await _refreshWorkouts();
      case TrainingPeaksConnectResult.notConfigured:
        _showSetupDialog();
      case TrainingPeaksConnectResult.cancelled:
        break; // user cancelled — do nothing
      case TrainingPeaksConnectResult.tokenError:
      case TrainingPeaksConnectResult.error:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Disconnect TrainingPeaks?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your account will be unlinked. You can reconnect at any time.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _svc.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _athleteName = null;
      _workouts = [];
    });
  }

  Future<void> _refreshWorkouts() async {
    if (!mounted) return;
    setState(() {
      _fetchingWorkouts = true;
      _workoutsError = null;
    });
    try {
      final list = await _svc.getTodaysWorkouts();
      if (!mounted) return;
      setState(() {
        _workouts = list;
        _fetchingWorkouts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workoutsError = 'Could not load workouts. Check your connection.';
        _fetchingWorkouts = false;
      });
    }
  }

  Future<void> _runWorkout(TpWorkout workout) async {
    setState(() => _loadingPlan[workout.id] = true);
    try {
      final plan = await _svc.fetchWorkoutPlan(workout);
      if (!mounted) return;
      if (plan == null || plan.steps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No structured steps found for "${workout.title}". '
              'Try opening it manually in TrainingPeaks and exporting as TCX.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutUploadScreen(initialPlan: plan),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPlan.remove(workout.id));
    }
  }

  void _showSetupDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: const [
            Icon(Icons.build_outlined, color: Colors.orange),
            SizedBox(width: 12),
            Text(
              'API Credentials Required',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To enable direct TrainingPeaks sync, you need to register '
                'this app as a TrainingPeaks API partner:',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              SizedBox(height: 16),
              _SetupStep(
                n: '1',
                text:
                    'Visit developer.trainingpeaks.com and apply for API access',
              ),
              _SetupStep(
                n: '2',
                text:
                    'Register redirect URI:\nrunnercompanion://trainingpeaks-callback',
              ),
              _SetupStep(
                n: '3',
                text: 'Receive your client_id and client_secret',
              ),
              _SetupStep(
                n: '4',
                text:
                    'Open lib/services/training_peaks_service.dart and paste them into _kClientId and _kClientSecret',
              ),
              _SetupStep(n: '5', text: 'Rebuild and try again'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              launchUrl(
                Uri.parse('https://developer.trainingpeaks.com/'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Open Developer Portal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.network(
              'https://developer.trainingpeaks.com/assets/images/tp-logo-white.png',
              height: 22,
              errorBuilder: (context, error, stack) => const Text(
                'TrainingPeaks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          if (_connected)
            IconButton(
              tooltip: 'Refresh today\'s workouts',
              icon: _fetchingWorkouts
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _fetchingWorkouts ? null : _refreshWorkouts,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _connected
          ? _buildConnectedView()
          : _buildConnectView(),
    );
  }

  // ── Disconnected view ─────────────────────────────────────────────

  Widget _buildConnectView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Icon(
              Icons.sync_alt_rounded,
              size: 56,
              color: Colors.deepPurpleAccent,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connect TrainingPeaks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sync directly with your TrainingPeaks account.\n'
            'When your coach schedules a workout, the app will show it here\n'
            'and you can run it on the robot with one tap — no file uploading.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
          const SizedBox(height: 32),
          _featureRow(Icons.today, 'Today\'s planned workouts — auto-fetched'),
          _featureRow(
            Icons.smart_toy_rounded,
            'Run any workout on the robot with one tap',
          ),
          _featureRow(Icons.route, 'Structured steps: paces, intervals, zones'),
          _featureRow(Icons.refresh, 'Token auto-refreshes — sign in once'),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _connect,
              icon: _svc.state == TrainingPeaksConnectionState.connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: const Text('Connect with TrainingPeaks'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.trainingpeaks.com'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              'Don\'t have TrainingPeaks? Sign up free',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          if (!_svc.isConfigured) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade700),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.build_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Developer Setup Required',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'API credentials not yet configured. '
                          'Tap "Connect" for setup instructions.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.deepPurpleAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connected view ────────────────────────────────────────────────

  Widget _buildConnectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileBanner(),
        Expanded(child: _buildWorkoutsList()),
      ],
    );
  }

  Widget _buildProfileBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF1A0030),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _athleteName ?? 'TrainingPeaks Account',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Connected',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _disconnect,
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsList() {
    final today = DateTime.now();
    final label = '${_monthName(today.month)} ${today.day}, ${today.year}';

    if (_fetchingWorkouts) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.deepPurpleAccent),
            SizedBox(height: 12),
            Text(
              'Loading today\'s workouts…',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (_workoutsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              _workoutsError!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshWorkouts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No workouts planned for today',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _refreshWorkouts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check again'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.today, color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              Text(
                'Today — $label',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
        ..._workouts.map((w) => _buildWorkoutCard(w)),
      ],
    );
  }

  Widget _buildWorkoutCard(TpWorkout workout) {
    final isRun = workout.isRun;
    final isLoadingThis = _loadingPlan[workout.id] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRun
              ? Colors.deepPurple.withValues(alpha: 0.5)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Row(
              children: [
                _workoutTypeIcon(workout.workoutType),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    workout.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (workout.completed)
                  const Chip(
                    label: Text(
                      'Done',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),

            // ── Metrics ──────────────────────────────────────────────
            if (workout.distanceLabel.isNotEmpty ||
                workout.durationLabel.isNotEmpty ||
                workout.paceLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  if (workout.distanceLabel.isNotEmpty)
                    _chip(Icons.straighten, workout.distanceLabel),
                  if (workout.durationLabel.isNotEmpty)
                    _chip(Icons.timer, workout.durationLabel),
                  if (workout.paceLabel.isNotEmpty)
                    _chip(Icons.speed, workout.paceLabel),
                ],
              ),
            ],

            // ── Description snippet ───────────────────────────────────
            if (workout.description != null &&
                workout.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                workout.description!.trim().length > 120
                    ? '${workout.description!.trim().substring(0, 120)}…'
                    : workout.description!.trim(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],

            // ── Action buttons ────────────────────────────────────────
            const SizedBox(height: 14),
            Row(
              children: [
                // Open in TrainingPeaks
                if (workout.url != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(workout.url!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('View', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                const Spacer(),
                // Run with Robot
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRun
                        ? Colors.deepPurple
                        : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isLoadingThis ? null : () => _runWorkout(workout),
                  icon: isLoadingThis
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.smart_toy_rounded, size: 16),
                  label: Text(
                    isLoadingThis
                        ? 'Loading…'
                        : isRun
                        ? 'Run with Robot'
                        : 'Not a run',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _workoutTypeIcon(String type) {
    final t = type.toLowerCase();
    IconData icon;
    Color color;
    if (t.contains('run')) {
      icon = Icons.directions_run;
      color = Colors.deepPurpleAccent;
    } else if (t.contains('bike') || t.contains('cycl')) {
      icon = Icons.directions_bike;
      color = Colors.blue;
    } else if (t.contains('swim')) {
      icon = Icons.pool;
      color = Colors.cyan;
    } else if (t.contains('strength')) {
      icon = Icons.fitness_center;
      color = Colors.orange;
    } else {
      icon = Icons.sports;
      color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  String _monthName(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];
}

// ── Small widget helpers ────────────────────────────────────────────────────

class _SetupStep extends StatelessWidget {
  final String n;
  final String text;
  const _SetupStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
