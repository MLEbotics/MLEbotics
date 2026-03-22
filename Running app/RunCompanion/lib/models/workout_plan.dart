import 'package:xml/xml.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum StepType {
  warmup,
  active, // fast / interval
  recovery, // jog / easy
  rest, // walk or full stop
  cooldown,
}

enum DurationType { time, distance }

// ─── WorkoutStep ─────────────────────────────────────────────────────────────

class WorkoutStep {
  final String name;
  final StepType type;
  final DurationType durationType;

  /// Seconds if durationType == time, else metres if distance.
  final double duration;

  /// Middle of pace range sent to robot (km/h).
  final double targetPaceKmh;
  final double minPaceKmh;
  final double maxPaceKmh;

  const WorkoutStep({
    required this.name,
    required this.type,
    required this.durationType,
    required this.duration,
    required this.targetPaceKmh,
    this.minPaceKmh = 0,
    this.maxPaceKmh = 0,
  });

  /// Friendly label for display (e.g. "5:00/km" or "10.0 km/h").
  String get paceLabel {
    if (targetPaceKmh <= 0) return 'walk';
    final minPerKm = 60.0 / targetPaceKmh;
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}/km';
  }

  /// Duration as a human-readable string.
  String get durationLabel {
    if (durationType == DurationType.distance) {
      return duration >= 1000
          ? '${(duration / 1000).toStringAsFixed(1)} km'
          : '${duration.toInt()} m';
    }
    final d = duration.toInt();
    final m = d ~/ 60;
    final s = d % 60;
    return m > 0 ? (s > 0 ? '${m}m ${s}s' : '${m}m') : '${s}s';
  }

  /// Estimated time in seconds for this step.
  double get estimatedSeconds {
    if (durationType == DurationType.time) return duration;
    if (targetPaceKmh > 0) {
      return (duration / 1000) / targetPaceKmh * 3600;
    }
    return duration / (4.0 / 3.6); // fallback: assume 4 km/h walk
  }

  /// Estimated distance in metres for this step.
  double get estimatedMetres {
    if (durationType == DurationType.distance) return duration;
    return (targetPaceKmh / 3600) * 1000 * estimatedSeconds;
  }

  StepType get _effectiveType => type;

  // ── UI colour coding ──────────────────────────────────────────────
  int get colorValue {
    switch (_effectiveType) {
      case StepType.warmup:
        return 0xFF43A047; // green
      case StepType.active:
        return 0xFFEF6C00; // orange
      case StepType.recovery:
        return 0xFF1E88E5; // blue
      case StepType.rest:
        return 0xFF757575; // grey
      case StepType.cooldown:
        return 0xFF00897B; // teal
    }
  }

  @override
  String toString() => 'WorkoutStep($name, $paceLabel, $durationLabel)';
}

// ─── WorkoutPlan ─────────────────────────────────────────────────────────────

class WorkoutPlan {
  final String name;
  final String source; // "Garmin Connect", "TrainingPeaks", "Manual"
  final DateTime createdAt;

  /// Flat, fully expanded list of steps (repeats already unrolled).
  final List<WorkoutStep> steps;

