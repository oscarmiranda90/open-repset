/// Aggregated training metrics.
///
/// Everything here is derived from completed sets — nothing is stored twice.
/// Volume, duration and records are computed on read so a corrected set can
/// never leave a stale number behind.
library;

/// One entry in a time series, bucketed by day or week.
class TrainingPoint {
  const TrainingPoint({
    required this.date,
    required this.volumeKg,
    required this.setCount,
    required this.sessionCount,
  });

  /// Start of the bucket, local time.
  final DateTime date;
  final double volumeKg;
  final int setCount;
  final int sessionCount;
}

/// Progression of a single exercise over time.
class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.bestLoadKg,
    required this.estimatedOneRepMaxKg,
    required this.volumeKg,
    required this.totalReps,
  });

  final DateTime date;

  /// Heaviest completed set that day.
  final double bestLoadKg;

  /// Epley estimate from the best set. Comparable across rep ranges, which
  /// raw top-set weight is not: 100kg x 3 is more than 95kg x 5.
  final double estimatedOneRepMaxKg;

  final double volumeKg;
  final int totalReps;
}

/// How an exercise is trending against its own recent history.
enum ProgressTrend { improving, plateaued, declining, insufficientData }

class ExerciseInsight {
  const ExerciseInsight({
    required this.exerciseId,
    required this.exerciseName,
    required this.sessionCount,
    required this.lastPerformedAt,
    required this.bestLoadKg,
    required this.bestEstimatedOneRepMaxKg,
    required this.totalVolumeKg,
    required this.trend,
    required this.trendChange,
  });

  final String exerciseId;
  final String exerciseName;
  final int sessionCount;
  final DateTime? lastPerformedAt;
  final double bestLoadKg;
  final double bestEstimatedOneRepMaxKg;
  final double totalVolumeKg;
  final ProgressTrend trend;

  /// Fractional change of recent estimated 1RM against the prior window
  /// (0.08 == 8% stronger). Zero when there is not enough history.
  final double trendChange;

  /// Days since this exercise was last trained, or null if never.
  int? get daysSinceLastPerformed => lastPerformedAt == null
      ? null
      : DateTime.now().difference(lastPerformedAt!).inDays;
}

/// Headline numbers for the Progress screen.
class TrainingOverview {
  const TrainingOverview({
    required this.totalSessions,
    required this.sessionsThisWeek,
    required this.sessionsLastWeek,
    required this.totalVolumeKg,
    required this.volumeThisWeekKg,
    required this.volumeLastWeekKg,
    required this.totalSets,
    required this.totalReps,
    required this.averageSessionDuration,
    required this.currentStreakWeeks,
    required this.firstSessionAt,
    required this.lastSessionAt,
  });

  final int totalSessions;
  final int sessionsThisWeek;
  final int sessionsLastWeek;
  final double totalVolumeKg;
  final double volumeThisWeekKg;
  final double volumeLastWeekKg;
  final int totalSets;
  final int totalReps;
  final Duration averageSessionDuration;

  /// Consecutive weeks, counting back from this one, with at least one session.
  final int currentStreakWeeks;

  final DateTime? firstSessionAt;
  final DateTime? lastSessionAt;

  bool get hasHistory => totalSessions > 0;

  /// Week-over-week volume change as a fraction, or null without a baseline.
  double? get volumeWeekChange => volumeLastWeekKg > 0
      ? (volumeThisWeekKg - volumeLastWeekKg) / volumeLastWeekKg
      : null;
}

/// Training distribution across muscle groups, for spotting imbalance.
class MuscleGroupShare {
  const MuscleGroupShare({
    required this.target,
    required this.volumeKg,
    required this.setCount,
    required this.share,
  });

  final String target;
  final double volumeKg;
  final int setCount;

  /// Fraction of total logged volume, 0..1.
  final double share;
}

/// Epley: load * (1 + reps/30). Widely used, and accurate enough under ~10
/// reps, which is where strength work lives.
double estimateOneRepMax(double loadKg, int repetitions) {
  if (loadKg <= 0 || repetitions <= 0) return 0;
  if (repetitions == 1) return loadKg;
  return loadKg * (1 + repetitions / 30);
}

/// Classifies progression by comparing the most recent third of sessions
/// against the third before it.
///
/// Lives in the domain so every repository reaches the same verdict from the
/// same data — a threshold that drifted between implementations would make the
/// same history look different depending on where it was stored.
(ProgressTrend, double) classifyTrend(List<ExerciseProgressPoint> points) {
  // Under six sessions the windows are too small to mean anything, and a
  // confident arrow drawn from three points is worse than no arrow.
  if (points.length < 6) return (ProgressTrend.insufficientData, 0);

  final window = points.length ~/ 3;
  final recent = points.sublist(points.length - window);
  final earlier = points.sublist(
    points.length - window * 2,
    points.length - window,
  );

  double average(List<ExerciseProgressPoint> values) =>
      values.fold<double>(0, (sum, point) => sum + point.estimatedOneRepMaxKg) /
      values.length;

  final earlierAverage = average(earlier);
  if (earlierAverage <= 0) return (ProgressTrend.insufficientData, 0);
  final change = (average(recent) - earlierAverage) / earlierAverage;

  // A 3% band around flat: session-to-session noise is not a trend.
  if (change > .03) return (ProgressTrend.improving, change);
  if (change < -.03) return (ProgressTrend.declining, change);
  return (ProgressTrend.plateaued, change);
}

/// Reads aggregated training data.
///
/// Kept separate from `WorkoutRepository`: that one persists sessions, this one
/// only ever reads and never returns whole sessions, so the queries can stay in
/// SQL instead of loading a training history into memory to sum it.
abstract interface class TrainingAnalyticsRepository {
  Future<TrainingOverview> getOverview();

  /// Volume series bucketed by week, most recent last.
  Future<List<TrainingPoint>> getWeeklyVolume({int weeks = 12});

  /// Per-session progression for one exercise, oldest first.
  Future<List<ExerciseProgressPoint>> getExerciseProgress(
    String exerciseId, {
    int limit = 30,
  });

  /// Exercises ranked by how much they have been trained.
  Future<List<ExerciseInsight>> getExerciseInsights({int limit = 20});

  /// Volume split across muscle targets, largest first.
  Future<List<MuscleGroupShare>> getMuscleGroupShares({int limit = 8});

  /// Median rest actually taken between consecutive sets, which is not the
  /// configured `restSeconds` — it is what the athlete really did.
  Future<Duration?> getMedianRestBetweenSets();
}
