import '../domain/training_analytics.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';

/// Analytics over an in-memory workout repository.
///
/// Used for the no-database fallback and for tests. Computing in Dart is fine
/// here precisely because the data set is bounded; the SQLite implementation
/// exists for real histories.
class MemoryTrainingAnalyticsRepository implements TrainingAnalyticsRepository {
  const MemoryTrainingAnalyticsRepository(this._workouts);

  final WorkoutRepository _workouts;

  Future<List<WorkoutSession>> get _completed async {
    final sessions = await _workouts.getCompletedSessions();
    return sessions
        .where((session) => session.completedAt != null)
        .toList(growable: false)
      ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
  }

  Iterable<WorkoutSet> _completedSets(WorkoutSession session) =>
      session.sets.where((set) => set.isCompleted);

  @override
  Future<TrainingOverview> getOverview() async {
    final sessions = await _completed;
    if (sessions.isEmpty) {
      return const TrainingOverview(
        totalSessions: 0,
        sessionsThisWeek: 0,
        sessionsLastWeek: 0,
        totalVolumeKg: 0,
        volumeThisWeekKg: 0,
        volumeLastWeekKg: 0,
        totalSets: 0,
        totalReps: 0,
        averageSessionDuration: Duration.zero,
        currentStreakWeeks: 0,
        firstSessionAt: null,
        lastSessionAt: null,
      );
    }

    final thisWeekStart = _startOfWeek(DateTime.now());
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    var sessionsThisWeek = 0;
    var sessionsLastWeek = 0;
    var volumeThisWeek = 0.0;
    var volumeLastWeek = 0.0;
    var totalVolume = 0.0;
    var totalSets = 0;
    var totalReps = 0;
    var totalDuration = Duration.zero;
    final activeWeeks = <DateTime>{};

    for (final session in sessions) {
      final completedAt = session.completedAt!;
      final volume = session.volumeKg;
      totalVolume += volume;
      totalDuration += completedAt.difference(session.startedAt);
      activeWeeks.add(_startOfWeek(completedAt));
      for (final set in _completedSets(session)) {
        totalSets++;
        totalReps += set.repetitions;
      }
      if (!completedAt.isBefore(thisWeekStart)) {
        sessionsThisWeek++;
        volumeThisWeek += volume;
      } else if (!completedAt.isBefore(lastWeekStart)) {
        sessionsLastWeek++;
        volumeLastWeek += volume;
      }
    }

    return TrainingOverview(
      totalSessions: sessions.length,
      sessionsThisWeek: sessionsThisWeek,
      sessionsLastWeek: sessionsLastWeek,
      totalVolumeKg: totalVolume,
      volumeThisWeekKg: volumeThisWeek,
      volumeLastWeekKg: volumeLastWeek,
      totalSets: totalSets,
      totalReps: totalReps,
      averageSessionDuration: Duration(
        microseconds: totalDuration.inMicroseconds ~/ sessions.length,
      ),
      currentStreakWeeks: _streakWeeks(activeWeeks, thisWeekStart),
      firstSessionAt: sessions.first.completedAt,
      lastSessionAt: sessions.last.completedAt,
    );
  }

  @override
  Future<List<TrainingPoint>> getWeeklyVolume({int weeks = 12}) async {
    final sessions = await _completed;
    final since = _startOfWeek(
      DateTime.now(),
    ).subtract(Duration(days: 7 * (weeks - 1)));

    final volume = <DateTime, double>{};
    final sets = <DateTime, int>{};
    final counts = <DateTime, int>{};
    for (final session in sessions) {
      final completedAt = session.completedAt!;
      if (completedAt.isBefore(since)) continue;
      final bucket = _startOfWeek(completedAt);
      volume[bucket] = (volume[bucket] ?? 0) + session.volumeKg;
      sets[bucket] = (sets[bucket] ?? 0) + session.completedSetCount;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }

    return List.generate(weeks, (index) {
      final weekStart = since.add(Duration(days: 7 * index));
      return TrainingPoint(
        date: weekStart,
        volumeKg: volume[weekStart] ?? 0,
        setCount: sets[weekStart] ?? 0,
        sessionCount: counts[weekStart] ?? 0,
      );
    }, growable: false);
  }

