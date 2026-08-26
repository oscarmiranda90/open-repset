import 'exercise.dart';

abstract interface class ExerciseRepository {
  Future<List<Exercise>> loadCached(String languageCode);
  Future<List<Exercise>> refresh(String languageCode);
  Future<void> saveCustom(String languageCode, Exercise exercise);
  Future<void> setFavorite(String exerciseId, {required bool isFavorite});
}
