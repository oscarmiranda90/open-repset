import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/sqlite_workout_repository.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('round-trips an editable set and its RPE through SQLite', () async {
    final database = AppDatabase.open(path: inMemoryDatabasePath);
    final repository = SqliteWorkoutRepository(database);
    final startedAt = DateTime(2026, 8, 23, 10);
    final session = WorkoutSession(
      id: 'session-1',
      title: 'Strength',
      startedAt: startedAt,
      exercises: [
        WorkoutExercise(
          id: 'entry-1',
          exerciseId: 'squat',
          name: 'Back squat',
          position: 0,
          weightUnit: WorkoutWeightUnit.pounds,
          restSeconds: 90,
          supersetId: 'superset-1',
          sets: const [
            WorkoutSet(
              id: 'set-1',
              exerciseId: 'squat',
              position: 0,
              repetitions: 5,
              loadKg: 120,
              rpe: 9.5,
              notes: 'Hard but clean',
            ),
          ],
        ),
      ],
    );

    await repository.save(session);
    final restored = await repository.getActive();

    expect(restored!.title, 'Strength');
    expect(restored.exercises.single.name, 'Back squat');
    expect(restored.exercises.single.weightUnit, WorkoutWeightUnit.pounds);
    expect(restored.exercises.single.restSeconds, 90);
    expect(restored.exercises.single.supersetId, 'superset-1');
    expect(restored.sets.single.rpe, 9.5);
    expect(restored.sets.single.isCompleted, isFalse);
    expect(restored.sets.single.completedAt, isNull);

    await (await database).close();
  });

  test('aggregates only completed exercise history', () async {
    final database = AppDatabase.open(path: inMemoryDatabasePath);
    final repository = SqliteWorkoutRepository(database);
    final startedAt = DateTime(2026, 8, 23, 10);
    await repository.save(
      WorkoutSession(
        id: 'completed-session',
        title: 'Push day',
        startedAt: startedAt,
        completedAt: startedAt.add(const Duration(hours: 1)),
        exercises: [
          WorkoutExercise(
            id: 'completed-entry',
            exerciseId: 'bench',
            name: 'Bench press',
            position: 0,
            sets: [
              WorkoutSet(
                id: 'completed-set',
                exerciseId: 'bench',
                position: 0,
                repetitions: 8,
                loadKg: 100,
                isCompleted: true,
                completedAt: startedAt.add(const Duration(minutes: 10)),
              ),
            ],
          ),
        ],
      ),
    );
    await repository.save(
      WorkoutSession(
        id: 'active-session',
        title: 'Current workout',
        startedAt: startedAt.add(const Duration(days: 1)),
        exercises: const [
          WorkoutExercise(
            id: 'active-entry',
            exerciseId: 'bench',
            name: 'Bench press',
            position: 0,
            sets: [
              WorkoutSet(
                id: 'active-set',
                exerciseId: 'bench',
                position: 0,
                repetitions: 10,
                loadKg: 120,
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
    );

    final stats = await repository.getExerciseHistory('bench');

    expect(stats.sessionCount, 1);
    expect(stats.completedSetCount, 1);
    expect(stats.bestLoadKg, 100);
    expect(stats.totalVolumeKg, 800);
    await (await database).close();
  });

  test('migrates completed version-one sets without losing them', () async {
    final directory = await Directory.systemTemp.createTemp('repset-v1-test-');
    final databasePath = path.join(directory.path, 'legacy.db');
    final oldDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute(
            'CREATE TABLE workout_sessions(id TEXT PRIMARY KEY, title TEXT NOT NULL, started_at INTEGER NOT NULL, completed_at INTEGER)',
          );
          await database.execute(
            'CREATE TABLE workout_sets(id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, repetitions INTEGER NOT NULL, load_kg REAL NOT NULL, completed_at INTEGER NOT NULL, FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE)',
          );
        },
      ),
    );
    await oldDatabase.insert('workout_sessions', {
      'id': 'legacy-session',
      'title': 'Legacy workout',
      'started_at': 1000,
      'completed_at': null,
    });
    await oldDatabase.insert('workout_sets', {
      'session_id': 'legacy-session',
      'exercise_id': 'legacy-bench',
      'repetitions': 10,
      'load_kg': 80.0,
      'completed_at': 2000,
    });
    await oldDatabase.close();

    final upgraded = AppDatabase.open(path: databasePath);
    final restored = await SqliteWorkoutRepository(upgraded).getActive();

    expect(restored!.sets.single.repetitions, 10);
    expect(restored.exercises.single.restSeconds, 120);
    expect(restored.sets.single.isCompleted, isTrue);
    expect(restored.sets.single.rpe, isNull);

    await (await upgraded).close();
    await directory.delete(recursive: true);
  });
}
