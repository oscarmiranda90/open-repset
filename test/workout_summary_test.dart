import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/sqlite_workout_repository.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:repset/domain/workout_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WorkoutSet _set({
  required String id,
  required String exerciseId,
  required int position,
  required int repetitions,
  required double loadKg,
  double? rpe,
  bool isCompleted = true,
}) => WorkoutSet(
  id: id,
  exerciseId: exerciseId,
  position: position,
  repetitions: repetitions,
  loadKg: loadKg,
  rpe: rpe,
  isCompleted: isCompleted,
);

WorkoutSession _session({
  required String id,
  required DateTime startedAt,
  DateTime? completedAt,
  required List<WorkoutExercise> exercises,
}) => WorkoutSession(
  id: id,
  title: 'Session $id',
  startedAt: startedAt,
  completedAt: completedAt,
  exercises: exercises,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // sqflite_ffi shares one in-memory database across the whole process, so a
  // per-test file is the only way to keep session history isolated.
  var databaseCounter = 0;
  late Directory temporaryRoot;

  setUp(() {
    temporaryRoot = Directory.systemTemp.createTempSync('repset-summary');
  });

  tearDown(() {
    if (temporaryRoot.existsSync()) {
      temporaryRoot.deleteSync(recursive: true);
    }
  });

  SqliteWorkoutRepository newRepository() => SqliteWorkoutRepository(
    AppDatabase.open(
      path: path.join(temporaryRoot.path, 'summary-${databaseCounter++}.db'),
    ),
  );

  test(
    'reports every completed set as a record on the first session',
    () async {
      final repository = newRepository();
      final summary = await buildWorkoutSummary(
        repository: repository,
        session: _session(
          id: 'first',
          startedAt: DateTime(2026, 8, 24, 9),
          completedAt: DateTime(2026, 8, 24, 10),
          exercises: [
            WorkoutExercise(
              id: 'entry-1',
              exerciseId: 'bench',
              name: 'Bench press',
              position: 0,
              sets: [
                _set(
                  id: 's1',
                  exerciseId: 'bench',
                  position: 0,
                  repetitions: 8,
                  loadKg: 60,
                ),
              ],
            ),
          ],
        ),
      );

      expect(summary.isFirstSession, isTrue);
      expect(summary.records, hasLength(2));
      expect(summary.records.every((record) => record.isFirstTime), isTrue);
      expect(summary.completedSetCount, 1);
      expect(summary.volumeKg, 480);
      expect(summary.totalReps, 8);
      expect(summary.hasVolumeComparison, isFalse);
    },
  );

  test(
    'only flags a heavier set than the stored history as a record',
    () async {
      final repository = newRepository();
      await repository.save(
        _session(
          id: 'past',
          startedAt: DateTime(2026, 8, 20, 9),
          completedAt: DateTime(2026, 8, 20, 10),
          exercises: [
            WorkoutExercise(
              id: 'past-entry',
              exerciseId: 'bench',
              name: 'Bench press',
              position: 0,
              sets: [
                _set(
                  id: 'past-set',
                  exerciseId: 'bench',
                  position: 0,
                  repetitions: 5,
                  loadKg: 80,
                ),
              ],
            ),
          ],
        ),
      );

      final matched = await buildWorkoutSummary(
        repository: repository,
        session: _session(
          id: 'equal',
          startedAt: DateTime(2026, 8, 24, 9),
          completedAt: DateTime(2026, 8, 24, 10),
          exercises: [
            WorkoutExercise(
              id: 'entry',
              exerciseId: 'bench',
              name: 'Bench press',
              position: 0,
              sets: [
                _set(
                  id: 'set',
                  exerciseId: 'bench',
                  position: 0,
                  repetitions: 5,
                  loadKg: 80,
                ),
              ],
            ),
          ],
        ),
      );
      // Matching the previous best is not beating it.
      expect(
        matched.records.where(
          (record) => record.kind == WorkoutRecordKind.heaviestSet,
        ),
        isEmpty,
      );

      final beaten = await buildWorkoutSummary(
        repository: repository,
        session: _session(
          id: 'heavier',
          startedAt: DateTime(2026, 8, 24, 9),
          completedAt: DateTime(2026, 8, 24, 10),
          exercises: [
            WorkoutExercise(
              id: 'entry',
              exerciseId: 'bench',
              name: 'Bench press',
              position: 0,
              sets: [
                _set(
                  id: 'set',
                  exerciseId: 'bench',
                  position: 0,
                  repetitions: 3,
                  loadKg: 85,
                ),
              ],
            ),
          ],
        ),
      );
      final loadRecord = beaten.records.firstWhere(
        (record) => record.kind == WorkoutRecordKind.heaviestSet,
      );
      expect(loadRecord.value, 85);
      expect(loadRecord.previousValue, 80);
      expect(loadRecord.improvement, 5);
      expect(loadRecord.isFirstTime, isFalse);
    },
  );

  test('ignores sets that were never completed', () async {
    final repository = newRepository();
    final summary = await buildWorkoutSummary(
      repository: repository,
      session: _session(
        id: 'partial',
        startedAt: DateTime(2026, 8, 24, 9),
        completedAt: DateTime(2026, 8, 24, 10),
        exercises: [
          WorkoutExercise(
            id: 'entry',
            exerciseId: 'squat',
            name: 'Back squat',
            position: 0,
            sets: [
              _set(
                id: 'done',
                exerciseId: 'squat',
                position: 0,
                repetitions: 5,
                loadKg: 100,
              ),
              _set(
                id: 'skipped',
                exerciseId: 'squat',
                position: 1,
                repetitions: 5,
                loadKg: 200,
                isCompleted: false,
              ),
            ],
          ),
        ],
      ),
    );

    expect(summary.completedSetCount, 1);
    expect(summary.heaviestSetKg, 100);
    expect(summary.volumeKg, 500);
    final loadRecord = summary.records.firstWhere(
      (record) => record.kind == WorkoutRecordKind.heaviestSet,
    );
    // The uncompleted 200kg set must not become a record.
    expect(loadRecord.value, 100);
  });

  test('compares volume against the most recent completed session', () async {
    final repository = newRepository();
    await repository.save(
      _session(
        id: 'older',
        startedAt: DateTime(2026, 8, 18, 9),
        completedAt: DateTime(2026, 8, 18, 10),
        exercises: [
          WorkoutExercise(
            id: 'older-entry',
            exerciseId: 'row',
            name: 'Barbell row',
            position: 0,
            sets: [
              _set(
                id: 'older-set',
                exerciseId: 'row',
                position: 0,
                repetitions: 10,
                loadKg: 100,
              ),
            ],
          ),
        ],
      ),
    );
    await repository.save(
      _session(
        id: 'newer',
        startedAt: DateTime(2026, 8, 22, 9),
        completedAt: DateTime(2026, 8, 22, 10),
        exercises: [
          WorkoutExercise(
            id: 'newer-entry',
            exerciseId: 'row',
            name: 'Barbell row',
            position: 0,
            sets: [
              _set(
                id: 'newer-set',
                exerciseId: 'row',
                position: 0,
                repetitions: 10,
                loadKg: 50,
              ),
            ],
          ),
        ],
      ),
    );

    final summary = await buildWorkoutSummary(
      repository: repository,
      session: _session(
        id: 'current',
        startedAt: DateTime(2026, 8, 24, 9),
        completedAt: DateTime(2026, 8, 24, 10),
        exercises: [
          WorkoutExercise(
            id: 'current-entry',
            exerciseId: 'row',
            name: 'Barbell row',
            position: 0,
            sets: [
              _set(
                id: 'current-set',
                exerciseId: 'row',
                position: 0,
                repetitions: 10,
                loadKg: 75,
              ),
            ],
          ),
        ],
      ),
    );

    expect(summary.completedSessionCount, 2);
    // The 22nd is more recent than the 18th, so 500 kg is the baseline.
    expect(summary.previousSessionVolumeKg, 500);
    expect(summary.volumeKg, 750);
    expect(summary.volumeDelta, closeTo(.5, 1e-9));
  });

  test('averages RPE across only the sets that recorded one', () async {
    final repository = newRepository();
    final summary = await buildWorkoutSummary(
      repository: repository,
      session: _session(
        id: 'rpe',
        startedAt: DateTime(2026, 8, 24, 9),
        completedAt: DateTime(2026, 8, 24, 9, 45),
        exercises: [
          WorkoutExercise(
            id: 'e',
            exerciseId: 'ohp',
            name: 'Overhead press',
            position: 0,
            sets: [
              _set(
                id: 'a',
                exerciseId: 'ohp',
                position: 0,
                repetitions: 5,
                loadKg: 40,
                rpe: 8,
              ),
              _set(
                id: 'b',
                exerciseId: 'ohp',
                position: 1,
                repetitions: 5,
                loadKg: 40,
                rpe: 9,
              ),
              _set(
                id: 'c',
                exerciseId: 'ohp',
                position: 2,
                repetitions: 5,
                loadKg: 40,
              ),
            ],
          ),
        ],
      ),
    );

    expect(summary.averageRpe, closeTo(8.5, 1e-9));
    expect(summary.duration, const Duration(minutes: 45));
    expect(summary.exerciseCount, 1);
  });
}
