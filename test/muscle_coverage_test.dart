import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/sqlite_muscle_coverage_repository.dart';
import 'package:repset/data/sqlite_workout_repository.dart';
import 'package:repset/domain/muscle_map.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('name resolution', () {
    test('maps the catalogue vocabulary onto illustration groups', () {
      expect(resolveMuscleGroup('pectorals'), MuscleGroup.chest);
      expect(resolveMuscleGroup('lats'), MuscleGroup.back);
      expect(resolveMuscleGroup('upper back'), MuscleGroup.back);
      expect(resolveMuscleGroup('delts'), MuscleGroup.shoulders);
      expect(resolveMuscleGroup('biceps'), MuscleGroup.biceps);
      expect(resolveMuscleGroup('triceps'), MuscleGroup.triceps);
      expect(resolveMuscleGroup('quads'), MuscleGroup.quads);
      expect(resolveMuscleGroup('hamstrings'), MuscleGroup.hamstrings);
      expect(resolveMuscleGroup('glutes'), MuscleGroup.glutes);
      expect(resolveMuscleGroup('calves'), MuscleGroup.calves);
      expect(resolveMuscleGroup('abs'), MuscleGroup.core);
      expect(resolveMuscleGroup('forearms'), MuscleGroup.forearms);
    });

    test('ignores case and surrounding whitespace', () {
      expect(resolveMuscleGroup('  Pectorals '), MuscleGroup.chest);
      expect(resolveMuscleGroup('SPINE'), MuscleGroup.back);
    });

    test('returns null rather than guessing at an unknown name', () {
      // Shading the wrong muscle is worse than shading none: the map would
      // then report training that never happened.
      expect(resolveMuscleGroup('cardiovascular system'), isNull);
      expect(resolveMuscleGroup(''), isNull);
      expect(resolveMuscleGroup(null), isNull);
    });
  });

  group('coverage', () {
    var counter = 0;
    late Directory root;
    late Future<Database> database;
    late SqliteWorkoutRepository workouts;
    late SqliteMuscleCoverageRepository coverage;

    setUp(() {
      root = Directory.systemTemp.createTempSync('repset-muscles');
      database = AppDatabase.open(
        path: path.join(root.path, 'muscles-${counter++}.db'),
      );
      workouts = SqliteWorkoutRepository(database);
      coverage = SqliteMuscleCoverageRepository(database);
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<void> addExercise({
      required String id,
      required String target,
      String bodyPart = 'upper body',
      List<String> secondary = const [],
    }) async {
      final db = await database;
      await db.insert('exercises', {
        'id': id,
        'language_code': 'en',
        'name': id,
        'body_part': bodyPart,
        'target': target,
        'equipment': 'barbell',
        'secondary_muscles': jsonEncode(secondary),
        'instructions': jsonEncode(<String>[]),
        'is_custom': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    Future<void> logSession({
      required String id,
      required String exerciseId,
      required double loadKg,
      int repetitions = 10,
      int daysAgo = 1,
      int setCount = 1,
    }) async {
      final day = DateTime.now().subtract(Duration(days: daysAgo));
      await workouts.save(
        WorkoutSession(
          id: id,
          title: 'Session $id',
          startedAt: day,
          completedAt: day.add(const Duration(minutes: 45)),
          exercises: [
            WorkoutExercise(
              id: 'entry-$id',
              exerciseId: exerciseId,
              name: exerciseId,
              position: 0,
              sets: List.generate(
                setCount,
                (index) => WorkoutSet(
                  id: 'set-$id-$index',
                  exerciseId: exerciseId,
                  position: index,
                  repetitions: repetitions,
                  loadKg: loadKg,
                  isCompleted: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    test('reports nothing without training', () async {
      final result = await coverage.getCoverage();
      expect(result.hasData, isFalse);
      expect(result.peakVolumeKg, 0);
      // With no data every group is untrained, which is still the truth.
      expect(result.untrainedGroups, hasLength(MuscleGroup.values.length));
    });

    test('credits the primary target with the full volume', () async {
      await addExercise(id: 'bench', target: 'pectorals');
      await logSession(id: 'a', exerciseId: 'bench', loadKg: 80);

      final result = await coverage.getCoverage();
      expect(result.volumes[MuscleGroup.chest]!.volumeKg, 800);
      expect(result.volumes[MuscleGroup.chest]!.setCount, 1);
      expect(result.intensityOf(MuscleGroup.chest), 1);
    });

    test('credits secondary muscles at a reduced weight', () async {
      await addExercise(
        id: 'bench',
        target: 'pectorals',
        secondary: ['triceps', 'delts'],
      );
      await logSession(id: 'a', exerciseId: 'bench', loadKg: 100);

      final result = await coverage.getCoverage();
      // Full credit for triceps would make every push day read as an arm day.
      expect(result.volumes[MuscleGroup.chest]!.volumeKg, 1000);
      expect(result.volumes[MuscleGroup.triceps]!.volumeKg, 400);
      expect(result.volumes[MuscleGroup.shoulders]!.volumeKg, 400);
      expect(result.intensityOf(MuscleGroup.triceps), closeTo(.4, 1e-9));
    });

    test('does not double count a muscle that is both primary and secondary', () async {
      await addExercise(
        id: 'curl',
        target: 'biceps',
        secondary: ['biceps', 'forearms'],
      );
      await logSession(id: 'a', exerciseId: 'curl', loadKg: 30);

      final result = await coverage.getCoverage();
      expect(result.volumes[MuscleGroup.biceps]!.volumeKg, 300);
      expect(result.volumes[MuscleGroup.forearms]!.volumeKg, 120);
    });

    test('surfaces volume it could not attribute instead of hiding it', () async {
      await addExercise(
        id: 'treadmill',
        target: 'cardiovascular system',
        bodyPart: 'cardio',
      );
      await logSession(id: 'a', exerciseId: 'treadmill', loadKg: 5);

      final result = await coverage.getCoverage();
      expect(result.hasData, isFalse);
      // Silently dropping it would make the map under-report without saying so.
      expect(result.unmappedVolumeKg, 50);
    });

    test('falls back to body part when the target is unmapped', () async {
      await addExercise(
        id: 'plank',
        target: 'unknown muscle',
        bodyPart: 'core',
      );
      await logSession(id: 'a', exerciseId: 'plank', loadKg: 10);

      final result = await coverage.getCoverage();
      expect(result.volumes[MuscleGroup.core]!.volumeKg, 100);
    });

    test('honours the requested window', () async {
      await addExercise(id: 'squat', target: 'quads');
      await logSession(id: 'recent', exerciseId: 'squat', loadKg: 100, daysAgo: 3);
      await logSession(id: 'old', exerciseId: 'squat', loadKg: 200, daysAgo: 60);

      final month = await coverage.getCoverage(days: 30);
      expect(month.volumes[MuscleGroup.quads]!.volumeKg, 1000);

      final quarter = await coverage.getCoverage(days: 90);
      expect(quarter.volumes[MuscleGroup.quads]!.volumeKg, 3000);
    });

    test('names the untrained groups', () async {
      await addExercise(id: 'bench', target: 'pectorals');
      await logSession(id: 'a', exerciseId: 'bench', loadKg: 80);

      final result = await coverage.getCoverage();
      final untrained = result.untrainedGroups;
      expect(untrained, isNot(contains(MuscleGroup.chest)));
      expect(untrained, contains(MuscleGroup.hamstrings));
      expect(untrained, contains(MuscleGroup.calves));
    });

    test('normalises intensity against the busiest muscle', () async {
      await addExercise(id: 'squat', target: 'quads');
      await addExercise(id: 'curl', target: 'biceps');
      await logSession(id: 'legs', exerciseId: 'squat', loadKg: 100);
      await logSession(id: 'arms', exerciseId: 'curl', loadKg: 25);

      final result = await coverage.getCoverage();
      expect(result.intensityOf(MuscleGroup.quads), 1);
      expect(result.intensityOf(MuscleGroup.biceps), closeTo(.25, 1e-9));
    });

    test('ignores sets that were never completed', () async {
      await addExercise(id: 'row', target: 'lats');
      final day = DateTime.now().subtract(const Duration(days: 1));
      await workouts.save(
        WorkoutSession(
          id: 'partial',
          title: 'Partial',
          startedAt: day,
          completedAt: day.add(const Duration(minutes: 30)),
          exercises: [
            WorkoutExercise(
              id: 'entry',
              exerciseId: 'row',
              name: 'Barbell row',
              position: 0,
              sets: [
                WorkoutSet(
                  id: 'done',
                  exerciseId: 'row',
                  position: 0,
                  repetitions: 10,
                  loadKg: 60,
                  isCompleted: true,
                ),
                WorkoutSet(
                  id: 'skipped',
                  exerciseId: 'row',
                  position: 1,
                  repetitions: 10,
                  loadKg: 500,
                  isCompleted: false,
                ),
              ],
            ),
          ],
        ),
      );

      final result = await coverage.getCoverage();
      expect(result.volumes[MuscleGroup.back]!.volumeKg, 600);
    });
  });
}
