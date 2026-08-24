import '../domain/exercise_repository.dart';
import '../domain/muscle_map.dart';
import '../domain/workout_repository.dart';

/// Muscle coverage over in-memory repositories, for the no-database fallback
/// and for tests.
class MemoryMuscleCoverageRepository implements MuscleCoverageRepository {
  const MemoryMuscleCoverageRepository(
    this._workouts,
    this._exercises, [
    this._languageCode = 'en',
  ]);

  final WorkoutRepository _workouts;
  final ExerciseRepository _exercises;
  final String _languageCode;

  /// Matches the SQLite implementation so both surfaces agree on how much a
  /// secondary muscle earns from a set.
  static const _secondaryWeight = .4;

  @override
  Future<MuscleCoverage> getCoverage({int days = 30}) async {
    final now = DateTime.now();
    final since = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    final catalogue = {
      for (final exercise in await _exercises.loadCached(_languageCode))
        exercise.id: exercise,
    };

    final volumes = <MuscleGroup, double>{};
    final setCounts = <MuscleGroup, int>{};
    var unmapped = 0.0;

    for (final session in await _workouts.getCompletedSessions()) {
      final completedAt = session.completedAt;
      if (completedAt == null || completedAt.isBefore(since)) continue;

      for (final exercise in session.exercises) {
        final completedSets = exercise.sets.where((set) => set.isCompleted);
        if (completedSets.isEmpty) continue;

        final volume = completedSets.fold<double>(
          0,
          (total, set) => total + set.volumeKg,
        );
        if (volume <= 0) continue;

        final catalogEntry = catalogue[exercise.exerciseId];
        final primary =
            resolveMuscleGroup(catalogEntry?.target) ??
            resolveMuscleGroup(catalogEntry?.bodyPart);

        if (primary == null) {
          unmapped += volume;
          continue;
        }

        volumes[primary] = (volumes[primary] ?? 0) + volume;
        setCounts[primary] = (setCounts[primary] ?? 0) + completedSets.length;

        final secondaries = (catalogEntry?.secondaryMuscles ?? const <String>[])
            .map(resolveMuscleGroup)
            .whereType<MuscleGroup>()
            .toSet();
        for (final group in secondaries) {
          if (group == primary) continue;
          volumes[group] = (volumes[group] ?? 0) + volume * _secondaryWeight;
          setCounts[group] ??= 0;
        }
      }
    }

    return MuscleCoverage(
      volumes: {
        for (final entry in volumes.entries)
          entry.key: MuscleGroupVolume(
            group: entry.key,
            volumeKg: entry.value,
            setCount: setCounts[entry.key] ?? 0,
          ),
      },
      unmappedVolumeKg: unmapped,
      since: since,
    );
  }
}
