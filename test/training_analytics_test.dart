import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/sqlite_training_analytics_repository.dart';
import 'package:repset/data/sqlite_workout_repository.dart';
import 'package:repset/domain/training_analytics.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WorkoutSet _set({
  required String id,
  required String exerciseId,
  required int position,
  required int repetitions,
  required double loadKg,
  DateTime? completedAt,
  bool isCompleted = true,
}) => WorkoutSet(
  id: id,
  exerciseId: exerciseId,
  position: position,
  repetitions: repetitions,
  loadKg: loadKg,
  isCompleted: isCompleted,
  completedAt: completedAt,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // sqflite_ffi shares one in-memory database per process, so each test needs
  // its own file to keep history isolated.
  var counter = 0;
  late Directory root;
  late Future<Database> database;
  late SqliteWorkoutRepository workouts;
  late SqliteTrainingAnalyticsRepository analytics;

  setUp(() {
    root = Directory.systemTemp.createTempSync('repset-analytics');
    database = AppDatabase.open(
      path: path.join(root.path, 'analytics-${counter++}.db'),
    );
    workouts = SqliteWorkoutRepository(database);
    analytics = SqliteTrainingAnalyticsRepository(database);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> saveSession({
    required String id,
    required DateTime startedAt,
    required DateTime completedAt,
    required List<WorkoutExercise> exercises,
  }) => workouts.save(
    WorkoutSession(
      id: id,
      title: 'Session $id',
      startedAt: startedAt,
      completedAt: completedAt,
      exercises: exercises,
    ),
  );

  test('reports zeroed totals with no history', () async {
    final overview = await analytics.getOverview();

    expect(overview.hasHistory, isFalse);
    expect(overview.totalSessions, 0);
    expect(overview.totalVolumeKg, 0);
    expect(overview.currentStreakWeeks, 0);
    expect(overview.volumeWeekChange, isNull);
    expect(await analytics.getExerciseInsights(), isEmpty);
    expect(await analytics.getMedianRestBetweenSets(), isNull);
  });

  test('counts only completed sets of completed sessions', () async {
    final now = DateTime.now();
    await saveSession(
      id: 'done',
      startedAt: now.subtract(const Duration(hours: 2)),
      completedAt: now.subtract(const Duration(hours: 1)),
      exercises: [
        WorkoutExercise(
          id: 'e1',
          exerciseId: 'bench',
          name: 'Bench press',
          position: 0,
          sets: [
            _set(
              id: 's1',
              exerciseId: 'bench',
              position: 0,
              repetitions: 10,
              loadKg: 60,
            ),
            _set(
              id: 's2',
              exerciseId: 'bench',
              position: 1,
              repetitions: 10,
              loadKg: 999,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );
    // An abandoned session is not training that happened.
    await workouts.save(
      WorkoutSession(
        id: 'abandoned',
        title: 'Abandoned',
        startedAt: now.subtract(const Duration(minutes: 30)),
        exercises: [
          WorkoutExercise(
            id: 'e2',
            exerciseId: 'bench',
            name: 'Bench press',
            position: 0,
            sets: [
              _set(
                id: 's3',
                exerciseId: 'bench',
                position: 0,
                repetitions: 10,
                loadKg: 500,
              ),
            ],
          ),
        ],
      ),
    );

    final overview = await analytics.getOverview();
    expect(overview.totalSessions, 1);
    expect(overview.totalSets, 1);
    expect(overview.totalReps, 10);
    expect(overview.totalVolumeKg, 600);
    expect(overview.averageSessionDuration, const Duration(hours: 1));
  });

  test('buckets volume by week and keeps empty weeks visible', () async {
    final now = DateTime.now();
    await saveSession(
      id: 'recent',
      startedAt: now.subtract(const Duration(hours: 1)),
      completedAt: now,
      exercises: [
        WorkoutExercise(
          id: 'e1',
          exerciseId: 'squat',
          name: 'Back squat',
          position: 0,
          sets: [
            _set(
              id: 's1',
              exerciseId: 'squat',
              position: 0,
              repetitions: 5,
              loadKg: 100,
            ),
          ],
        ),
      ],
    );

    final series = await analytics.getWeeklyVolume(weeks: 4);
    expect(series, hasLength(4));
    // A gap in training must read as a gap, not vanish from the series.
    expect(series.take(3).every((point) => point.volumeKg == 0), isTrue);
    expect(series.last.volumeKg, 500);
    expect(series.last.sessionCount, 1);
  });

  test(
    'tracks per-session progression using the best set of each day',
    () async {
      final base = DateTime.now().subtract(const Duration(days: 20));
      for (var index = 0; index < 3; index++) {
        final day = base.add(Duration(days: index * 3));
        await saveSession(
          id: 'session-$index',
          startedAt: day,
          completedAt: day.add(const Duration(minutes: 50)),
          exercises: [
            WorkoutExercise(
              id: 'entry-$index',
              exerciseId: 'deadlift',
              name: 'Deadlift',
              position: 0,
              sets: [
                _set(
                  id: 'light-$index',
                  exerciseId: 'deadlift',
                  position: 0,
                  repetitions: 8,
                  loadKg: 80,
                ),
                _set(
                  id: 'top-$index',
                  exerciseId: 'deadlift',
                  position: 1,
                  repetitions: 3,
                  loadKg: 100 + index * 5,
                ),
              ],
            ),
          ],
        );
      }

      final progress = await analytics.getExerciseProgress('deadlift');
      expect(progress, hasLength(3));
      // One point per training day, represented by that day's heaviest set.
      expect(progress.map((point) => point.bestLoadKg).toList(), [
        100,
        105,
        110,
      ]);
      // Epley on 110kg x 3 -> 110 * 1.1.
      expect(progress.last.estimatedOneRepMaxKg, closeTo(121, .001));
      expect(progress.first.volumeKg, 80 * 8 + 100 * 3);
    },
  );

  test('withholds a trend verdict until there is enough history', () async {
    final base = DateTime.now().subtract(const Duration(days: 30));
    for (var index = 0; index < 3; index++) {
      final day = base.add(Duration(days: index * 4));
      await saveSession(
        id: 'few-$index',
        startedAt: day,
        completedAt: day.add(const Duration(minutes: 40)),
        exercises: [
          WorkoutExercise(
            id: 'entry-$index',
            exerciseId: 'press',
            name: 'Overhead press',
            position: 0,
            sets: [
              _set(
                id: 'set-$index',
                exerciseId: 'press',
                position: 0,
                repetitions: 5,
                loadKg: 50,
              ),
            ],
          ),
        ],
      );
    }

    final insights = await analytics.getExerciseInsights();
    expect(insights.single.trend, ProgressTrend.insufficientData);
    expect(insights.single.sessionCount, 3);
  });

  test('separates improving from plateaued exercises', () async {
    final base = DateTime.now().subtract(const Duration(days: 60));
    for (var index = 0; index < 9; index++) {
      final day = base.add(Duration(days: index * 5));
      await saveSession(
        id: 'growth-$index',
        startedAt: day,
        completedAt: day.add(const Duration(minutes: 55)),
        exercises: [
          WorkoutExercise(
            id: 'rising-$index',
            exerciseId: 'squat',
            name: 'Back squat',
            position: 0,
            sets: [
              _set(
                id: 'rising-set-$index',
                exerciseId: 'squat',
                position: 0,
                repetitions: 5,
                loadKg: 100 + index * 5,
              ),
            ],
          ),
          WorkoutExercise(
            id: 'flat-$index',
            exerciseId: 'curl',
            name: 'Biceps curl',
            position: 1,
            sets: [
              _set(
                id: 'flat-set-$index',
                exerciseId: 'curl',
                position: 0,
                repetitions: 10,
                loadKg: 20,
              ),
            ],
          ),
        ],
      );
    }

    final insights = await analytics.getExerciseInsights();
    final squat = insights.firstWhere((item) => item.exerciseId == 'squat');
    final curl = insights.firstWhere((item) => item.exerciseId == 'curl');

    expect(squat.trend, ProgressTrend.improving);
    expect(squat.trendChange, greaterThan(.03));
    // Identical loads every session is the definition of a plateau.
    expect(curl.trend, ProgressTrend.plateaued);
    expect(curl.trendChange, closeTo(0, 1e-9));
  });

  test('splits volume across muscle targets without double counting', () async {
    final db = await database;
    // Two translations of one exercise: a naive join would double its volume.
    for (final language in ['en', 'es']) {
      await db.insert('exercises', {
        'id': 'bench',
        'language_code': language,
        'name': language == 'en' ? 'Bench press' : 'Press de banca',
        'body_part': 'chest',
        'target': 'pectorals',
        'equipment': 'barbell',
        'secondary_muscles': '',
        'instructions': '',
        'is_custom': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    final now = DateTime.now();
    await saveSession(
      id: 'split',
      startedAt: now.subtract(const Duration(hours: 1)),
      completedAt: now,
      exercises: [
        WorkoutExercise(
          id: 'e1',
          exerciseId: 'bench',
          name: 'Bench press',
          position: 0,
          sets: [
            _set(
              id: 's1',
              exerciseId: 'bench',
              position: 0,
              repetitions: 10,
              loadKg: 60,
            ),
          ],
        ),
        WorkoutExercise(
          id: 'e2',
          exerciseId: 'unknown-lift',
          name: 'Unknown lift',
          position: 1,
          sets: [
            _set(
              id: 's2',
              exerciseId: 'unknown-lift',
              position: 0,
              repetitions: 10,
              loadKg: 20,
            ),
          ],
        ),
      ],
    );

    final shares = await analytics.getMuscleGroupShares();
    final pectorals = shares.firstWhere((share) => share.target == 'pectorals');
    expect(pectorals.volumeKg, 600);
    expect(pectorals.setCount, 1);
    expect(pectorals.share, closeTo(600 / 800, 1e-9));
    // An exercise missing from the catalogue still has to be represented.
    expect(shares.any((share) => share.target == 'Unclassified'), isTrue);
  });

  test('measures real rest between sets and ignores long breaks', () async {
    final start = DateTime.now().subtract(const Duration(hours: 2));
    await saveSession(
      id: 'rest',
      startedAt: start,
      completedAt: start.add(const Duration(hours: 1)),
      exercises: [
        WorkoutExercise(
          id: 'entry',
          exerciseId: 'row',
          name: 'Barbell row',
          position: 0,
          restSeconds: 120,
          sets: [
            _set(
              id: 'a',
              exerciseId: 'row',
              position: 0,
              repetitions: 8,
              loadKg: 60,
              completedAt: start,
            ),
            _set(
              id: 'b',
              exerciseId: 'row',
              position: 1,
              repetitions: 8,
              loadKg: 60,
              completedAt: start.add(const Duration(seconds: 90)),
            ),
            _set(
              id: 'c',
              exerciseId: 'row',
              position: 2,
              repetitions: 8,
              loadKg: 60,
              completedAt: start.add(const Duration(seconds: 240)),
            ),
            // A 40-minute gap is a phone call, not rest between sets.
            _set(
              id: 'd',
              exerciseId: 'row',
              position: 3,
              repetitions: 8,
              loadKg: 60,
              completedAt: start.add(const Duration(minutes: 44)),
            ),
          ],
        ),
      ],
    );

    final median = await analytics.getMedianRestBetweenSets();
    // Gaps of 90s and 150s survive; their median is 120s.
    expect(median, const Duration(seconds: 120));
  });

  test('counts a training streak back from the current week', () async {
    final thisWeek = DateTime.now();
    for (var weeksAgo = 0; weeksAgo < 3; weeksAgo++) {
      final day = thisWeek.subtract(Duration(days: 7 * weeksAgo));
      await saveSession(
        id: 'streak-$weeksAgo',
        startedAt: day.subtract(const Duration(hours: 1)),
        completedAt: day,
        exercises: [
          WorkoutExercise(
            id: 'entry-$weeksAgo',
            exerciseId: 'squat',
            name: 'Back squat',
            position: 0,
            sets: [
              _set(
                id: 'set-$weeksAgo',
                exerciseId: 'squat',
                position: 0,
                repetitions: 5,
                loadKg: 100,
              ),
            ],
          ),
        ],
      );
    }

    final overview = await analytics.getOverview();
    expect(overview.currentStreakWeeks, greaterThanOrEqualTo(3));
    expect(overview.sessionsThisWeek, greaterThanOrEqualTo(1));
  });
}
