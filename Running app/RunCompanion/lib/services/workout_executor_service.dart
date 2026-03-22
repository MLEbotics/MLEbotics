import 'dart:async';
import '../models/workout_plan.dart';
import 'robot_service.dart';

// ─── State emitted every tick ─────────────────────────────────────────────────

class WorkoutProgress {
  final WorkoutPlan plan;
  final int stepIndex; // current step (0-based in flat list)
  final WorkoutStep step; // current step data
  final double stepElapsed; // seconds elapsed in current step
  final double stepRemaining; // seconds remaining in current step (time steps)
  final Duration totalElapsed;
  final bool isRunning;
  final bool isPaused;
  final bool isComplete;

  const WorkoutProgress({
    required this.plan,
    required this.stepIndex,
    required this.step,
    required this.stepElapsed,
    required this.stepRemaining,
    required this.totalElapsed,
    required this.isRunning,
    required this.isPaused,
    required this.isComplete,
  });

  /// 0.0 – 1.0 progress through the current step (time-based only).
  double get stepFraction {
    if (step.durationType == DurationType.distance) return 0;
    if (step.duration <= 0) return 1;
    return (stepElapsed / step.duration).clamp(0.0, 1.0);
  }

  /// 0.0 – 1.0 progress through the entire workout (by estimated time).
  double get totalFraction {
    final total = plan.estimatedDuration.inSeconds.toDouble();
    if (total <= 0) return 0;
    return (totalElapsed.inSeconds / total).clamp(0.0, 1.0);
  }
}

// ─── WorkoutExecutorService ───────────────────────────────────────────────────

/// Executes a [WorkoutPlan] step by step, controlling the robot's pace at each
/// step. The robot is the pacer; the runner follows.
///
/// Usage:
///   final exec = WorkoutExecutorService(robotService);
///   exec.start(plan);
///   exec.progressStream.listen((p) { ... });
///   exec.stop();
class WorkoutExecutorService {
  final RobotService _robot;

  WorkoutPlan? _plan;
  int _stepIndex = 0;
  double _stepElapsed = 0; // seconds elapsed in current step
  Duration _totalElapsed = Duration.zero;
  bool _running = false;
  bool _paused = false;

  Timer? _ticker;

  final _progressController = StreamController<WorkoutProgress>.broadcast();

  /// Live progress stream — emits every second during execution.
  Stream<WorkoutProgress> get progressStream => _progressController.stream;

  bool get isRunning => _running;
  bool get isPaused => _paused;
  WorkoutPlan? get activePlan => _plan;
  int get currentStepIndex => _stepIndex;

  WorkoutExecutorService(this._robot);

  // ─── Control ─────────────────────────────────────────────────────

  /// Start executing [plan]. Immediately sets the robot to the first step's pace.
  void start(WorkoutPlan plan) {
    stop(); // clean up any previous session
    _plan = plan;
    _stepIndex = 0;
    _stepElapsed = 0;
    _totalElapsed = Duration.zero;
    _running = true;
    _paused = false;

    _applyCurrentStepPace();
    _emitProgress();

    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void pause() {
    if (!_running || _paused) return;
    _paused = true;
    _robot.updatePace(0); // stop robot while paused
    _emitProgress();
  }

  void resume() {
    if (!_running || !_paused) return;
    _paused = false;
    _applyCurrentStepPace();
    _emitProgress();
  }

  void stop() {
    _running = false;
    _paused = false;
    _ticker?.cancel();
    _ticker = null;
    if (_plan != null) {
      _robot.updatePace(0); // stop robot
    }
    _plan = null;
  }

  void dispose() {
    stop();
    _progressController.close();
  }

  // ─── Internal ────────────────────────────────────────────────────

  void _tick(Timer _) {
    if (!_running || _paused) return;

    _stepElapsed += 1;
    _totalElapsed += const Duration(seconds: 1);

    final step = _currentStep;

    // Advance step when time-based duration expires.
    // Distance-based steps advance when the robot's GPS reports enough distance
    // (handled separately via advanceStepByDistance() from UI), but we also
    // auto-advance after 3× the estimated time as a safety fallback.
    bool advance = false;
    if (step.durationType == DurationType.time) {
      if (_stepElapsed >= step.duration) advance = true;
    } else {
      // Safety timeout: 3× estimated time
      if (_stepElapsed >= step.estimatedSeconds * 3) advance = true;
    }

    if (advance) {
      _nextStep();
    } else {
      _emitProgress();
    }
  }

  void _nextStep() {
    final plan = _plan!;
    _stepIndex++;
    _stepElapsed = 0;

    if (_stepIndex >= plan.steps.length) {
      // Workout complete
      _running = false;
      _ticker?.cancel();
      _robot.updatePace(0);
      _progressController.add(
        WorkoutProgress(
          plan: plan,
          stepIndex: plan.steps.length - 1,
          step: plan.steps.last,
          stepElapsed: plan.steps.last.duration,
          stepRemaining: 0,
          totalElapsed: _totalElapsed,
          isRunning: false,
          isPaused: false,
          isComplete: true,
        ),
      );
      return;
    }

    _applyCurrentStepPace();
    _emitProgress();
  }

  /// Called from UI when the robot's GPS distance triggers step advance
  /// (for distance-based steps).
  void advanceStepByDistance() {
    if (!_running || _paused) return;
    _nextStep();
  }

  void _applyCurrentStepPace() {
    final step = _currentStep;
    _robot.updatePace(step.targetPaceKmh);
  }

  WorkoutStep get _currentStep => _plan!.steps[_stepIndex];

  void _emitProgress() {
    if (_progressController.isClosed || _plan == null) return;
    final step = _currentStep;
    final remaining = step.durationType == DurationType.time
        ? (step.duration - _stepElapsed).clamp(0.0, step.duration)
        : 0.0;
    _progressController.add(
      WorkoutProgress(
        plan: _plan!,
        stepIndex: _stepIndex,
        step: step,
        stepElapsed: _stepElapsed,
        stepRemaining: remaining,
        totalElapsed: _totalElapsed,
        isRunning: _running,
        isPaused: _paused,
        isComplete: false,
      ),
    );
  }
}
