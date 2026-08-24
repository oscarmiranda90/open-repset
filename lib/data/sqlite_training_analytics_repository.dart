import 'package:sqflite/sqflite.dart';

import '../domain/training_analytics.dart';

/// Reads training metrics with SQL aggregation.
///
/// Nothing here loads whole sessions: summing a few hundred sessions in Dart
/// would mean pulling an entire training history into memory to produce one
/// number. SQLite aggregates in place, so cost stays flat as history grows.
class SqliteTrainingAnalyticsRepository implements TrainingAnalyticsRepository {
  const SqliteTrainingAnalyticsRepository(this._database);

  final Future<Database> _database;

  /// Only completed sets of completed sessions count. An abandoned session or
  /// an unticked set is not training that happened.
  static const _completedJoin = '''
    FROM workout_sets s
    INNER JOIN workout_sessions ws ON ws.id = s.session_id
    WHERE ws.completed_at IS NOT NULL AND s.is_completed = 1
  ''';

  @override
  Future<TrainingOverview> getOverview() async {
    final db = await _database;

    final totals = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT s.session_id) AS session_count,
        COUNT(s.id) AS set_count,
        COALESCE(SUM(s.repetitions), 0) AS rep_count,
        COALESCE(SUM(s.load_kg * s.repetitions), 0) AS volume_kg
      $_completedJoin
    ''');
    final totalRow = totals.single;

    final sessionRows = await db.rawQuery('''
      SELECT started_at, completed_at
      FROM workout_sessions
      WHERE completed_at IS NOT NULL
      ORDER BY completed_at ASC
    ''');

    final thisWeekStart = _startOfWeek(DateTime.now());
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    var sessionsThisWeek = 0;
    var sessionsLastWeek = 0;
    var totalDuration = Duration.zero;
    DateTime? firstAt;
    DateTime? lastAt;
    final activeWeeks = <DateTime>{};

    for (final row in sessionRows) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        (row['started_at']! as num).toInt(),
      );
      final completedAt = DateTime.fromMillisecondsSinceEpoch(
        (row['completed_at']! as num).toInt(),
      );
      firstAt ??= completedAt;
      lastAt = completedAt;
      totalDuration += completedAt.difference(startedAt);
      activeWeeks.add(_startOfWeek(completedAt));
      if (!completedAt.isBefore(thisWeekStart)) {
        sessionsThisWeek++;
      } else if (!completedAt.isBefore(lastWeekStart)) {
        sessionsLastWeek++;
      }
    }

    final volumeThisWeek = await _volumeSince(db, thisWeekStart);
    final volumeLastWeek = await _volumeBetween(
      db,
      lastWeekStart,
      thisWeekStart,
    );

    final sessionCount = (totalRow['session_count'] as num?)?.toInt() ?? 0;
    return TrainingOverview(
      totalSessions: sessionCount,
      sessionsThisWeek: sessionsThisWeek,
      sessionsLastWeek: sessionsLastWeek,
      totalVolumeKg: (totalRow['volume_kg'] as num?)?.toDouble() ?? 0,
      volumeThisWeekKg: volumeThisWeek,
      volumeLastWeekKg: volumeLastWeek,
      totalSets: (totalRow['set_count'] as num?)?.toInt() ?? 0,
      totalReps: (totalRow['rep_count'] as num?)?.toInt() ?? 0,
      averageSessionDuration: sessionRows.isEmpty
          ? Duration.zero
          : Duration(
              microseconds: totalDuration.inMicroseconds ~/ sessionRows.length,
            ),
      currentStreakWeeks: _streakWeeks(activeWeeks, thisWeekStart),
      firstSessionAt: firstAt,
      lastSessionAt: lastAt,
    );
  }

  Future<double> _volumeSince(Database db, DateTime from) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(s.load_kg * s.repetitions), 0) AS volume_kg
      $_completedJoin AND ws.completed_at >= ?
    ''',
      [from.millisecondsSinceEpoch],
    );
    return (rows.single['volume_kg'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _volumeBetween(Database db, DateTime from, DateTime to) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(s.load_kg * s.repetitions), 0) AS volume_kg
      $_completedJoin AND ws.completed_at >= ? AND ws.completed_at < ?
    ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (rows.single['volume_kg'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<List<TrainingPoint>> getWeeklyVolume({int weeks = 12}) async {
    final db = await _database;
    final since = _startOfWeek(
      DateTime.now(),
    ).subtract(Duration(days: 7 * (weeks - 1)));

    final rows = await db.rawQuery(
      '''
      SELECT
        ws.completed_at AS completed_at,
        s.session_id AS session_id,
        s.load_kg * s.repetitions AS volume_kg
      $_completedJoin AND ws.completed_at >= ?
    ''',
      [since.millisecondsSinceEpoch],
    );

    // Bucketing happens in Dart because week boundaries are local-time and
    // DST-aware; SQLite's date functions would treat them as UTC.
    final buckets = <DateTime, _WeekBucket>{};
    for (final row in rows) {
      final completedAt = DateTime.fromMillisecondsSinceEpoch(
        (row['completed_at']! as num).toInt(),
      );
      final bucket = buckets.putIfAbsent(
        _startOfWeek(completedAt),
        _WeekBucket.new,
      );
      bucket.volumeKg += (row['volume_kg'] as num?)?.toDouble() ?? 0;
      bucket.setCount++;
      bucket.sessionIds.add(row['session_id']! as String);
    }

    // Empty weeks are real information: a gap in training should show as a gap.
    return List.generate(weeks, (index) {
      final weekStart = since.add(Duration(days: 7 * index));
      final bucket = buckets[weekStart];
      return TrainingPoint(
        date: weekStart,
        volumeKg: bucket?.volumeKg ?? 0,
        setCount: bucket?.setCount ?? 0,
        sessionCount: bucket?.sessionIds.length ?? 0,
      );
    }, growable: false);
  }

  @override
  Future<List<ExerciseProgressPoint>> getExerciseProgress(
    String exerciseId, {
    int limit = 30,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT
        s.session_id AS session_id,
        ws.completed_at AS completed_at,
        s.load_kg AS load_kg,
        s.repetitions AS repetitions
      $_completedJoin AND s.exercise_id = ?
      ORDER BY ws.completed_at ASC
    ''',
      [exerciseId],
    );

    // Grouped per session rather than per set: one point on the chart is one
    // training day, and the best set of that day is what represents it.
    final bySession = <String, _ProgressBucket>{};
    for (final row in rows) {
      final sessionId = row['session_id']! as String;
      final bucket = bySession.putIfAbsent(
        sessionId,
        () => _ProgressBucket(
          DateTime.fromMillisecondsSinceEpoch(
            (row['completed_at']! as num).toInt(),
          ),
        ),
      );
      final load = (row['load_kg'] as num?)?.toDouble() ?? 0;
      final reps = (row['repetitions'] as num?)?.toInt() ?? 0;
      bucket.volumeKg += load * reps;
      bucket.totalReps += reps;
      if (load > bucket.bestLoadKg) bucket.bestLoadKg = load;
      final oneRepMax = estimateOneRepMax(load, reps);
      if (oneRepMax > bucket.bestOneRepMaxKg) {
        bucket.bestOneRepMaxKg = oneRepMax;
      }
    }

    final points =
        bySession.values
            .map(
              (bucket) => ExerciseProgressPoint(
                date: bucket.date,
                bestLoadKg: bucket.bestLoadKg,
                estimatedOneRepMaxKg: bucket.bestOneRepMaxKg,
                volumeKg: bucket.volumeKg,
                totalReps: bucket.totalReps,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    if (points.length <= limit) return points;
    return points.sublist(points.length - limit);
  }

  @override
  Future<List<ExerciseInsight>> getExerciseInsights({int limit = 20}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT
        s.exercise_id AS exercise_id,
        MAX(we.exercise_name) AS exercise_name,
        COUNT(DISTINCT s.session_id) AS session_count,
        MAX(ws.completed_at) AS last_completed_at,
        MAX(s.load_kg) AS best_load_kg,
        COALESCE(SUM(s.load_kg * s.repetitions), 0) AS total_volume_kg
      FROM workout_sets s
      INNER JOIN workout_sessions ws ON ws.id = s.session_id
      INNER JOIN workout_exercises we ON we.id = s.workout_exercise_id
      WHERE ws.completed_at IS NOT NULL AND s.is_completed = 1
      GROUP BY s.exercise_id
      ORDER BY total_volume_kg DESC
      LIMIT ?
    ''',
      [limit],
    );

    final insights = <ExerciseInsight>[];
    for (final row in rows) {
      final exerciseId = row['exercise_id']! as String;
      final progress = await getExerciseProgress(exerciseId);
      final trend = classifyTrend(progress);
      insights.add(
        ExerciseInsight(
          exerciseId: exerciseId,
          exerciseName: (row['exercise_name'] as String?) ?? exerciseId,
          sessionCount: (row['session_count'] as num?)?.toInt() ?? 0,
          lastPerformedAt: row['last_completed_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (row['last_completed_at']! as num).toInt(),
                ),
          bestLoadKg: (row['best_load_kg'] as num?)?.toDouble() ?? 0,
          bestEstimatedOneRepMaxKg: progress.fold<double>(
            0,
            (best, point) => point.estimatedOneRepMaxKg > best
                ? point.estimatedOneRepMaxKg
                : best,
          ),
          totalVolumeKg: (row['total_volume_kg'] as num?)?.toDouble() ?? 0,
          trend: trend.$1,
          trendChange: trend.$2,
        ),
      );
    }
    return insights;
  }

  @override
  Future<List<MuscleGroupShare>> getMuscleGroupShares({int limit = 8}) async {
    final db = await _database;
    // The exercises table is keyed by (id, language_code), so it is collapsed
    // to one row per id first — joining it directly would multiply every set
    // by the number of translations.
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(t.target, 'Unclassified') AS target,
        COUNT(s.id) AS set_count,
        COALESCE(SUM(s.load_kg * s.repetitions), 0) AS volume_kg
      FROM workout_sets s
      INNER JOIN workout_sessions ws ON ws.id = s.session_id
      LEFT JOIN (
        SELECT id, MIN(target) AS target FROM exercises GROUP BY id
      ) t ON t.id = s.exercise_id
      WHERE ws.completed_at IS NOT NULL AND s.is_completed = 1
      GROUP BY target
      ORDER BY volume_kg DESC
      LIMIT ?
    ''',
      [limit],
    );

    final total = rows.fold<double>(
      0,
      (sum, row) => sum + ((row['volume_kg'] as num?)?.toDouble() ?? 0),
    );

    return rows
        .map((row) {
          final volume = (row['volume_kg'] as num?)?.toDouble() ?? 0;
          return MuscleGroupShare(
            target: row['target']! as String,
            volumeKg: volume,
            setCount: (row['set_count'] as num?)?.toInt() ?? 0,
            share: total > 0 ? volume / total : 0,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Duration?> getMedianRestBetweenSets() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT s.session_id AS session_id, s.completed_at AS completed_at
      $_completedJoin AND s.completed_at IS NOT NULL
      ORDER BY s.session_id ASC, s.completed_at ASC
    ''');

    final gaps = <int>[];
    String? currentSession;
    int? previousAt;
    for (final row in rows) {
      final sessionId = row['session_id']! as String;
      final completedAt = (row['completed_at']! as num).toInt();
      if (sessionId != currentSession) {
        currentSession = sessionId;
        previousAt = completedAt;
        continue;
      }
      final gap = completedAt - previousAt!;
      previousAt = completedAt;
      // Gaps beyond 15 minutes are breaks, phone calls, or a forgotten tick —
      // not rest between sets. Including them would skew the median upward.
      if (gap > 0 && gap <= const Duration(minutes: 15).inMilliseconds) {
        gaps.add(gap);
      }
    }

    if (gaps.isEmpty) return null;
    gaps.sort();
    // Median, not mean: a single long gap should not move the number.
    final middle = gaps.length ~/ 2;
    final medianMs = gaps.length.isOdd
        ? gaps[middle]
        : (gaps[middle - 1] + gaps[middle]) ~/ 2;
    return Duration(milliseconds: medianMs);
  }
}

/// Monday 00:00 local time of the week containing [moment].
DateTime _startOfWeek(DateTime moment) {
  final date = DateTime(moment.year, moment.month, moment.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

int _streakWeeks(Set<DateTime> activeWeeks, DateTime thisWeekStart) {
  if (activeWeeks.isEmpty) return 0;
  // A week still in progress should not break the streak, so counting starts
  // at last week when this one has no session yet.
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

class _WeekBucket {
  double volumeKg = 0;
  int setCount = 0;
  final Set<String> sessionIds = {};
}

class _ProgressBucket {
  _ProgressBucket(this.date);

  final DateTime date;
  double volumeKg = 0;
  double bestLoadKg = 0;
  double bestOneRepMaxKg = 0;
  int totalReps = 0;
}
