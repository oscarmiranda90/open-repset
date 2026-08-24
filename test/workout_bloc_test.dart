import 'package:flutter_test/flutter_test.dart';
import 'package:repset/data/memory_workout_repository.dart';
import 'package:repset/domain/exercise.dart';
import 'package:repset/domain/workout_session.dart';
import 'package:repset/features/workout/workout_bloc.dart';

void main() {
  test('logs and restores a completed set with optional RPE', () async {
    final repository = MemoryWorkoutRepository();
    final bloc = WorkoutBloc(repository);

    bloc.add(const WorkoutStarted(title: 'RPE session'));
    await bloc.stream.firstWhere(
      (state) => state.hasActiveSession && !state.isSaving,
    );

    bloc.add(const WorkoutExerciseAdded(_benchPress));
    await bloc.stream.firstWhere(
      (state) => state.session?.exercises.length == 1 && !state.isSaving,
    );
    final exercise = bloc.state.session!.exercises.single;
    final set = exercise.sets.single;

    bloc.add(
      WorkoutExerciseWeightUnitChanged(
        entryId: exercise.id,
        weightUnit: WorkoutWeightUnit.pounds,
      ),
    );
    await bloc.stream.firstWhere(
      (state) =>
          state.session?.exercises.single.weightUnit ==
              WorkoutWeightUnit.pounds &&
          !state.isSaving,
    );

    bloc.add(WorkoutExerciseRestChanged(entryId: exercise.id, seconds: 90));
    await bloc.stream.firstWhere(
      (state) =>
          state.session?.exercises.single.restSeconds == 90 && !state.isSaving,
    );

    bloc.add(
      WorkoutSetUpdated(
        entryId: exercise.id,
        setId: set.id,
        repetitions: 8,
        loadKg: 100,
        rpe: 8.5,
        notes: 'Smooth reps',
        type: WorkoutSetType.working,
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.session?.sets.single.rpe == 8.5 && !state.isSaving,
    );

    bloc.add(WorkoutSetCompletionToggled(entryId: exercise.id, setId: set.id));
    await bloc.stream.firstWhere(
      (state) =>
          state.session?.sets.single.isCompleted == true && !state.isSaving,
    );

    final restored = await repository.getActive();
    expect(restored, isNotNull);
    expect(restored!.sets.single.repetitions, 8);
    expect(restored.sets.single.loadKg, 100);
    expect(restored.exercises.single.weightUnit, WorkoutWeightUnit.pounds);
    expect(restored.exercises.single.restSeconds, 90);
    expect(restored.sets.single.rpe, 8.5);
    expect(restored.sets.single.notes, 'Smooth reps');
    expect(restored.volumeKg, 800);

    await bloc.close();
  });

  test('materializes inherited ghost values when completing a set', () async {
    final repository = MemoryWorkoutRepository();
    final bloc = WorkoutBloc(repository);

    bloc.add(const WorkoutStarted());
    await bloc.stream.firstWhere(
      (state) => state.hasActiveSession && !state.isSaving,
    );
    expect(bloc.state.session!.title, "Today's Workout");

    bloc.add(const WorkoutRenamed('Leg day'));
    await bloc.stream.firstWhere(
      (state) => state.session?.title == 'Leg day' && !state.isSaving,
    );
    expect((await repository.getActive())!.title, 'Leg day');

    bloc.add(const WorkoutExerciseAdded(_benchPress));
    await bloc.stream.firstWhere(
      (state) => state.session?.exercises.length == 1 && !state.isSaving,
    );
    final exercise = bloc.state.session!.exercises.single;
    final first = exercise.sets.single;
    bloc.add(
      WorkoutSetUpdated(
        entryId: exercise.id,
        setId: first.id,
        repetitions: 10,
        loadKg: 60,
        type: WorkoutSetType.working,
      ),
    );
    await bloc.stream.firstWhere(
      (state) =>
          state.session?.sets.single.repetitions == 10 && !state.isSaving,
    );

    bloc.add(WorkoutSetAdded(exercise.id));
    await bloc.stream.firstWhere(
      (state) => state.session?.sets.length == 2 && !state.isSaving,
    );
    final second = bloc.state.session!.sets.last;
    expect(second.repetitions, 0);
    expect(second.loadKg, 0);

    bloc.add(
      WorkoutSetCompletionToggled(
        entryId: exercise.id,
        setId: second.id,
        inheritedRepetitions: 10,
        inheritedLoadKg: 60,
      ),
    );
    await bloc.stream.firstWhere(
      (state) =>
          state.session?.sets.last.isCompleted == true && !state.isSaving,
    );

    expect(bloc.state.session!.sets.last.repetitions, 10);
    expect(bloc.state.session!.sets.last.loadKg, 60);
    await bloc.close();
  });

  test('groups two exercises and advances through superset order', () async {
    final repository = MemoryWorkoutRepository();
    final bloc = WorkoutBloc(repository);

    bloc.add(const WorkoutStarted());
    await bloc.stream.firstWhere(
      (state) => state.hasActiveSession && !state.isSaving,
    );
    bloc.add(
      const WorkoutExercisesAdded([_benchPress, _squat], asSuperset: true),
    );
    await bloc.stream.firstWhere(
      (state) => state.session?.exercises.length == 2 && !state.isSaving,
    );
    final bench = bloc.state.session!.exercises.first;
    final squat = bloc.state.session!.exercises.last;
    expect(bench.supersetId, isNotNull);
    expect(squat.supersetId, bench.supersetId);

    bloc.add(WorkoutSetAdded(bench.id));
    await bloc.stream.firstWhere(
      (state) =>
          state.session!.exercises.first.sets.length == 2 &&
          state.session!.exercises.last.sets.length == 2 &&
          !state.isSaving,
    );
    final current = bloc.state.session!;
    final benchFirst = current.exercises.first.sets.first;
    final benchSecond = current.exercises.first.sets.last;
    final squatFirst = current.exercises.last.sets.first;

    for (final target in [
      (entryId: bench.id, setId: benchFirst.id),
      (entryId: squat.id, setId: squatFirst.id),
    ]) {
      bloc.add(
        WorkoutSetUpdated(
          entryId: target.entryId,
          setId: target.setId,
          repetitions: 8,
          loadKg: 50,
          type: WorkoutSetType.working,
        ),
      );
      await bloc.stream.firstWhere(
        (state) =>
            state.session!.sets
                .firstWhere((set) => set.id == target.setId)
                .repetitions ==
            8,
      );
    }

    bloc.add(
      WorkoutSetCompletionToggled(entryId: bench.id, setId: benchFirst.id),
    );
    await bloc.stream.firstWhere(
      (state) => state.focusedSetId == squatFirst.id,
    );
    expect(bloc.state.focusedSetId, squatFirst.id);

    bloc.add(
      WorkoutSetCompletionToggled(entryId: squat.id, setId: squatFirst.id),
    );
    await bloc.stream.firstWhere(
      (state) => state.focusedSetId == benchSecond.id,
    );
    expect(bloc.state.focusedSetId, benchSecond.id);
    await bloc.close();
  });

  test('reorders, duplicates, and replaces an exercise persistently', () async {
    final repository = MemoryWorkoutRepository();
    final bloc = WorkoutBloc(repository);

    bloc.add(const WorkoutStarted());
    await bloc.stream.firstWhere(
      (state) => state.hasActiveSession && !state.isSaving,
    );
    bloc.add(const WorkoutExercisesAdded([_benchPress, _squat]));
    await bloc.stream.firstWhere(
      (state) => state.session?.exercises.length == 2 && !state.isSaving,
    );

    final bench = bloc.state.session!.exercises.first;
    bloc.add(WorkoutExerciseMoved(entryId: bench.id, toIndex: 2));
    await bloc.stream.firstWhere(
      (state) =>
          state.session?.exercises.first.exerciseId == _squat.id &&
          !state.isSaving,
    );

    final movedBench = bloc.state.session!.exercises.last;
    bloc.add(WorkoutExerciseDuplicated(movedBench.id));
    await bloc.stream.firstWhere(
      (state) => state.session?.exercises.length == 3 && !state.isSaving,
    );
    final duplicate = bloc.state.session!.exercises.last;
    expect(duplicate.id, isNot(movedBench.id));
    expect(duplicate.exerciseId, _benchPress.id);
    expect(duplicate.sets.single.isCompleted, isFalse);

    bloc.add(
      WorkoutExerciseReplaced(entryId: duplicate.id, replacement: _squat),
    );
    await bloc.stream.firstWhere(
      (state) =>
          state.session!.exercises.last.exerciseId == _squat.id &&
          !state.isSaving,
    );
    final replaced = bloc.state.session!.exercises.last;
    expect(replaced.name, _squat.name);
    expect(replaced.sets, hasLength(1));
    expect(replaced.sets.single.repetitions, 0);
    expect(
      (await repository.getActive())!.exercises.last.exerciseId,
      _squat.id,
    );
    await bloc.close();
  });
}

const _benchPress = Exercise(
  id: 'bench-press',
  name: 'Bench press',
  bodyPart: 'Upper body',
  target: 'Chest',
  equipment: 'Barbell',
  secondaryMuscles: ['Triceps'],
  instructions: ['Press'],
);

const _squat = Exercise(
  id: 'squat',
  name: 'Back squat',
  bodyPart: 'Lower body',
  target: 'Quadriceps',
  equipment: 'Barbell',
  secondaryMuscles: ['Glutes'],
  instructions: ['Squat'],
);
