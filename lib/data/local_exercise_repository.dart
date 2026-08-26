import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';
import 'demo_exercise_repository.dart';
import 'sqlite_exercise_store.dart';

/// Durable local catalogue for native builds without a configured remote source.
///
/// It seeds the community demo catalogue once, then lets people keep their own
/// exercises on-device without depending on a network service.
class LocalExerciseRepository implements ExerciseRepository {
  LocalExerciseRepository(this._local, {ExerciseRepository? seed})
    : _seed = seed ?? DemoExerciseRepository();

  final SqliteExerciseStore _local;
  final ExerciseRepository _seed;

  @override
  Future<List<Exercise>> loadCached(String languageCode) =>
      _local.read(languageCode);

  @override
  Future<List<Exercise>> refresh(String languageCode) async {
    final cached = await _local.read(languageCode);
    if (cached.isNotEmpty) return cached;
    final exercises = await _seed.loadCached(languageCode);
    await _local.replaceRemote(languageCode, exercises);
    return _local.read(languageCode);
  }

  @override
  Future<void> saveCustom(String languageCode, Exercise exercise) =>
      _local.saveCustom(languageCode, exercise);

  @override
  Future<void> setFavorite(String exerciseId, {required bool isFavorite}) =>
      _local.setFavorite(exerciseId, isFavorite: isFavorite);
}
