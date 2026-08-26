import 'package:flutter_test/flutter_test.dart';
import 'package:repset/data/demo_exercise_repository.dart';
import 'package:repset/domain/exercise.dart';
import 'package:repset/features/library/library_bloc.dart';

void main() {
  test('filters catalog and toggles a favorite', () async {
    final bloc = LibraryBloc(DemoExerciseRepository());
    bloc.add(const LibraryStarted());
    await bloc.stream.firstWhere(
      (state) => !state.isLoading && !state.isRefreshing,
    );

    bloc.add(const LibrarySearchChanged('hamstrings'));
    await bloc.stream.firstWhere((state) => state.query == 'hamstrings');
    expect(bloc.state.visibleExercises.single.name, 'Romanian deadlift');

    final exercise = bloc.state.visibleExercises.single;
    bloc.add(LibraryFavoriteToggled(exercise));
    await bloc.stream.firstWhere(
      (state) => state.exercises.any(
        (item) => item.id == exercise.id && item.isFavorite,
      ),
    );
    expect(
      bloc.state.exercises
          .singleWhere((item) => item.id == exercise.id)
          .isFavorite,
      isTrue,
    );

    await bloc.close();
  });

  test('adds a custom exercise to the library', () async {
    final bloc = LibraryBloc(DemoExerciseRepository());
    bloc.add(const LibraryStarted());
    await bloc.stream.firstWhere(
      (state) => !state.isLoading && !state.isRefreshing,
    );

    const custom = Exercise(
      id: 'custom-machine',
      name: 'Custom machine press',
      bodyPart: 'Custom',
      target: 'Chest',
      equipment: 'Gym machine',
      secondaryMuscles: [],
      instructions: [],
      isCustom: true,
    );
    bloc.add(const LibraryCustomExerciseCreated(custom));
    await bloc.stream.firstWhere(
      (state) => state.exercises.any((exercise) => exercise.id == custom.id),
    );

    expect(
      bloc.state.exercises
          .singleWhere((exercise) => exercise.id == custom.id)
          .isCustom,
      isTrue,
    );
    await bloc.close();
  });
}
