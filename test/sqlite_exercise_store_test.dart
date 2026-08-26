import 'package:flutter_test/flutter_test.dart';
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/sqlite_exercise_store.dart';
import 'package:repset/domain/exercise.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'persists catalog metadata and favorites without downloading media',
    () async {
      final database = AppDatabase.open(path: inMemoryDatabasePath);
      final store = SqliteExerciseStore(database);
      const exercise = Exercise(
        id: 'squat',
        name: 'Back squat',
        bodyPart: 'Lower body',
        target: 'Quads',
        equipment: 'Barbell',
        secondaryMuscles: ['Glutes'],
        instructions: ['Brace', 'Descend', 'Stand'],
        mediaUrl: 'https://example.test/squat.gif',
      );

      await store.replaceRemote('en', const [exercise]);
      var saved = await store.read('en');
      expect(saved.single.mediaUrl, exercise.mediaUrl);
      expect(saved.single.isFavorite, isFalse);

      await store.setFavorite(exercise.id, isFavorite: true);
      saved = await store.read('en');
      expect(saved.single.isFavorite, isTrue);

      await (await database).close();
    },
  );

  test('keeps custom exercises when the remote catalogue refreshes', () async {
    final database = AppDatabase.open(path: inMemoryDatabasePath);
    final store = SqliteExerciseStore(database);
    const custom = Exercise(
      id: 'custom-press',
      name: 'Plate-loaded press',
      bodyPart: 'Custom',
      target: 'Chest',
      equipment: 'Plate-loaded machine',
      secondaryMuscles: [],
      instructions: [],
      isCustom: true,
    );
    const remote = Exercise(
      id: 'row',
      name: 'Cable row',
      bodyPart: 'Upper body',
      target: 'Back',
      equipment: 'Cable',
      secondaryMuscles: [],
      instructions: [],
    );

    await store.saveCustom('en', custom);
    await store.replaceRemote('en', const [remote]);

    final saved = await store.read('en');
    expect(
      saved.map((exercise) => exercise.id),
      containsAll(['custom-press', 'row']),
    );
    expect(
      saved.singleWhere((exercise) => exercise.id == custom.id).isCustom,
      isTrue,
    );

    await (await database).close();
  });
}
