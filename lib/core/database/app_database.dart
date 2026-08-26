import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static Future<Database> open({String? path}) async => openDatabase(
    path ?? join(await getDatabasesPath(), 'repset.db'),
    version: 9,
    onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
    onCreate: (database, _) async {
      await database.execute(
        'CREATE TABLE workout_sessions(id TEXT PRIMARY KEY, title TEXT NOT NULL, started_at INTEGER NOT NULL, completed_at INTEGER)',
      );
      await database.execute(
        'CREATE TABLE workout_exercises(id TEXT PRIMARY KEY, session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, exercise_name TEXT NOT NULL, position INTEGER NOT NULL, weight_unit TEXT NOT NULL DEFAULT \'kg\', rest_seconds INTEGER NOT NULL DEFAULT 120, superset_id TEXT, notes TEXT NOT NULL DEFAULT \'\', FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE)',
      );
      await database.execute(
        'CREATE TABLE workout_sets(id TEXT PRIMARY KEY, session_id TEXT NOT NULL, workout_exercise_id TEXT NOT NULL, exercise_id TEXT NOT NULL, position INTEGER NOT NULL, set_type TEXT NOT NULL DEFAULT \'working\', repetitions INTEGER NOT NULL DEFAULT 0, load_kg REAL NOT NULL DEFAULT 0, rpe REAL, notes TEXT NOT NULL DEFAULT \'\', is_completed INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE, FOREIGN KEY(workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE)',
      );
      await database.execute(
        'CREATE TABLE exercises(id TEXT NOT NULL, language_code TEXT NOT NULL, name TEXT NOT NULL, body_part TEXT NOT NULL, target TEXT NOT NULL, equipment TEXT NOT NULL, secondary_muscles TEXT NOT NULL, instructions TEXT NOT NULL, media_url TEXT, is_custom INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL, PRIMARY KEY(id, language_code))',
      );
      await database.execute(
        'CREATE TABLE favorite_exercises(exercise_id TEXT PRIMARY KEY, created_at INTEGER NOT NULL)',
      );
      await database.execute(
        'CREATE INDEX exercise_search_index ON exercises(language_code, name, target, equipment)',
      );
      await database.execute(
        'CREATE TABLE workout_templates(id TEXT PRIMARY KEY, title TEXT NOT NULL, exercises_json TEXT NOT NULL, updated_at INTEGER NOT NULL, is_archived INTEGER NOT NULL DEFAULT 0, is_favorite INTEGER NOT NULL DEFAULT 0)',
      );
      await database.execute(_createBodyWeightEntries);
      await database.execute(_createAppPreferences);
    },
    onUpgrade: (database, oldVersion, _) async {
      if (oldVersion < 2) {
        await database.execute(
          'ALTER TABLE workout_sets RENAME TO workout_sets_v1',
        );
        await database.execute(
          'CREATE TABLE workout_exercises(id TEXT PRIMARY KEY, session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, exercise_name TEXT NOT NULL, position INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT \'\', FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE)',
        );
        await database.execute(
          'CREATE TABLE workout_sets(id TEXT PRIMARY KEY, session_id TEXT NOT NULL, workout_exercise_id TEXT NOT NULL, exercise_id TEXT NOT NULL, position INTEGER NOT NULL, set_type TEXT NOT NULL DEFAULT \'working\', repetitions INTEGER NOT NULL DEFAULT 0, load_kg REAL NOT NULL DEFAULT 0, rpe REAL, notes TEXT NOT NULL DEFAULT \'\', is_completed INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, FOREIGN KEY(session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE, FOREIGN KEY(workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE)',
        );
        await database.execute(
          "INSERT INTO workout_exercises(id, session_id, exercise_id, exercise_name, position) SELECT session_id || ':' || exercise_id, session_id, exercise_id, exercise_id, MIN(id) FROM workout_sets_v1 GROUP BY session_id, exercise_id",
        );
        await database.execute(
          "INSERT INTO workout_sets(id, session_id, workout_exercise_id, exercise_id, position, set_type, repetitions, load_kg, is_completed, completed_at) SELECT 'legacy-' || id, session_id, session_id || ':' || exercise_id, exercise_id, id, 'working', repetitions, load_kg, 1, completed_at FROM workout_sets_v1",
        );
        await database.execute('DROP TABLE workout_sets_v1');
      }
      if (oldVersion < 3) {
        await database.execute(
          "ALTER TABLE workout_exercises ADD COLUMN weight_unit TEXT NOT NULL DEFAULT 'kg'",
        );
      }
      if (oldVersion < 4) {
        await database.execute(
          'ALTER TABLE workout_exercises ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 120',
        );
      }
      if (oldVersion < 5) {
        await database.execute(
          'ALTER TABLE workout_exercises ADD COLUMN superset_id TEXT',
        );
      }
      if (oldVersion < 6) {
        await database.execute(
          'CREATE TABLE workout_templates(id TEXT PRIMARY KEY, title TEXT NOT NULL, exercises_json TEXT NOT NULL, updated_at INTEGER NOT NULL, is_archived INTEGER NOT NULL DEFAULT 0)',
        );
      }
      if (oldVersion < 7) {
        await database.execute(
          'ALTER TABLE workout_templates ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (oldVersion < 8) {
        await database.execute(_createBodyWeightEntries);
      }
      if (oldVersion < 9) {
        await database.execute(_createAppPreferences);
      }
    },
  );
}

/// Small, durable app state that is neither training data nor a user profile:
/// whether onboarding has run, which path the person chose, and anything else
/// of that shape. A key-value table keeps such flags from each becoming a
/// schema migration of their own.
const _createAppPreferences =
    'CREATE TABLE app_preferences(key TEXT PRIMARY KEY, value TEXT NOT NULL)';

/// Body weight is a time series, not a profile field.
///
/// A single "current weight" would rewrite history: a bench press logged when
/// the athlete weighed 75 kg has to keep comparing against 75, not against
/// whatever the scale says today.
///
/// `measured_on` is the local date at midnight and is the primary key, so
/// stepping on the scale three times in one day leaves one point on the curve
/// rather than three.
const _createBodyWeightEntries =
    'CREATE TABLE body_weight_entries('
    'measured_on INTEGER PRIMARY KEY, '
    'weight_kg REAL NOT NULL, '
    'notes TEXT NOT NULL DEFAULT \'\', '
    'updated_at INTEGER NOT NULL)';
