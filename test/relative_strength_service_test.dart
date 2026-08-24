import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/sqlite_body_weight_repository.dart';
import 'package:repset/data/sqlite_training_analytics_repository.dart';
import 'package:repset/data/sqlite_workout_repository.dart';
import 'package:repset/domain/body_weight.dart';
import 'package:repset/domain/relative_strength_service.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  var counter = 0;
  late Directory root;
  late Future<Database> database;
  late SqliteWorkoutRepository workouts;
  late SqliteBodyWeightRepository weights;
  late RelativeStrengthService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('repset-relative');
    database = AppDatabase.open(
      path: path.join(root.path, 'relative-${counter++}.db'),
    );
    workouts = SqliteWorkoutRepository(database);
    weights = SqliteBodyWeightRepository(database);
    service = RelativeStrengthService(
      SqliteTrainingAnalyticsRepository(database),
      weights,
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> logSession({
    required String id,
    required DateTime day,
    required String exerciseId,
    required String exerciseName,
    required double loadKg,
    int repetitions = 1,
  }) => workouts.save(
    WorkoutSession(
      id: id,
      title: 'Session $id',
      startedAt: day,
      completedAt: day.add(const Duration(minutes: 50)),
      exercises: [
        WorkoutExercise(
          id: 'entry-$id',
          exerciseId: exerciseId,
          name: exerciseName,
          position: 0,
          sets: [
            WorkoutSet(
              id: 'set-$id',
              exerciseId: exerciseId,
              position: 0,
              repetitions: repetitions,
              loadKg: loadKg,
              isCompleted: true,
            ),
          ],
        ),
      ],
    ),
  );

  test('returns nothing when there is no training history', () async {
    expect(await service.getInsights(), isEmpty);
  });

  test('keeps training numbers when no weigh-in exists', () async {
    await logSession(
      id: 'a',
      day: DateTime(2026, 8, 10),
      exerciseId: 'bench',
      exerciseName: 'Bench press',
      loadKg: 100,
    );

    final insights = await service.getInsights();
    expect(insights, hasLength(1));
    // The lift still reports itself; only the ratio is withheld.
    expect(insights.single.insight.bestLoadKg, 100);
    expect(insights.single.hasRelativeStrength, isFalse);
    expect(insights.single.relativeStrength, isNull);
  });

  test('pairs a lift with the body weight carried that day', () async {
    await weights.save(
      BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 80),
    );
    await logSession(
      id: 'a',
      day: DateTime(2026, 8, 10),
      exerciseId: 'squat',
      exerciseName: 'Back squat',
      loadKg: 120,
    );

    final strength = (await service.getInsights()).single.relativeStrength!;
    expect(strength.bodyWeightKg, 80);
    expect(strength.estimatedOneRepMaxKg, 120);
    expect(strength.ratio, closeTo(1.5, 1e-9));
  });

  test('prefers the strongest ratio, not the heaviest absolute lift', () async {
    await weights.save(
      BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 75),
    );
    await weights.save(
      BodyWeightEntry(measuredOn: DateTime(2026, 8, 20), weightKg: 90),
    );

    await logSession(
      id: 'light',
      day: DateTime(2026, 8, 10),
      exerciseId: 'bench',
      exerciseName: 'Bench press',
      loadKg: 120,
    );
    await logSession(
      id: 'heavy',
      day: DateTime(2026, 8, 25),
      exerciseId: 'bench',
      exerciseName: 'Bench press',
      loadKg: 135,
    );

    final strength = (await service.getInsights()).single.relativeStrength!;
    // 120/75 = 1.6 beats 135/90 = 1.5: a bigger lift at a heavier bodyweight
    // is relatively weaker.
    expect(strength.ratio, closeTo(1.6, 1e-9));
    expect(strength.bodyWeightKg, 75);
    // achievedOn is the session's completion timestamp, not midnight.
    expect(strength.achievedOn.day, 10);
  });

  test('ignores lifts logged before the first weigh-in', () async {
    await weights.save(
      BodyWeightEntry(measuredOn: DateTime(2026, 8, 15), weightKg: 80),
    );
    await logSession(
      id: 'before',
      day: DateTime(2026, 7, 1),
      exerciseId: 'deadlift',
      exerciseName: 'Deadlift',
      loadKg: 250,
    );
    await logSession(
      id: 'after',
      day: DateTime(2026, 8, 20),
      exerciseId: 'deadlift',
      exerciseName: 'Deadlift',
      loadKg: 160,
    );

    final strength = (await service.getInsights()).single.relativeStrength!;
    // The 250kg July lift has no body weight behind it, so it cannot win
    // despite being far heavier.
    expect(strength.achievedOn.day, 20);
    expect(strength.ratio, closeTo(2.0, 1e-9));
  });

  test('uses the estimated one-rep max, not the raw top set', () async {
    await weights.save(
      BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 80),
    );
    await logSession(
      id: 'reps',
      day: DateTime(2026, 8, 10),
      exerciseId: 'press',
      exerciseName: 'Overhead press',
      loadKg: 60,
      repetitions: 5,
    );

    final strength = (await service.getInsights()).single.relativeStrength!;
    // Epley on 60kg x 5 -> 60 * (1 + 5/30) = 70.
    expect(strength.estimatedOneRepMaxKg, closeTo(70, 1e-9));
    expect(strength.ratio, closeTo(70 / 80, 1e-9));
  });

  test('attaches a ratio to every lift that has one', () async {
    await weights.save(
      BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 80),
    );
    await logSession(
      id: 'squat',
      day: DateTime(2026, 8, 10),
      exerciseId: 'squat',
      exerciseName: 'Back squat',
      loadKg: 160,
    );
    await logSession(
      id: 'bench',
      day: DateTime(2026, 8, 11),
      exerciseId: 'bench',
      exerciseName: 'Bench press',
      loadKg: 100,
    );

    final insights = await service.getInsights();
    expect(insights, hasLength(2));
    expect(insights.every((entry) => entry.hasRelativeStrength), isTrue);

    final squat = insights.firstWhere(
      (entry) => entry.insight.exerciseId == 'squat',
    );
    expect(squat.relativeStrength!.ratio, closeTo(2.0, 1e-9));
  });
}
