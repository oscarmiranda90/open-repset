enum WorkoutSetType { warmup, working }

/// The display/input unit belongs to the exercise entry. Set loads remain
/// canonical kilograms so session volume and future history stay consistent.
enum WorkoutWeightUnit {
  kilograms('kg'),
  pounds('lb');

  const WorkoutWeightUnit(this.label);
  final String label;
}

class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.position,
    this.repetitions = 0,
    this.loadKg = 0,
    this.rpe,
    this.notes = '',
    this.type = WorkoutSetType.working,
    this.isCompleted = false,
    this.completedAt,
  }) : assert(rpe == null || (rpe >= 6 && rpe <= 10));

  final String id;
  final String exerciseId;
  final int position;
  final int repetitions;
  final double loadKg;
  final double? rpe;
  final String notes;
  final WorkoutSetType type;
  final bool isCompleted;
  final DateTime? completedAt;

  double get volumeKg => isCompleted ? loadKg * repetitions : 0;

  WorkoutSet copyWith({
    int? position,
    int? repetitions,
    double? loadKg,
    double? rpe,
    bool clearRpe = false,
    String? notes,
    WorkoutSetType? type,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => WorkoutSet(
    id: id,
    exerciseId: exerciseId,
    position: position ?? this.position,
    repetitions: repetitions ?? this.repetitions,
    loadKg: loadKg ?? this.loadKg,
    rpe: clearRpe ? null : rpe ?? this.rpe,
    notes: notes ?? this.notes,
    type: type ?? this.type,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.position,
    this.weightUnit = WorkoutWeightUnit.kilograms,
    this.restSeconds = 120,
    this.supersetId,
    this.notes = '',
    this.sets = const [],
  }) : assert(restSeconds >= 15 && restSeconds <= 600);

  /// Stable ID for this occurrence. A catalog exercise can appear twice.
  final String id;
  final String exerciseId;
  final String name;
  final int position;
  final WorkoutWeightUnit weightUnit;
  final int restSeconds;
  final String? supersetId;
  final String notes;
  final List<WorkoutSet> sets;

  WorkoutExercise copyWith({
    int? position,
    WorkoutWeightUnit? weightUnit,
    int? restSeconds,
    String? supersetId,
    bool clearSuperset = false,
    String? notes,
    List<WorkoutSet>? sets,
  }) => WorkoutExercise(
    id: id,
    exerciseId: exerciseId,
    name: name,
    position: position ?? this.position,
    weightUnit: weightUnit ?? this.weightUnit,
    restSeconds: restSeconds ?? this.restSeconds,
    supersetId: clearSuperset ? null : supersetId ?? this.supersetId,
    notes: notes ?? this.notes,
    sets: sets ?? this.sets,
  );
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.exercises,
    this.completedAt,
    this.title = "Today's Workout",
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<WorkoutExercise> exercises;

  bool get isActive => completedAt == null;
  List<WorkoutSet> get sets =>
      exercises.expand((exercise) => exercise.sets).toList(growable: false);
  int get completedSetCount => sets.where((set) => set.isCompleted).length;
  double get volumeKg => sets.fold(0, (total, set) => total + set.volumeKg);

  WorkoutSession copyWith({
    String? title,
    List<WorkoutExercise>? exercises,
    DateTime? completedAt,
  }) => WorkoutSession(
    id: id,
    title: title ?? this.title,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    exercises: exercises ?? this.exercises,
  );
}
