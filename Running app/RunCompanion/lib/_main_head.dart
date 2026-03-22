import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/robot_preorder_screen.dart';
import 'services/subscription_service.dart';
import 'screens/pace_workout_screen.dart';
import 'screens/pacer_pro_screen.dart';
import 'screens/workout_upload_screen.dart';
import 'screens/robot_navigation_screen.dart';
import 'screens/training_peaks_screen.dart';
import 'screens/aid_station_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/phone_brain_screen.dart';
import 'screens/runner_alert_screen.dart';
import 'screens/hybrid_modules_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/voice_service.dart';
import 'services/hybrid_module_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/support_screen.dart';
import 'screens/robot_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init ΓÇö wrapped so browser tracking prevention can't crash the app
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // On web, use LOCAL persistence so sign-in survives new tabs and
    // browser restarts. Falls back silently if storage is blocked.
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (e) {
        debugPrint('Firebase auth persistence warning: $e');
      }
    }
  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }

  // If user previously opted out of "stay signed in", sign them out now
  try {
    final prefs = await SharedPreferences.getInstance();
    final staySignedIn = prefs.getBool('stay_signed_in') ?? true;
    if (!staySignedIn && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  } catch (e) {
    debugPrint('SharedPreferences warning: $e');
  }

  // Stripe is supported on Android, iOS, and Web only
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      Stripe.publishableKey =
          'pk_test_51T5ZQRFOfNksyV0v2DhLprJnBaC9hVxj7wC98n9YbfmpIDCqPw0i89Q6LQmo53NXHXqPqNDK8iIdd4jZRP6QFq4k00wQ7g7O90';
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Stripe init warning: $e');
    }
  }
  runApp(const RunnerCompanionApp());
}

class RunnerCompanionApp extends StatelessWidget {
  const RunnerCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // '/' always shows the marketing / download home screen.
      // '/app' is the actual robot control app (reached after sign-in).
      // '/reset-password' handles Firebase password-reset action links.
      home: const _HomeRouter(),
      routes: {
        '/': (_) => const LoginScreen(),
        '/app': (_) => const RobotControlPage(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/reset-password': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments;
          final code = (args is String) ? args : '';
          return ResetPasswordScreen(oobCode: code);
        },
      },
    );
  }
}

// Detects Firebase Auth action links (?mode=resetPassword&oobCode=...) on
// initial load and routes to the appropriate screen.
// Also skips the login screen if the user is already signed in.
class _HomeRouter extends StatefulWidget {
  const _HomeRouter();
  @override
  State<_HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<_HomeRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialRoute());
  }

  void _checkInitialRoute() async {
    if (!mounted) return;

    // Show onboarding to first-time users
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!seen) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Handle Firebase password-reset action links (web only)
    if (kIsWeb) {
      final uri = Uri.base;
      final mode = uri.queryParameters['mode'];
      final oobCode = uri.queryParameters['oobCode'] ?? '';
      if (mode == 'resetPassword' && oobCode.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(oobCode: oobCode),
          ),
        );
        return;
      }
    }

    // AUTH DISABLED ΓÇö skip login, allow everyone in directly.
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RobotControlPage()),
    );
  }

  @override
  Widget build(BuildContext context) => const RobotControlPage();
}

class RobotControlPage extends StatefulWidget {
  const RobotControlPage({super.key});

  @override
  State<RobotControlPage> createState() => _RobotControlPageState();
}

class _RobotControlPageState extends State<RobotControlPage> {
  String _status = 'Idle';
  String _mode = 'None';
  bool _isConnected = false;
  DateTime? _modeStartTime;
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _hybridService = HybridModuleService.instance;
  final _subscriptionService = SubscriptionService.instance;

  @override
  void initState() {
    super.initState();
    _hybridService.ensureAutoRefresh();
    _subscriptionService.startListening();
  }

  @override
  void dispose() {
    _subscriptionService.stopListening();
    super.dispose();
  }

  void _sendCommand(String command) {
    setState(() => _status = command);
    // TODO: Replace with actual TCP/WebSocket/BLE commands to your robot.
  }

