import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/exercise.dart';

class SqliteExerciseStore {
  SqliteExerciseStore(this._database);
  final Future<Database> _database;

  Future<List<Exercise>> read(String languageCode) async {
    final database = await _database;
    final rows = await database.rawQuery(
      'SELECT e.*, CASE WHEN f.exercise_id IS NULL THEN 0 ELSE 1 END AS is_favorite FROM exercises e LEFT JOIN favorite_exercises f ON f.exercise_id = e.id WHERE e.language_code = ? ORDER BY is_favorite DESC, e.name COLLATE NOCASE',
      [languageCode],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> replaceRemote(
    String languageCode,
    List<Exercise> exercises,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'exercises',
        where: 'language_code = ? AND is_custom = 0',
        whereArgs: [languageCode],
      );
      final batch = transaction.batch();
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      for (final exercise in exercises) {
        batch.insert('exercises', _toRow(exercise, languageCode, updatedAt));
      }
      await batch.commit(noResult: true);
    });
  }

  /// Custom exercises are local-only and deliberately survive catalogue refreshes.
  Future<void> saveCustom(String languageCode, Exercise exercise) async {
    final database = await _database;
    await database.insert(
      'exercises',
      _toRow(exercise, languageCode, DateTime.now().millisecondsSinceEpoch),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setFavorite(
    String exerciseId, {
    required bool isFavorite,
  }) async {
    final database = await _database;
    if (isFavorite) {
      await database.insert('favorite_exercises', {
        'exercise_id': exerciseId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await database.delete(
        'favorite_exercises',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
      );
    }
  }

  Map<String, Object?> _toRow(
    Exercise exercise,
    String languageCode,
    int updatedAt,
  ) => {
    'id': exercise.id,
    'language_code': languageCode,
    'name': exercise.name,
    'body_part': exercise.bodyPart,
    'target': exercise.target,
    'equipment': exercise.equipment,
    'secondary_muscles': jsonEncode(exercise.secondaryMuscles),
    'instructions': jsonEncode(exercise.instructions),
    'media_url': exercise.mediaUrl,
    'is_custom': exercise.isCustom ? 1 : 0,
    'updated_at': updatedAt,
  };

  Exercise _fromRow(Map<String, Object?> row) => Exercise(
    id: row['id']! as String,
    name: row['name']! as String,
    bodyPart: row['body_part']! as String,
    target: row['target']! as String,
    equipment: row['equipment']! as String,
    secondaryMuscles: List<String>.from(
      jsonDecode(row['secondary_muscles']! as String) as List,
    ),
    instructions: List<String>.from(
      jsonDecode(row['instructions']! as String) as List,
    ),
    mediaUrl: row['media_url'] as String?,
    isFavorite: (row['is_favorite'] as int? ?? 0) == 1,
    isCustom: (row['is_custom']! as int) == 1,
  );
}
