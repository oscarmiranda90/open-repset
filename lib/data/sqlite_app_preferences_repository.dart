import 'package:sqflite/sqflite.dart';

import '../domain/app_preferences.dart';

/// Stores small app flags in the same database as everything else, so they
/// share its lifetime: uninstalling the app clears them along with the
/// training data, and nothing outlives what the person deleted.
class SqliteAppPreferencesRepository implements AppPreferencesRepository {
  SqliteAppPreferencesRepository(this._database);

  static const _completeKey = 'onboarding_complete';
  static const _nameKey = 'onboarding_name';
  static const _pathKey = 'onboarding_path';

  final Future<Database> _database;

  @override
  Future<OnboardingRecord> readOnboarding() async {
    final database = await _database;
    final rows = await database.query(
      'app_preferences',
      where: 'key IN (?, ?, ?)',
      whereArgs: const [_completeKey, _nameKey, _pathKey],
    );
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return OnboardingRecord(
      name: values[_nameKey] ?? '',
      path: TrainerPath.parse(values[_pathKey]),
      isComplete: values[_completeKey] == 'true',
    );
  }

  @override
  Future<void> saveOnboarding(OnboardingRecord record) async {
    final database = await _database;
    final batch = database.batch();
    void put(String key, String value) => batch.insert(
      'app_preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    put(_completeKey, record.isComplete ? 'true' : 'false');
    put(_nameKey, record.name);
    if (record.path != null) put(_pathKey, record.path!.name);
    await batch.commit(noResult: true);
  }
}