  @override
  Future<List<ExerciseProgressPoint>> getExerciseProgress(
    String exerciseId, {
    int limit = 30,
  }) async {
    final sessions = await _completed;
    final points = <ExerciseProgressPoint>[];

    for (final session in sessions) {
      var bestLoad = 0.0;
      var bestOneRepMax = 0.0;
      var volume = 0.0;
      var reps = 0;
      for (final exercise in session.exercises) {
        if (exercise.exerciseId != exerciseId) continue;
        for (final set in exercise.sets.where((set) => set.isCompleted)) {
          volume += set.volumeKg;
          reps += set.repetitions;
          if (set.loadKg > bestLoad) bestLoad = set.loadKg;
          final oneRepMax = estimateOneRepMax(set.loadKg, set.repetitions);
          if (oneRepMax > bestOneRepMax) bestOneRepMax = oneRepMax;
        }
      }
      if (reps == 0 && volume == 0) continue;
      points.add(
        ExerciseProgressPoint(
          date: session.completedAt!,
          bestLoadKg: bestLoad,
          estimatedOneRepMaxKg: bestOneRepMax,
          volumeKg: volume,
          totalReps: reps,
        ),
      );
    }

    if (points.length <= limit) return points;
    return points.sublist(points.length - limit);
  }

  @override
  Future<List<ExerciseInsight>> getExerciseInsights({int limit = 20}) async {
    final sessions = await _completed;
    final names = <String, String>{};
    final volumes = <String, double>{};
    final bestLoads = <String, double>{};
    final sessionCounts = <String, int>{};
    final lastSeen = <String, DateTime>{};

    for (final session in sessions) {
      final seenThisSession = <String>{};
      for (final exercise in session.exercises) {
        for (final set in exercise.sets.where((set) => set.isCompleted)) {
          final id = exercise.exerciseId;
          names[id] = exercise.name;
          volumes[id] = (volumes[id] ?? 0) + set.volumeKg;
          if (set.loadKg > (bestLoads[id] ?? 0)) bestLoads[id] = set.loadKg;
          lastSeen[id] = session.completedAt!;
          if (seenThisSession.add(id)) {
            sessionCounts[id] = (sessionCounts[id] ?? 0) + 1;
          }
        }
      }
    }

    final ranked = volumes.keys.toList(growable: false)
      ..sort((a, b) => (volumes[b] ?? 0).compareTo(volumes[a] ?? 0));

    final insights = <ExerciseInsight>[];
    for (final id in ranked.take(limit)) {
      final progress = await getExerciseProgress(id);
      final trend = classifyTrend(progress);
      insights.add(
        ExerciseInsight(
          exerciseId: id,
          exerciseName: names[id] ?? id,
          sessionCount: sessionCounts[id] ?? 0,
          lastPerformedAt: lastSeen[id],
          bestLoadKg: bestLoads[id] ?? 0,
          bestEstimatedOneRepMaxKg: progress.fold<double>(
            0,
            (best, point) => point.estimatedOneRepMaxKg > best
                ? point.estimatedOneRepMaxKg
                : best,
          ),
          totalVolumeKg: volumes[id] ?? 0,
          trend: trend.$1,
          trendChange: trend.$2,
        ),
      );
    }
    return insights;
  }

  @override
  Future<List<MuscleGroupShare>> getMuscleGroupShares({int limit = 8}) async {
    // Muscle targets live in the exercise catalogue, which this repository has
    // no access to. Returning nothing is honest; inventing groupings is not.
    return const [];
  }

  @override
  Future<Duration?> getMedianRestBetweenSets() async {
    final sessions = await _completed;
    final gaps = <int>[];

    for (final session in sessions) {
      final stamps =
          _completedSets(session)
              .map((set) => set.completedAt)
              .whereType<DateTime>()
              .toList(growable: false)
            ..sort();
      for (var index = 1; index < stamps.length; index++) {
        final gap = stamps[index].difference(stamps[index - 1]);
        if (gap > Duration.zero && gap <= const Duration(minutes: 15)) {
          gaps.add(gap.inMilliseconds);
        }
      }
    }

    if (gaps.isEmpty) return null;
    gaps.sort();
    final middle = gaps.length ~/ 2;
    final medianMs = gaps.length.isOdd
        ? gaps[middle]
        : (gaps[middle - 1] + gaps[middle]) ~/ 2;
    return Duration(milliseconds: medianMs);
  }
}

DateTime _startOfWeek(DateTime moment) {
  final date = DateTime(moment.year, moment.month, moment.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

int _streakWeeks(Set<DateTime> activeWeeks, DateTime thisWeekStart) {
  if (activeWeeks.isEmpty) return 0;
  var cursor = activeWeeks.contains(thisWeekStart)
      ? thisWeekStart
      : thisWeekStart.subtract(const Duration(days: 7));
  var streak = 0;
  while (activeWeeks.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}
