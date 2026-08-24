import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';
import 'r2_exercise_source.dart';
import 'sqlite_exercise_store.dart';

class OfflineFirstExerciseRepository implements ExerciseRepository {
  OfflineFirstExerciseRepository(this._local, this._remote);
  final SqliteExerciseStore _local;
  final R2ExerciseSource _remote;

  @override
  Future<List<Exercise>> loadCached(String languageCode) =>
      _local.read(languageCode);

  @override
  Future<List<Exercise>> refresh(String languageCode) async {
    final remoteExercises = await _remote.fetch(languageCode);
    await _local.replaceRemote(languageCode, remoteExercises);
    return _local.read(languageCode);
  }

  @override
  Future<void> setFavorite(String exerciseId, {required bool isFavorite}) =>
      _local.setFavorite(exerciseId, isFavorite: isFavorite);
}