  void _toggleConnection() {
    setState(() {
      _isConnected = !_isConnected;
      _status = _isConnected ? 'Connected' : 'Disconnected';
    });
    // TODO: Replace with actual connection logic.
  }

  Future<void> _logRun(String mode) async {
    // Save any previous active mode with duration
    if (_modeStartTime != null && _mode != 'None' && _mode != 'Stopped') {
      final dur = DateTime.now().difference(_modeStartTime!);
      await _firestoreService.saveRunSession(
        mode: _mode,
        startTime: _modeStartTime!,
        duration: dur,
      );
    }
    _modeStartTime = DateTime.now();
  }

  Future<void> _checkHybridUpdates() async {
    await _hybridService.loadModules(forceRefresh: true);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cloud modules refreshed.')));
  }

  String _hybridStatus(HybridSyncState state) {
    if (state.lastSync == null) return 'Cloud modules have not synced yet.';
    final rel = _relativeTime(state.lastSync!);
    final version = state.manifestVersion != null
        ? 'v${state.manifestVersion}'
        : 'n/a';
    return 'Last sync $rel ($version)';
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _logout(BuildContext context) async {
    await _authService.logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  Future<void> _editName(BuildContext context) async {
    final user = _authService.currentUser;
    final parts = (user?.displayName ?? '').trim().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final firstCtrl = TextEditingController(text: firstName);
    final lastCtrl = TextEditingController(text: lastName);
    final formKey = GlobalKey<FormState>();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.person, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Edit Name'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstCtrl,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newName =
                    '${firstCtrl.text.trim()} ${lastCtrl.text.trim()}';
                try {
                  await user?.updateDisplayName(newName);
                  await user?.reload();
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {}); // refresh greeting
                } catch (e) {
                  setStateDialog(() => error = e.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF00796B)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Run History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder(
                stream: _firestoreService.getRunHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_run,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No runs yet. Start your first run!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final mode = data['mode'] ?? 'Run';
                      final time =
                          (data['startTime'] as dynamic)?.toDate() as DateTime?;
                      final durationSecs = data['durationSeconds'] as int?;
                      final distKm = (data['distanceKm'] as num?)?.toDouble();
                      final hr = data['avgHeartRate'] as int?;
                      final cadence = data['avgCadence'] as int?;

                      String dateStr = '';
                      if (time != null) {
                        dateStr =
                            '${time.day}/${time.month}/${time.year}  ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                      }

                      String durationStr = '';
                      if (durationSecs != null && durationSecs > 0) {
                        final d = Duration(seconds: durationSecs);
                        String two(int n) => n.toString().padLeft(2, '0');
                        durationStr =
                            '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
                      }

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Colors.red.shade700,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.white),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete run?'),
                                  content: const Text(
                                    'This run will be permanently removed.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) =>
                            _firestoreService.deleteRunSession(doc.id),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade50,
                            child: const Icon(
                              Icons.directions_run,
                              color: Color(0xFF00796B),
                            ),
                          ),
                          title: Text(
                            mode,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Wrap(
                                spacing: 10,
                                children: [
                                  if (durationStr.isNotEmpty)
                                    _runChip(
                                      Icons.timer,
                                      durationStr,
                                      Colors.blue,
                                    ),
                                  if (distKm != null && distKm > 0)
                                    _runChip(
                                      Icons.straighten,
                                      '${distKm.toStringAsFixed(2)} km',
                                      Colors.teal,
                                    ),
                                  if (hr != null && hr > 0)
                                    _runChip(
                                      Icons.favorite,
                                      '$hr bpm',
                                      Colors.red,
                                    ),
                                  if (cadence != null && cadence > 0)
                                    _runChip(
                                      Icons.accessibility_new,
                                      '$cadence spm',
                                      Colors.orange,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            tooltip: 'Delete',
                            onPressed: () async {
                              final ok =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete run?'),
                                      content: const Text(
                                        'This run will be permanently removed.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (ok) {
                                _firestoreService.deleteRunSession(doc.id);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final userEmail = user?.email ?? '';
    final displayName = user?.displayName;
    final greeting = displayName != null && displayName.isNotEmpty
        ? displayName.split(' ').first
        : (userEmail.contains('@') ? userEmail.split('@').first : userEmail);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.directions_run,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Running Companion',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          // BT status pill
          GestureDetector(
            onTap: _toggleConnection,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.teal.withValues(alpha: 0.25)
                    : Colors.red.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isConnected ? Colors.tealAccent : Colors.redAccent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: _isConnected ? Colors.tealAccent : Colors.redAccent,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isConnected
                          ? Colors.tealAccent
                          : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.teal.shade300,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      greeting.isNotEmpty ? greeting[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            tooltip: greeting,
            onSelected: (value) {
              if (value == 'logout') _logout(context);
              if (value == 'history') _showHistory(context);
              if (value == 'edit_name') _editName(context);
              if (value == 'robot_setup') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RobotSetupScreen(isFirstTime: false),
                  ),
                );
              }
              if (value == 'robot_setup_first') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RobotSetupScreen(isFirstTime: true),
                  ),
                );
              }
              if (value == 'support') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                );
              }
              if (value == 'billing') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              }
              if (value == 'preorder') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RobotPreOrderScreen(),
                  ),
                );
              }
              if (value == 'download') {
                launchUrl(
                  Uri.parse('https://runningcompanion.web.app/download'),
                  mode: LaunchMode.platformDefault,
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      userEmail,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: ValueListenableBuilder<SubscriptionStatus>(
                  valueListenable: _subscriptionService.status,
                  builder: (_, status, _) => Row(
                    children: [
                      Icon(
                        status.isPremium
                            ? Icons.star_rounded
                            : Icons.star_outline,
                        size: 16,
                        color: status.isPremium ? Colors.amber : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.isPremium ? 'Premium' : 'Free plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: status.isPremium
                              ? Colors.amber.shade700
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'robot_setup',
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(
                      'Robot WiFi Setup',
                      style: TextStyle(
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'robot_setup_first',
                child: Row(
                  children: [
                    Icon(Icons.settings_remote, size: 18),
                    SizedBox(width: 8),
                    Text('First-Time Robot Setup'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'billing',
                child: Row(
                  children: [
                    Icon(Icons.credit_card, size: 18),
                    SizedBox(width: 8),
                    Text('Plans & Billing'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preorder',
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, size: 18),
                    SizedBox(width: 8),
                    Text('Pre-Order RunBot'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: Color(0xFF00796B),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Download App',
                      style: TextStyle(
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'edit_name',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Name'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('Run History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'support',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Help & Support'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Log Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_modeStartTime != null && _mode != 'None' && _mode != 'Stopped') {
            final dur = DateTime.now().difference(_modeStartTime!);
            await _firestoreService.saveRunSession(
              mode: _mode,
              startTime: _modeStartTime!,
              duration: dur,
            );
            _modeStartTime = null;
          }
          setState(() => _mode = 'Stopped');
          _sendCommand('stop');
        },
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.stop_rounded),
        label: const Text(
          'Stop Robot',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _connectionBanner(greeting),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FEATURES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _featureCard(
                        icon: Icons.directions_run,
                        label: 'Start Following',
                        subtitle: 'Robot follows you',
                        color: const Color(0xFF00796B),
                        onTap: () {
                          setState(() => _mode = 'Follow Me');
                          _sendCommand('follow_me');
                          _logRun('Follow Me');
                        },
                      ),
                      _featureCard(
                        icon: Icons.speed,
                        label: 'Pace Workout',
                        subtitle: 'Set your target pace',
                        color: Colors.deepOrange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaceWorkoutScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.timer_rounded,
                        label: 'Pacer Pro',
                        subtitle: 'GPS pace + intervals',
                        color: const Color(0xFF388BFD),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PacerProScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.assignment,
                        label: 'Coach Workout',
                        subtitle: 'Upload Garmin / TrainingPeaks plan',
                        color: const Color(0xFF6A1B9A),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkoutUploadScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.navigation_rounded,
                        label: 'Navigate Robot',
                        subtitle: 'Send robot to a map location',
                        color: const Color(0xFF00695C),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RobotNavigationScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.sync_alt_rounded,
                        label: 'TrainingPeaks',
                        subtitle: 'Today\'s plan ΓÇö auto-synced',
                        color: const Color(0xFF4A148C),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrainingPeaksScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.inventory_2_rounded,
                        label: 'Aid Station',
                        subtitle: 'Hydration & gels',
                        color: const Color(0xFF1565C0),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AidStationScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.smart_toy_rounded,
                        label: 'RunBot AI',
                        subtitle: 'AI training coach',
                        color: const Color(0xFF1A237E),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AiChatScreen(
                              workoutContext: const WorkoutContext(),
                            ),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.campaign_rounded,
                        label: 'Alert Ahead',
                        subtitle: 'Notify your contacts',
                        color: const Color(0xFF7B1FA2),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RunnerAlertScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.phonelink_setup_rounded,
                        label: 'Phone-as-Brain',
                        subtitle: 'Use phone as CPU',
                        color: const Color(0xFF0D47A1),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PhoneBrainScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.cloud_sync_rounded,
                        label: 'Cloud Modules',
                        subtitle: 'Hybrid OTA sync',
                        color: const Color(0xFF00695C),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HybridModulesScreen(),
                          ),
                        ),
                      ),
                      _featureCard(
                        icon: Icons.precision_manufacturing_rounded,
                        label: 'Pre-Order RunBot',
                        subtitle: 'Reserve your robot',
                        color: const Color(0xFF37474F),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RobotPreOrderScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ROBOT MODES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeButton(
                          label: 'Pace',
                          icon: Icons.speed,
                          color: Colors.deepOrange.shade700,
                          onPressed: () {
                            setState(() => _mode = 'Pace');
                            _sendCommand('set_mode_pace');
                            _logRun('Pace');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeButton(
                          label: 'Guard',
                          icon: Icons.security,
                          color: Colors.indigo,
                          onPressed: () {
                            setState(() => _mode = 'Guard');
                            _sendCommand('set_mode_guard');
                            _logRun('Guard');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeButton(
                          label: 'Return',
                          icon: Icons.home_rounded,
                          color: Colors.green.shade700,
                          onPressed: () {
                            setState(() => _mode = 'Return Home');
                            _sendCommand('return_home');
                            _logRun('Return Home');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeButton(
                          label: 'History',
                          icon: Icons.history,
                          color: Colors.blueGrey.shade600,
                          onPressed: () => _showHistory(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ΓöÇΓöÇ Bottom status bar ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _StatusIndicator(
                  icon: Icons.battery_full,
                  label: 'Battery',
                  value: '--%',
                ),
                _StatusIndicator(
                  icon: Icons.gps_fixed,
                  label: 'GPS',
                  value: 'No fix',
                ),
                _StatusIndicator(
                  icon: Icons.network_wifi,
                  label: 'Signal',
                  value: '--',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ΓöÇΓöÇ Connection banner ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _connectionBanner(String greeting) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isConnected
              ? [const Color(0xFF004D40), const Color(0xFF00796B)]
              : [const Color(0xFF37474F), const Color(0xFF546E7A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isConnected ? const Color(0xFF00796B) : Colors.grey)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isConnected ? Icons.directions_run : Icons.power_off_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, $greeting! ≡ƒæï',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isConnected
                      ? 'Robot connected ┬╖ Mode: $_mode'
                      : 'Robot not connected ΓÇö tap BT to connect',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<HybridSyncState>(
            valueListenable: _hybridService.syncState,
            builder: (context, state, _) => GestureDetector(
              onTap: state.isSyncing ? null : _checkHybridUpdates,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.isSyncing ? Icons.sync : Icons.cloud_sync_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.isSyncing ? 'Syncing' : 'Sync',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ΓöÇΓöÇ Feature card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Widget _featureCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: onPressed,
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusIndicator({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