  WorkoutPlan({
    required this.name,
    required this.steps,
    this.source = 'Manual',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Duration get estimatedDuration => Duration(
    seconds: steps
        .fold<double>(0, (sum, s) => sum + s.estimatedSeconds)
        .toInt(),
  );

  double get totalDistanceKm =>
      steps.fold<double>(0, (sum, s) => sum + s.estimatedMetres) / 1000;

  // ─── TCX parser (Garmin Connect / TrainingPeaks export) ──────────

  /// Parse a `.tcx` workout file exported from Garmin Connect or TrainingPeaks.
  ///
  /// Supports:
  ///  • Time-based steps (`<Duration xsi:type="Time_t">`)
  ///  • Distance-based steps (`<Duration xsi:type="Distance_t">`)
  ///  • Repeat blocks (`<Step xsi:type="Repeat_t">`)
  ///  • Custom speed zones (metres/second → km/h)
  ///  • Heart-rate targeted steps (pace inferred from intensity)
  static WorkoutPlan fromTcx(String xmlContent) {
    final doc = XmlDocument.parse(xmlContent);

    // Workout element — try both namespaced and plain
    final workoutEls = doc.findAllElements('Workout');
    if (workoutEls.isEmpty) {
      throw FormatException('No <Workout> element found in TCX file.');
    }
    final workoutEl = workoutEls.first;

    final nameEl = workoutEl.findElements('Name');
    final workoutName = nameEl.isNotEmpty
        ? nameEl.first.innerText.trim()
        : 'Imported Workout';

    final steps = <WorkoutStep>[];
    for (final child in workoutEl.childElements) {
      if (child.name.local == 'Step') {
        steps.addAll(_parseStepElement(child));
      }
    }

    if (steps.isEmpty) {
      throw FormatException('No workout steps found in TCX file.');
    }

    return WorkoutPlan(
      name: workoutName,
      steps: steps,
      source: 'Garmin / TrainingPeaks',
    );
  }

  // ── TCX step parser (recursive for repeat blocks) ────────────────

  static List<WorkoutStep> _parseStepElement(XmlElement el) {
    final xsiType =
        el.getAttribute('xsi:type') ?? el.getAttribute('type') ?? '';

    if (xsiType.contains('Repeat')) {
      // ── Repeat_t: unroll into flat list ──────────────────────────
      final repsEl = el.findElements('Repetitions');
      final reps = repsEl.isNotEmpty
          ? int.tryParse(repsEl.first.innerText) ?? 1
          : 1;
      final childSteps = <WorkoutStep>[];
      for (final child in el.childElements) {
        if (child.name.local == 'Child') {
          childSteps.addAll(_parseStepElement(child));
        }
      }
      final expanded = <WorkoutStep>[];
      for (var i = 0; i < reps; i++) {
        expanded.addAll(childSteps);
      }
      return expanded;
    }

    // ── Single Step_t ─────────────────────────────────────────────
    final nameEl = el.findElements('Name');
    final stepName = nameEl.isNotEmpty ? nameEl.first.innerText.trim() : 'Step';

    final intensityEl = el.findElements('Intensity');
    final intensity = intensityEl.isNotEmpty
        ? intensityEl.first.innerText.toLowerCase()
        : 'active';

    // Determine step type from name + intensity
    StepType stepType;
    final lname = stepName.toLowerCase();
    if (lname.contains('warm')) {
      stepType = StepType.warmup;
    } else if (lname.contains('cool')) {
      stepType = StepType.cooldown;
    } else if (intensity == 'resting' ||
        lname.contains('rest') ||
        lname.contains('walk')) {
      stepType = StepType.rest;
    } else if (lname.contains('recover') ||
        lname.contains('jog') ||
        lname.contains('easy')) {
      stepType = StepType.recovery;
    } else {
      stepType = StepType.active;
    }

    // Duration
    DurationType durationType = DurationType.time;
    double duration = 60; // fallback 1 minute

    final durationEl = el.findElements('Duration');
    if (durationEl.isNotEmpty) {
      final d = durationEl.first;
      final dtype = d.getAttribute('xsi:type') ?? '';
      if (dtype.contains('Time')) {
        final secsEl = d.findElements('Seconds');
        duration = secsEl.isNotEmpty
            ? double.tryParse(secsEl.first.innerText) ?? 60
            : 60;
        durationType = DurationType.time;
      } else if (dtype.contains('Distance')) {
        final mEl = d.findElements('Meters');
        duration = mEl.isNotEmpty
            ? double.tryParse(mEl.first.innerText) ?? 400
            : 400;
        durationType = DurationType.distance;
      }
    }

    // Target pace — from speed zone or inferred from intensity/name
    double minSpeedMs = 0, maxSpeedMs = 0;

    final targetEl = el.findElements('Target');
    if (targetEl.isNotEmpty) {
      final t = targetEl.first;
      final ttype = t.getAttribute('xsi:type') ?? '';
      if (ttype.contains('Speed')) {
        final zoneEl = t.findElements('SpeedZone');
        if (zoneEl.isNotEmpty) {
          final z = zoneEl.first;
          final lowEl = z.findElements('LowInMetersPerSecond');
          final highEl = z.findElements('HighInMetersPerSecond');
          minSpeedMs = lowEl.isNotEmpty
              ? double.tryParse(lowEl.first.innerText) ?? 0
              : 0;
          maxSpeedMs = highEl.isNotEmpty
              ? double.tryParse(highEl.first.innerText) ?? 0
              : 0;
        }
        // Garmin speed zone number (1–7) fallback
        final numberEl = t.findElements('Number');
        if (numberEl.isNotEmpty && minSpeedMs == 0) {
          final zone = int.tryParse(numberEl.first.innerText) ?? 3;
          final speeds = [0.0, 2.0, 2.5, 3.0, 3.5, 4.2, 5.0, 6.0];
          minSpeedMs = speeds[(zone - 1).clamp(0, 6)];
          maxSpeedMs = speeds[zone.clamp(0, 7)];
        }
      }
    }

    double minKmh = minSpeedMs * 3.6;
    double maxKmh = maxSpeedMs * 3.6;
    double targetKmh;

    if (minKmh > 0 && maxKmh > 0) {
      targetKmh = (minKmh + maxKmh) / 2;
    } else if (minKmh > 0) {
      targetKmh = minKmh;
    } else {
      // No speed target in file — infer from step type
      targetKmh = _inferPaceKmh(stepType);
    }

    return [
      WorkoutStep(
        name: stepName,
        type: stepType,
        durationType: durationType,
        duration: duration,
        targetPaceKmh: targetKmh,
        minPaceKmh: minKmh,
        maxPaceKmh: maxKmh,
      ),
    ];
  }

  /// Fallback pace when TCX has no speed target (e.g. HR-targeted workouts).
  static double _inferPaceKmh(StepType type) {
    switch (type) {
      case StepType.warmup:
        return 7.0; // ~8:34/km easy jog
      case StepType.active:
        return 12.0; // ~5:00/km tempo
      case StepType.recovery:
        return 8.0; // ~7:30/km jog
      case StepType.rest:
        return 4.5; // ~13:20/km walk
      case StepType.cooldown:
        return 7.0;
    }
  }

  // ─── Manual builder convenience constructors ─────────────────────

  static WorkoutStep manualStep({
    required String name,
    required StepType type,
    required double targetPaceKmh,
    double durationMinutes = 5,
    double durationMetres = 0,
  }) {
    final isDistance = durationMetres > 0;
    return WorkoutStep(
      name: name,
      type: type,
      durationType: isDistance ? DurationType.distance : DurationType.time,
      duration: isDistance ? durationMetres : durationMinutes * 60,
      targetPaceKmh: targetPaceKmh,
    );
  }

  // ─── TrainingPeaks description text parser ────────────────────────
  //
  // Parses free-form workout descriptions that coaches write in
  // TrainingPeaks (or share via email/message). Handles formats like:
  //
  //   WU: 15min easy jog
  //   MS: 8x400m @ 4:30/km w/ 400m jog recovery
  //   CD: 10 minutes easy
  //
  //   Warm up 15 minutes easy, then 5 × (3min @ 5:00/km + 2min recovery jog)
  //   Cool down 10 min
  //
  //   10min Z1, 4x(5min Z4 @ 12km/h + 2min Z1), 10min Z1
  //
  static WorkoutPlan fromText(String text, {String name = 'Imported Workout'}) {
    if (text.trim().isEmpty) {
      throw FormatException('No workout text provided.');
    }

    // ── Tokenise: split on newlines and commas, then trim ────────────
    final rawTokens = text
        .replaceAll(RegExp(r'\bthen\b', caseSensitive: false), ',')
        .replaceAll(RegExp(r'\bfollowed by\b', caseSensitive: false), ',')
        .replaceAll(RegExp(r'\bafter that\b', caseSensitive: false), ',')
        .split(RegExp(r'[;\n]'))
        .expand((line) => line.split(','))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final steps = <WorkoutStep>[];
    for (final token in rawTokens) {
      steps.addAll(_parseTextToken(token));
    }

    if (steps.isEmpty) {
      throw FormatException(
        'Could not parse any workout steps. '
        'Try the format: "10min easy, 5x400m @ 4:30/km w/ 200m jog, 10min easy"',
      );
    }

    return WorkoutPlan(
      name: name,
      steps: steps,
      source: 'TrainingPeaks / Text',
    );
  }

  // ── Parse a single token which may be a repeat block ─────────────
  static List<WorkoutStep> _parseTextToken(String token) {
    // Match repeat: "8x400m...", "8 x (...)", "8×(...)", "8 times ..."
    final repeatRe = RegExp(
      r'^(\d+)\s*[×xX]\s*\((.+)\)$',
      caseSensitive: false,
    );
    final repeatSimpleRe = RegExp(
      r'^(\d+)\s*[×xX]\s*(.+)$',
      caseSensitive: false,
    );

    final mRepeat = repeatRe.firstMatch(token.trim());
    if (mRepeat != null) {
      final reps = int.parse(mRepeat.group(1)!);
      final inner = mRepeat.group(2)!;
      // Inner may have + or / separating active + recovery
      final parts = inner.split(RegExp(r'\s*[+/]\s*'));
      final innerSteps = parts.expand(_parseTextToken).toList();
      return List.generate(reps, (_) => innerSteps).expand((s) => s).toList();
    }

    final mRepeatSimple = repeatSimpleRe.firstMatch(token.trim());
    if (mRepeatSimple != null) {
      final reps = int.parse(mRepeatSimple.group(1)!);
      final inner = mRepeatSimple.group(2)!;
      // Make sure this isn't something like "8km @ pace" (distance with unit)
      if (!RegExp(
        r'^\d+\s*(km|m|mi|miles?)\b',
        caseSensitive: false,
      ).hasMatch(inner)) {
        final innerSteps = _parseSingleTextStep(inner);
        return List.generate(reps, (_) => innerSteps).expand((s) => s).toList();
      }
    }

    return _parseSingleTextStep(token);
  }

  // ── Parse a single step description string ───────────────────────
  static List<WorkoutStep> _parseSingleTextStep(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return [];

    // ── Duration ─────────────────────────────────────────────────────
    DurationType durationType = DurationType.time;
    double duration = 300; // fallback 5 min

    // Distance first (metres / km / miles)
    final distRe = RegExp(
      r'(\d+(?:\.\d+)?)\s*(km|k|m(?:i(?:les?)?)?|meters?|metres?)',
      caseSensitive: false,
    );
    final mDist = distRe.firstMatch(s);

    // Time (minutes / seconds / hours)
    final timeRe = RegExp(
      r'(\d+(?:\.\d+)?)\s*(h(?:rs?|ours?)?|min(?:utes?)?|s(?:ec(?:onds?)?)?)',
      caseSensitive: false,
    );
    final mTime = timeRe.firstMatch(s);

    bool hasDistance = false;
    if (mDist != null) {
      final val = double.parse(mDist.group(1)!);
      final unit = mDist.group(2)!.toLowerCase();
      double metres;
      if (unit.startsWith('k')) {
        metres = val * 1000;
      } else if (unit.startsWith('mi')) {
        metres = val * 1609.34;
      } else {
        metres = val; // metres
      }
      // Only treat as distance step if value is plausible (not something like
      // "4:30/km" where the number is pace, not distance)
      if (metres >= 50) {
        duration = metres;
        durationType = DurationType.distance;
        hasDistance = true;
      }
    }

    if (!hasDistance && mTime != null) {
      final val = double.parse(mTime.group(1)!);
      final unit = mTime.group(2)!.toLowerCase();
      if (unit.startsWith('h')) {
        duration = val * 3600;
      } else if (unit.startsWith('s')) {
        duration = val;
      } else {
        duration = val * 60; // minutes
      }
      durationType = DurationType.time;
    }

    // ── Pace / speed target ───────────────────────────────────────────
    double targetKmh = 0;

    // km/h speed: "@ 12 km/h", "@ 12kph", "12 km/h"
    final speedRe = RegExp(
      r'@?\s*(\d+(?:\.\d+)?)\s*(?:km[/ ]?h|kph)',
      caseSensitive: false,
    );
    final mSpeed = speedRe.firstMatch(s);
    if (mSpeed != null) {
      targetKmh = double.parse(mSpeed.group(1)!);
    }

    // min/km pace: "@ 4:30/km", "4:30 per km", "4:30 pace"
    if (targetKmh == 0) {
      final paceRe = RegExp(
        r'@?\s*(\d+):(\d{2})\s*(?:/\s*km|per\s*km|/?mi(?:le)?|pace)?',
        caseSensitive: false,
      );
      final mPace = paceRe.firstMatch(s);
      if (mPace != null) {
        final mins = double.parse(mPace.group(1)!);
        final secs = double.parse(mPace.group(2)!);
        final minPerKm = mins + secs / 60;
        if (minPerKm > 0) {
          final isMiles = (mPace.group(0) ?? '').toLowerCase().contains('mi');
          targetKmh = isMiles
              ? 1.60934 / (minPerKm / 60)
              : 1.0 / (minPerKm / 60);
        }
      }
    }

    // Zone shorthand Z1–Z5 or "zone 3" etc.
    if (targetKmh == 0) {
      final zoneRe = RegExp(r'\bz(?:one\s*)?([1-5])\b', caseSensitive: false);
      final mZone = zoneRe.firstMatch(s);
      if (mZone != null) {
        const zoneKmh = [5.5, 7.5, 9.5, 12.0, 15.0];
        final z = (int.tryParse(mZone.group(1)!) ?? 3) - 1;
        targetKmh = zoneKmh[z.clamp(0, 4)];
      }
    }

    // ── Step type from keywords ───────────────────────────────────────
    final lower = s.toLowerCase();
    StepType stepType;
    if (RegExp(r'\b(warm[- ]?up|wu|w/u)\b').hasMatch(lower)) {
      stepType = StepType.warmup;
    } else if (RegExp(r'\b(cool[- ]?down|cd|c/d)\b').hasMatch(lower)) {
      stepType = StepType.cooldown;
    } else if (RegExp(r'\b(rest|walk|standing)\b').hasMatch(lower)) {
      stepType = StepType.rest;
    } else if (RegExp(
      r'\b(recover|recovery|jog(?:ging)?|easy|light|z[12]|zone\s*[12])\b',
    ).hasMatch(lower)) {
      stepType = StepType.recovery;
    } else if (RegExp(
      r'\b(interval|tempo|hard|fast|effort|push|race|sprint|'
      r'threshold|lactate|lt|5k|10k|z[345]|zone\s*[345]|active|'
      r'work)\b',
    ).hasMatch(lower)) {
      stepType = StepType.active;
    } else {
      // Default: if pace is fast (< 5:30/km = > 10.9 km/h) → active, else recovery
      stepType = (targetKmh > 0 && targetKmh >= 10)
          ? StepType.active
          : StepType.recovery;
    }

    // Apply pace inference if still 0
    if (targetKmh == 0) targetKmh = _inferPaceKmh(stepType);

    // ── Name: strip pace/duration markers, keep descriptive label ────
    String name = s
        .replaceAll(
          RegExp(
            r'@\s*[\d:\.]+\s*(?:/km|/mi|km/?h|kph|pace)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b\d+(?:\.\d+)?\s*(?:km|m|mi(?:les?)?|min(?:utes?)?|sec(?:onds?)?|h(?:rs?|ours?)?)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\b[wW][uU]\b|\b[cC][dD]\b'), '')
        .replaceAll(RegExp(r'\bw/\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[:\-–]+\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // If stripping leaves nothing meaningful, use a type-based default label
    if (name.length < 3) {
      name = switch (stepType) {
        StepType.warmup => 'Warm Up',
        StepType.active => 'Interval',
        StepType.recovery => 'Recovery',
        StepType.rest => 'Rest',
        StepType.cooldown => 'Cool Down',
      };
    }

    return [
      WorkoutStep(
        name: name,
        type: stepType,
        durationType: durationType,
        duration: duration,
        targetPaceKmh: targetKmh,
      ),
    ];
  }
}
