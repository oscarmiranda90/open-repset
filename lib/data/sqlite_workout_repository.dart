import 'package:sqflite/sqflite.dart';

import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';
import '../domain/workout_template.dart';

/// Offline source of truth for training data. Any future sync is an outbound job,
/// never a dependency for a person to finish a workout.
class SqliteWorkoutRepository implements WorkoutRepository {
  SqliteWorkoutRepository(this._database);

  final Future<Database> _database;

  @override
  Future<WorkoutSession?> getActive() async {
    final db = await _database;
    final rows = await db.query(
      'workout_sessions',
      where: 'completed_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _readSession(db, rows.single);
  }

  @override
  Future<List<WorkoutSession>> getCompletedSessions() async {
    final db = await _database;
    final rows = await db.query(
      'workout_sessions',
      where: 'completed_at IS NOT NULL',
      orderBy: 'completed_at DESC',
    );
    return Future.wait(rows.map((row) => _readSession(db, row)));
  }

  @override
  Future<WorkoutSession?> getSession(String sessionId) async {
    final db = await _database;
    final rows = await db.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : _readSession(db, rows.single);
  }

  Future<WorkoutSession> _readSession(
    Database db,
    Map<String, Object?> session,
  ) async {
    final exerciseRows = await db.query(
      'workout_exercises',
      where: 'session_id = ?',
      whereArgs: [session['id']],
      orderBy: 'position ASC',
    );
    final setRows = await db.query(
      'workout_sets',
      where: 'session_id = ?',
      whereArgs: [session['id']],
      orderBy: 'position ASC',
    );

    return WorkoutSession(
      id: session['id']! as String,
      title: session['title']! as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        session['started_at']! as int,
      ),
      completedAt: session['completed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              session['completed_at']! as int,
            ),
      exercises: exerciseRows
          .map((exercise) {
            final entryId = exercise['id']! as String;
            return WorkoutExercise(
              id: entryId,
              exerciseId: exercise['exercise_id']! as String,
              name: exercise['exercise_name']! as String,
              position: exercise['position']! as int,
              weightUnit: exercise['weight_unit'] == 'lb'
                  ? WorkoutWeightUnit.pounds
                  : WorkoutWeightUnit.kilograms,
              restSeconds: exercise['rest_seconds']! as int,
              supersetId: exercise['superset_id'] as String?,
              notes: exercise['notes']! as String,
              sets: setRows
                  .where((set) => set['workout_exercise_id'] == entryId)
                  .map(_setFromRow)
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Future<ExerciseHistoryStats> getExerciseHistory(String exerciseId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(DISTINCT ws.id) AS session_count,
        COUNT(wset.id) AS completed_set_count,
        COALESCE(MAX(wset.load_kg), 0) AS best_load_kg,
        COALESCE(SUM(wset.load_kg * wset.repetitions), 0) AS total_volume_kg
      FROM workout_sessions ws
      INNER JOIN workout_exercises we ON we.session_id = ws.id
      INNER JOIN workout_sets wset ON wset.workout_exercise_id = we.id
      WHERE ws.completed_at IS NOT NULL
        AND we.exercise_id = ?
        AND wset.is_completed = 1
      ''',
      [exerciseId],
    );
    final row = rows.single;
    return ExerciseHistoryStats(
      sessionCount: (row['session_count'] as num?)?.toInt() ?? 0,
      completedSetCount: (row['completed_set_count'] as num?)?.toInt() ?? 0,
      bestLoadKg: (row['best_load_kg'] as num?)?.toDouble() ?? 0,
      totalVolumeKg: (row['total_volume_kg'] as num?)?.toDouble() ?? 0,
    );
  }

  WorkoutSet _setFromRow(Map<String, Object?> set) => WorkoutSet(
    id: set['id']! as String,
    exerciseId: set['exercise_id']! as String,
    position: set['position']! as int,
    repetitions: set['repetitions']! as int,
    loadKg: (set['load_kg']! as num).toDouble(),
    rpe: (set['rpe'] as num?)?.toDouble(),
    notes: set['notes']! as String,
    type: set['set_type'] == 'warmup'
        ? WorkoutSetType.warmup
        : WorkoutSetType.working,
    isCompleted: set['is_completed'] == 1,
    completedAt: set['completed_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(set['completed_at']! as int),
  );

  @override
  Future<void> save(WorkoutSession session) async {
    final db = await _database;
    await db.transaction((transaction) async {
      await transaction.insert('workout_sessions', {
        'id': session.id,
        'title': session.title,
        'started_at': session.startedAt.millisecondsSinceEpoch,
        'completed_at': session.completedAt?.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.delete(
        'workout_exercises',
        where: 'session_id = ?',
        whereArgs: [session.id],
      );
      for (final exercise in session.exercises) {
        await transaction.insert('workout_exercises', {
          'id': exercise.id,
          'session_id': session.id,
          'exercise_id': exercise.exerciseId,
          'exercise_name': exercise.name,
          'position': exercise.position,
          'weight_unit': exercise.weightUnit.label,
          'rest_seconds': exercise.restSeconds,
          'superset_id': exercise.supersetId,
          'notes': exercise.notes,
        });
        for (final set in exercise.sets) {
          await transaction.insert('workout_sets', {
            'id': set.id,
            'session_id': session.id,
            'workout_exercise_id': exercise.id,
            'exercise_id': exercise.exerciseId,
            'position': set.position,
            'set_type': set.type.name,
            'repetitions': set.repetitions,
            'load_kg': set.loadKg,
            'rpe': set.rpe,
            'notes': set.notes,
            'is_completed': set.isCompleted ? 1 : 0,
            'completed_at': set.completedAt?.millisecondsSinceEpoch,
          });
        }
      }
    });
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final db = await _database;
    await db.delete(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<List<WorkoutTemplate>> getTemplates() async {
    final db = await _database;
    final rows = await db.query(
      'workout_templates',
      where: 'is_archived = 0',
      orderBy: 'is_favorite DESC, updated_at DESC',
    );
    return rows
        .map(
          (row) => WorkoutTemplate(
            id: row['id']! as String,
            title: row['title']! as String,
            exercises: WorkoutTemplate.decodeExercises(
              row['exercises_json']! as String,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              row['updated_at']! as int,
            ),
            isFavorite: row['is_favorite'] == 1,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveTemplate(WorkoutTemplate template) async {
    final db = await _database;
    await db.insert('workout_templates', {
      'id': template.id,
      'title': template.title,
      'exercises_json': template.encodedExercises,
      'updated_at': template.updatedAt.millisecondsSinceEpoch,
      'is_archived': template.isArchived ? 1 : 0,
      'is_favorite': template.isFavorite ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    final db = await _database;
    await db.delete(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );
  }
}
