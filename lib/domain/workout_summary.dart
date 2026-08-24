import 'workout_repository.dart';
import 'workout_session.dart';

/// A record set during the session that just ended.
///
/// Records compare the session against history that excludes it, so the
/// comparison has to happen before the session is persisted as completed.
class WorkoutRecord {
  const WorkoutRecord({
    required this.exerciseName,
    required this.kind,
    required this.value,
    required this.previousValue,
  });

  final String exerciseName;
  final WorkoutRecordKind kind;

  /// The new best, in kilograms for load and volume records.
  final double value;

  /// The previous best, or 0 when this is the first ever entry.
  final double previousValue;

  /// A first-time entry is a milestone, not an improvement over something.
  bool get isFirstTime => previousValue <= 0;

  double get improvement => value - previousValue;
}

enum WorkoutRecordKind {
  /// Heaviest completed set for an exercise.
  heaviestSet,

  /// Highest single-session volume for an exercise.
  sessionVolume,
}

/// Everything the finished-workout summary needs, computed once.
class WorkoutSummary {
  const WorkoutSummary({
    required this.session,
    required this.records,
    required this.previousSessionVolumeKg,
    required this.completedSessionCount,
  });

  final WorkoutSession session;
  final List<WorkoutRecord> records;

  /// Total volume of the most recent completed session before this one, or 0
  /// when this is the first. Drives the "vs last session" comparison.
  final double previousSessionVolumeKg;

  /// How many sessions were already completed before this one.
  final int completedSessionCount;

  Duration get duration =>
      (session.completedAt ?? DateTime.now()).difference(session.startedAt);

  int get completedSetCount => session.completedSetCount;

  double get volumeKg => session.volumeKg;

  int get exerciseCount => session.exercises
      .where((exercise) => exercise.sets.any((set) => set.isCompleted))
      .length;

  int get totalReps => session.sets
      .where((set) => set.isCompleted)
      .fold(0, (total, set) => total + set.repetitions);

  /// Average RPE across completed sets that recorded one, or null when none did.
  double? get averageRpe {
    final rated = session.sets
        .where((set) => set.isCompleted && set.rpe != null)
        .toList(growable: false);
    if (rated.isEmpty) return null;
    final total = rated.fold<double>(0, (sum, set) => sum + set.rpe!);
    return total / rated.length;
  }

  /// Heaviest completed set of the session, in kilograms.
  double get heaviestSetKg => session.sets
      .where((set) => set.isCompleted)
      .fold<double>(0, (best, set) => set.loadKg > best ? set.loadKg : best);

  bool get isFirstSession => completedSessionCount == 0;

  bool get hasVolumeComparison => previousSessionVolumeKg > 0;

  /// Change against the previous session as a fraction (0.12 == +12%).
  double get volumeDelta => hasVolumeComparison
      ? (volumeKg - previousSessionVolumeKg) / previousSessionVolumeKg
      : 0;
}

/// Builds a [WorkoutSummary] for a session that is finishing.
///
/// [session] must NOT yet be saved with a `completedAt`: the repository counts
/// only completed sessions as history, so persisting first would fold this
/// session into its own baseline and every record would read as a tie.
Future<WorkoutSummary> buildWorkoutSummary({
  required WorkoutSession session,
  required WorkoutRepository repository,
}) async {
  final completed = await repository.getCompletedSessions();
  final records = <WorkoutRecord>[];

  for (final exercise in session.exercises) {
    final completedSets = exercise.sets
        .where((set) => set.isCompleted)
        .toList(growable: false);
    if (completedSets.isEmpty) continue;

    final history = await repository.getExerciseHistory(exercise.exerciseId);

    final heaviest = completedSets.fold<double>(
      0,
      (best, set) => set.loadKg > best ? set.loadKg : best,
    );
    if (heaviest > 0 && heaviest > history.bestLoadKg) {
      records.add(
        WorkoutRecord(
          exerciseName: exercise.name,
          kind: WorkoutRecordKind.heaviestSet,
          value: heaviest,
          previousValue: history.bestLoadKg,
        ),
      );
    }

    final sessionVolume = completedSets.fold<double>(
      0,
      (total, set) => total + set.volumeKg,
    );
    final bestPreviousVolume = _bestSessionVolume(
      completed,
      exercise.exerciseId,
    );
    if (sessionVolume > 0 && sessionVolume > bestPreviousVolume) {
      records.add(
        WorkoutRecord(
          exerciseName: exercise.name,
          kind: WorkoutRecordKind.sessionVolume,
          value: sessionVolume,
          previousValue: bestPreviousVolume,
        ),
      );
    }
  }

  // Heaviest-set records read as the bigger achievement, so they lead.
  records.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return b.improvement.compareTo(a.improvement);
  });

  return WorkoutSummary(
    session: session,
    records: records,
    previousSessionVolumeKg: _latestSessionVolume(completed),
    completedSessionCount: completed.length,
  );
}

double _bestSessionVolume(List<WorkoutSession> sessions, String exerciseId) {
  var best = 0.0;
  for (final session in sessions) {
    final volume = session.exercises
        .where((exercise) => exercise.exerciseId == exerciseId)
        .expand((exercise) => exercise.sets)
        .fold<double>(0, (total, set) => total + set.volumeKg);
    if (volume > best) best = volume;
  }
  return best;
}

double _latestSessionVolume(List<WorkoutSession> sessions) {
  if (sessions.isEmpty) return 0;
  final ordered = [...sessions]
    ..sort((a, b) {
      final aAt = a.completedAt ?? a.startedAt;
      final bAt = b.completedAt ?? b.startedAt;
      return bAt.compareTo(aAt);
    });
  return ordered.first.volumeKg;
}
