import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/workout_plan.dart';
import '../services/robot_service.dart';
import '../services/workout_executor_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkoutUploadScreen
//
// Step 1: Import a .tcx file exported from Garmin Connect or TrainingPeaks,
//         OR build a workout manually by adding steps.
// Step 2: Preview the parsed workout (flat step list, estimated time/distance).
// Step 3: Start — robot executes each step at the prescribed pace.
//         Runner follows the robot.  When the runner falls behind, the robot's
//         existing adaptive logic (back ultrasonic + Garmin BLE speed)
//         automatically eases off until they catch up.
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutUploadScreen extends StatefulWidget {
  /// Optional pre-loaded plan — set by TrainingPeaks screen so the user
  /// lands directly on the execution view without manually importing.
  final WorkoutPlan? initialPlan;

  /// When true, "Start" is replaced with "Use This Plan" which pops the route
  /// with the WorkoutPlan instead of executing it against the robot.
  final bool returnPlanOnly;

  const WorkoutUploadScreen({
    super.key,
    this.initialPlan,
    this.returnPlanOnly = false,
  });

  @override
  State<WorkoutUploadScreen> createState() => _WorkoutUploadScreenState();
}

class _WorkoutUploadScreenState extends State<WorkoutUploadScreen>
    with SingleTickerProviderStateMixin {
  final _robot = RobotService();
  late final WorkoutExecutorService _executor;

  WorkoutPlan? _plan;
  String? _importError;
  bool _importing = false;

  // Manual builder state
  final _manualNameController = TextEditingController(text: 'My Workout');
  final List<_EditableStep> _manualSteps = [];

  // Paste-text state
  final _pasteController = TextEditingController();
  final _pasteNameController = TextEditingController(text: 'Imported Workout');

  late final TabController _tabController;

  // Execution state
  WorkoutProgress? _progress;
  bool get _isExecuting => _progress != null && _progress!.isRunning;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _executor = WorkoutExecutorService(_robot);
    _executor.progressStream.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    _pasteController.addListener(() => setState(() {}));
    // If a plan was passed in (e.g. from TrainingPeaks), load it immediately
    if (widget.initialPlan != null) {
      _plan = widget.initialPlan;
    }
    _robot.startPolling();
  }

  @override
  void dispose() {
    _executor.dispose();
    _robot.stopPolling();
    _tabController.dispose();
    _manualNameController.dispose();
    _pasteController.dispose();
    _pasteNameController.dispose();
    for (final s in _manualSteps) {
      s.dispose();
    }
    super.dispose();
  }

  // ── File import ───────────────────────────────────────────────────

  Future<void> _pickTcxFile() async {
    setState(() {
      _importing = true;
      _importError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tcx', 'TCX'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        // Web / bytes path
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file.');
      }

      final plan = WorkoutPlan.fromTcx(content);
      setState(() {
        _plan = plan;
        _importing = false;
      });
    } catch (e) {
      setState(() {
        _importError = e.toString().replaceFirst('Exception: ', '');
        _importing = false;
      });
    }
  }

  // ── Paste text import ─────────────────────────────────────────────

  void _parsePastedText() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a workout description first.')),
      );
      return;
    }
    setState(() => _importError = null);
    try {
      final name = _pasteNameController.text.trim().isNotEmpty
          ? _pasteNameController.text.trim()
          : 'Imported Workout';
      final plan = WorkoutPlan.fromText(text, name: name);
      setState(() => _plan = plan);
    } catch (e) {
      setState(
        () => _importError = e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Widget _buildPasteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Paste TrainingPeaks Workout Description'),
          const SizedBox(height: 8),
          const Text(
            'Copy the workout description your coach wrote in TrainingPeaks '
            '(or any structured text) and paste it below. '
            'The robot will run each step at the prescribed pace.',
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 16),

          // ── Hint card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Supported formats',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...[
                  'WU: 15min easy jog',
                  '8 × 400m @ 4:30/km  w/ 400m recovery',
                  '5x(3min @ 12km/h + 2min easy jog)',
                  '10min Z4  (TrainingPeaks zone notation)',
                  'CD: 10 minutes easy',
                ].map(
                  (ex) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Text(
                          '  • ',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                        Text(
                          ex,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── How to get text from TrainingPeaks ──────────────────
          _howToCard(
            icon: Icons.terrain,
            title: 'Find the description in TrainingPeaks',
            steps: [
              'Open the workout in TrainingPeaks',
              'Look for the "Description" or "Notes" field',
              'Copy the workout text → paste below',
              'Or copy from your coach\'s email / message',
            ],
          ),
          const SizedBox(height: 20),

          // ── Workout name ─────────────────────────────────────────
          TextField(
            controller: _pasteNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Workout Name',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Paste area ───────────────────────────────────────────
          TextField(
            controller: _pasteController,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'WU: 15min easy\n8x400m @ 4:30/km w/ 200m jog\nCD: 10min easy',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_pasteController.text.trim().split('\n').where((l) => l.trim().isNotEmpty).length} lines',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),

          if (_importError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade900),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _importError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _parsePastedText,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Parse Workout'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual builder ────────────────────────────────────────────────

  void _addManualStep() {
    setState(() {
      _manualSteps.add(_EditableStep());
    });
  }

  void _removeStep(int i) => setState(() => _manualSteps.removeAt(i));

  void _buildManualPlan() {
    if (_manualSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one step first.')),
      );
      return;
    }

    final steps = _manualSteps.map((e) => e.toWorkoutStep()).toList();
    setState(() {
      _plan = WorkoutPlan(
        name: _manualNameController.text.trim().isNotEmpty
            ? _manualNameController.text.trim()
            : 'My Workout',
        steps: steps,
        source: 'Manual',
      );
    });
  }

  // ── Execution control ─────────────────────────────────────────────

  void _startWorkout() {
    if (_plan == null) return;
    _executor.start(_plan!);
  }

  void _stopWorkout() {
    _executor.stop();
    setState(() => _progress = null);
  }

  void _togglePause() {
    if (_executor.isPaused) {
      _executor.resume();
    } else {
      _executor.pause();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show execution view when workout is running
    if (_isExecuting) return _buildExecutionView();

    // Show completion banner when done
    if (_progress != null && _progress!.isComplete) {
      return _buildCompleteView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Coach Workout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Import File'),
            Tab(icon: Icon(Icons.content_paste), text: 'Paste Text'),
            Tab(icon: Icon(Icons.build), text: 'Build Manual'),
          ],
          isScrollable: true,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImportTab(),
                _buildPasteTab(),
                _buildManualTab(),
              ],
            ),
          ),
          if (_plan != null) _buildPlanPreview(),
        ],
      ),
    );
  }

  // ── Import tab ────────────────────────────────────────────────────

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Import from Garmin Connect or TrainingPeaks'),
          const SizedBox(height: 8),
          const Text(
            'Export your coach-designed workout as a .tcx file then upload it here. '
            'The robot will run each interval at the exact prescribed pace.',
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 20),

          // How-to steps
          _howToCard(
            icon: Icons.watch,
            title: 'From Garmin Connect',
            steps: [
              'Open Garmin Connect (web or app)',
              'Go to Training → Workouts',
              'Select your workout → Export → Export TCX',
            ],
          ),
          const SizedBox(height: 12),
          _howToCard(
            icon: Icons.terrain,
            title: 'From TrainingPeaks',
            steps: [
              'Open TrainingPeaks',
              'Go to Workouts library → select workout',
              'Click  ···  → Export → TCX',
            ],
          ),
          const SizedBox(height: 24),

          // Upload button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _importing ? null : _pickTcxFile,
              icon: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_importing ? 'Importing…' : 'Choose .tcx File'),
            ),
          ),

          if (_importError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade900),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _importError!,
                      style: const TextStyle(color: Colors.red),
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

  // ── Manual builder tab ────────────────────────────────────────────

  Widget _buildManualTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _manualNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Workout Name',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Expanded(
          child: _manualSteps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.playlist_add,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No steps yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add warmup, intervals, recovery, cooldown',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _manualSteps.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final step = _manualSteps.removeAt(oldIndex);
                      _manualSteps.insert(newIndex, step);
                    });
                  },
                  itemBuilder: (ctx, i) => _StepEditorCard(
                    key: ValueKey(_manualSteps[i]),
                    step: _manualSteps[i],
                    onDelete: () => _removeStep(i),
                    onChanged: () => setState(() {}),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _addManualStep,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Step'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _buildManualPlan,
                  icon: const Icon(Icons.check),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Plan preview (shown below tabs) ──────────────────────────────

  Widget _buildPlanPreview() {
    final plan = _plan!;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${plan.steps.length} steps  ·  '
                        '~${_fmtDuration(plan.estimatedDuration)}  ·  '
                        '~${plan.totalDistanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.returnPlanOnly
                        ? Colors.teal
                        : Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: widget.returnPlanOnly
                      ? () => Navigator.pop(context, _plan)
                      : _startWorkout,
                  icon: Icon(
                    widget.returnPlanOnly
                        ? Icons.check_circle_outline
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    widget.returnPlanOnly ? 'Use This Plan' : 'Start',
                  ),
                ),
              ],
            ),
          ),
          // Step swimlane
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: plan.steps.length,
              itemBuilder: (ctx, i) {
                final s = plan.steps[i];
                return _StepChip(step: s, index: i);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Execution view ────────────────────────────────────────────────

  Widget _buildExecutionView() {
    final p = _progress!;
    final step = p.step;
    final stepColor = Color(step.colorValue);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  Text(
                    p.plan.name,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Step ${p.stepIndex + 1} / ${p.plan.steps.length}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current step card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: stepColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stepColor.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stepColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            step.type.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_run,
                          color: Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          step.paceLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${step.targetPaceKmh.toStringAsFixed(1)} km/h',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Step progress bar (time steps only)
                    if (step.durationType == DurationType.time) ...[
                      LinearProgressIndicator(
                        value: p.stepFraction,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(stepColor),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            _fmtSeconds(p.stepElapsed.toInt()),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '-${_fmtSeconds(p.stepRemaining.toInt())}',
                            style: TextStyle(color: stepColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Distance step — show elapsed time + button to advance
                      Text(
                        '${step.durationLabel}  ·  ${_fmtSeconds(p.stepElapsed.toInt())} elapsed',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Upcoming steps
              Expanded(child: _buildUpcomingSteps(p)),

              // Overall progress
              const SizedBox(height: 12),
              _buildProgressBar(p),
              const SizedBox(height: 20),

              // Controls
              Row(
                children: [
                  // Pause / Resume
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _togglePause,
                      icon: Icon(p.isPaused ? Icons.play_arrow : Icons.pause),
                      label: Text(p.isPaused ? 'Resume' : 'Pause'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Skip step (distance-based convenience)
                  if (step.durationType == DurationType.distance)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0x33FFFFFF)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _executor.advanceStepByDistance,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Step Done'),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Stop
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade900),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _confirmStop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSteps(WorkoutProgress p) {
    final remaining = p.plan.steps.sublist(
      (p.stepIndex + 1).clamp(0, p.plan.steps.length),
    );
    if (remaining.isEmpty) {
      return const Center(
        child: Text(
          'Last step!',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: remaining.length.clamp(0, 4),
            itemBuilder: (ctx, i) {
              final s = remaining[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: Color(s.colorValue), width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Text(
                        s.paceLabel,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.durationLabel,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(WorkoutProgress p) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              _fmtDuration(p.totalElapsed),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            Text(
              _fmtDuration(p.plan.estimatedDuration),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: p.totalFraction,
          backgroundColor: Colors.white10,
          valueColor: const AlwaysStoppedAnimation(Colors.orange),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  // ── Completion view ───────────────────────────────────────────────

  Widget _buildCompleteView() {
    final p = _progress!;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text(
                'Workout Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(p.plan.name, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                _fmtDuration(p.totalElapsed),
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _progress = null;
                      _plan = null;
                    });
                  },
                  child: const Text(
                    'Back to Workouts',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Future<void> _confirmStop() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Stop Workout?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The robot will stop and the workout will end.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (yes == true) _stopWorkout();
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
  );

  Widget _howToCard({
    required IconData icon,
    required String title,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ...steps.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _fmtSeconds(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step chip for preview swimlane
// ─────────────────────────────────────────────────────────────────────────────

class _StepChip extends StatelessWidget {
  final WorkoutStep step;
  final int index;

  const _StepChip({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = Color(step.colorValue);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            step.name,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            step.paceLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            step.durationLabel,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editable step for manual builder
// ─────────────────────────────────────────────────────────────────────────────

class _EditableStep {
  final nameCtrl = TextEditingController(text: 'Step');
  final paceCtrl = TextEditingController(text: '10.0');
  final durationCtrl = TextEditingController(text: '5');
  StepType type = StepType.active;
  DurationType durationType = DurationType.time;

  WorkoutStep toWorkoutStep() {
    final name = nameCtrl.text.trim().isNotEmpty
        ? nameCtrl.text.trim()
        : 'Step';
    final pace = double.tryParse(paceCtrl.text) ?? 10.0;
    final dur = double.tryParse(durationCtrl.text) ?? 5;
    return WorkoutStep(
      name: name,
      type: type,
      durationType: durationType,
      duration: durationType == DurationType.time ? dur * 60 : dur,
      targetPaceKmh: pace,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    paceCtrl.dispose();
    durationCtrl.dispose();
  }
}

class _StepEditorCard extends StatefulWidget {
  final _EditableStep step;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _StepEditorCard({
    super.key,
    required this.step,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_StepEditorCard> createState() => _StepEditorCardState();
}

class _StepEditorCardState extends State<_StepEditorCard> {
  static const _types = StepType.values;
  static const _typeLabels = [
    'Warmup',
    'Active',
    'Recovery',
    'Rest',
    'Cooldown',
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    final color = Color(s.toWorkoutStep().colorValue);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Drag handle
                const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                // Type selector
                DropdownButton<StepType>(
                  value: s.type,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  underline: const SizedBox(),
                  items: _types
                      .asMap()
                      .entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.value,
                          child: Text(
                            _typeLabels[e.key],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => s.type = v);
                      widget.onChanged();
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _field(s.nameCtrl, 'Name', Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _field(
                    s.paceCtrl,
                    'km/h',
                    Colors.orange,
                    inputType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _field(
                    s.durationCtrl,
                    s.durationType == DurationType.time ? 'min' : 'metres',
                    Colors.white54,
                    inputType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 4),
                // Toggle time / distance
                IconButton(
                  icon: Icon(
                    s.durationType == DurationType.time
                        ? Icons.timer
                        : Icons.straighten,
                    color: Colors.white38,
                    size: 20,
                  ),
                  tooltip: s.durationType == DurationType.time
                      ? 'Switch to distance'
                      : 'Switch to time',
                  onPressed: () {
                    setState(() {
                      s.durationType = s.durationType == DurationType.time
                          ? DurationType.distance
                          : DurationType.time;
                      s.durationCtrl.text = s.durationType == DurationType.time
                          ? '5'
                          : '400';
                    });
                    widget.onChanged();
                  },
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    Color labelColor, {
    TextInputType inputType = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    keyboardType: inputType,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor, fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF111111),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onChanged: (_) => widget.onChanged(),
  );
}
