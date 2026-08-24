import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:repset/core/database/app_database.dart';
import 'package:repset/data/memory_body_weight_repository.dart';
import 'package:repset/data/sqlite_body_weight_repository.dart';
import 'package:repset/domain/body_weight.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  var counter = 0;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('repset-bodyweight');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  String newPath() => path.join(root.path, 'weight-${counter++}.db');

  SqliteBodyWeightRepository newRepository() =>
      SqliteBodyWeightRepository(AppDatabase.open(path: newPath()));

  group('storage', () {
    test(
      'normalises entries to the day and replaces a repeat weigh-in',
      () async {
        final repository = newRepository();
        final morning = DateTime(2026, 8, 24, 7, 30);
        final evening = DateTime(2026, 8, 24, 21, 15);

        await repository.save(
          BodyWeightEntry(measuredOn: morning, weightKg: 80.4),
        );
        await repository.save(
          BodyWeightEntry(measuredOn: evening, weightKg: 81.1),
        );

        final entries = await repository.getEntries();
        // Stepping on the scale twice in a day is one point on the curve.
        expect(entries, hasLength(1));
        expect(entries.single.weightKg, 81.1);
        expect(entries.single.measuredOn, DateTime(2026, 8, 24));
      },
    );

    test('returns entries newest first and finds the latest', () async {
      final repository = newRepository();
      for (final day in [20, 24, 22]) {
        await repository.save(
          BodyWeightEntry(
            measuredOn: DateTime(2026, 8, day),
            weightKg: 80 + day / 10,
          ),
        );
      }

      final entries = await repository.getEntries();
      expect(entries.map((entry) => entry.measuredOn.day).toList(), [
        24,
        22,
        20,
      ]);
      expect((await repository.getLatest())!.measuredOn.day, 24);
    });

    test('deletes a single day without touching the rest', () async {
      final repository = newRepository();
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 20), weightKg: 80),
      );
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 21), weightKg: 81),
      );

      await repository.delete(DateTime(2026, 8, 20, 18));

      final entries = await repository.getEntries();
      expect(entries, hasLength(1));
      expect(entries.single.measuredOn.day, 21);
    });

    test('upgrades an existing v7 database without losing data', () async {
      final databasePath = newPath();
      // Build the schema as it stood before body weight existed.
      final legacy = await openDatabase(
        databasePath,
        version: 7,
        onCreate: (database, _) async {
          await database.execute(
            'CREATE TABLE workout_sessions(id TEXT PRIMARY KEY, title TEXT NOT NULL, started_at INTEGER NOT NULL, completed_at INTEGER)',
          );
        },
      );
      await legacy.insert('workout_sessions', {
        'id': 'legacy-session',
        'title': 'Old session',
        'started_at': DateTime(2026, 8, 1).millisecondsSinceEpoch,
        'completed_at': DateTime(2026, 8, 1, 1).millisecondsSinceEpoch,
      });
      await legacy.close();

      final upgraded = AppDatabase.open(path: databasePath);
      final repository = SqliteBodyWeightRepository(upgraded);
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 24), weightKg: 78),
      );

      expect((await repository.getLatest())!.weightKg, 78);
      // The pre-existing row has to survive the migration.
      final sessions = await (await upgraded).query('workout_sessions');
      expect(sessions, hasLength(1));
      expect(sessions.single['id'], 'legacy-session');
    });
  });

  group('weight in effect on a date', () {
    test('uses the most recent weigh-in at or before the day', () async {
      final repository = newRepository();
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 75),
      );
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 15), weightKg: 78),
      );

      expect(
        (await repository.getEntryFor(DateTime(2026, 8, 10)))!.weightKg,
        75,
      );
      // On the day of a weigh-in, that weigh-in applies.
      expect(
        (await repository.getEntryFor(DateTime(2026, 8, 15)))!.weightKg,
        78,
      );
      expect(
        (await repository.getEntryFor(DateTime(2026, 8, 20)))!.weightKg,
        78,
      );
    });

    test('returns nothing before the first weigh-in', () async {
      final repository = newRepository();
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 15), weightKg: 78),
      );

      // Carrying a later weight backwards would invent the number.
      expect(await repository.getEntryFor(DateTime(2026, 8, 1)), isNull);
    });

    test('memory and SQLite resolve the same day identically', () async {
      final sqlite = newRepository();
      final memory = MemoryBodyWeightRepository();
      for (final entry in [
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 75),
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 15), weightKg: 78),
      ]) {
        await sqlite.save(entry);
        await memory.save(entry);
      }

      for (final day in [
        DateTime(2026, 7, 30),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 20),
      ]) {
        final fromSqlite = await sqlite.getEntryFor(day);
        final fromMemory = await memory.getEntryFor(day);
        expect(fromSqlite?.weightKg, fromMemory?.weightKg, reason: '$day');
      }
    });
  });

  group('trend', () {
    test('reports no history when nothing has been logged', () async {
      final trend = await newRepository().getTrend();
      expect(trend.hasHistory, isFalse);
      expect(trend.canCompare, isFalse);
      expect(trend.changeKg, 0);
    });

    test('withholds a comparison from a single weigh-in', () async {
      final repository = newRepository();
      await repository.save(
        BodyWeightEntry(measuredOn: DateTime.now(), weightKg: 80),
      );

      final trend = await repository.getTrend();
      expect(trend.hasHistory, isTrue);
      // One point is a reading, not a direction.
      expect(trend.canCompare, isFalse);
    });

    test('measures the change across the window', () async {
      final repository = newRepository();
      final today = DateTime.now();
      await repository.save(
        BodyWeightEntry(
          measuredOn: today.subtract(const Duration(days: 30)),
          weightKg: 80,
        ),
      );
      await repository.save(BodyWeightEntry(measuredOn: today, weightKg: 76));

      final trend = await repository.getTrend();
      expect(trend.canCompare, isTrue);
      expect(trend.changeKg, -4);
      expect(trend.changeFraction, closeTo(-.05, 1e-9));
      expect(trend.spanDays, 30);
      expect(trend.entryCount, 2);
    });

    test('ignores weigh-ins outside the requested window', () async {
      final repository = newRepository();
      final today = DateTime.now();
      await repository.save(
        BodyWeightEntry(
          measuredOn: today.subtract(const Duration(days: 200)),
          weightKg: 95,
        ),
      );
      await repository.save(BodyWeightEntry(measuredOn: today, weightKg: 80));

      final trend = await repository.getTrend(days: 30);
      expect(trend.entryCount, 1);
      expect(trend.canCompare, isFalse);
    });
  });

  group('relative strength', () {
    test('pairs each lift with the weight carried that day', () {
      final weights = [
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 20), weightKg: 90),
        BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 75),
      ];

      final best = bestRelativeStrength(
        exerciseId: 'bench',
        exerciseName: 'Bench press',
        points: [
          // 120 / 75 = 1.6 at the lighter body weight.
          (date: DateTime(2026, 8, 10), estimatedOneRepMaxKg: 120),
          // 135 / 90 = 1.5 — heavier absolute lift, weaker ratio.
          (date: DateTime(2026, 8, 25), estimatedOneRepMaxKg: 135),
        ],
        weightsNewestFirst: weights,
      );

      expect(best, isNotNull);
      expect(best!.ratio, closeTo(1.6, 1e-9));
      expect(best.bodyWeightKg, 75);
      expect(best.achievedOn, DateTime(2026, 8, 10));
    });

    test('skips sessions logged before the first weigh-in', () {
      final best = bestRelativeStrength(
        exerciseId: 'squat',
        exerciseName: 'Back squat',
        points: [
          (date: DateTime(2026, 7, 1), estimatedOneRepMaxKg: 200),
          (date: DateTime(2026, 8, 10), estimatedOneRepMaxKg: 100),
        ],
        weightsNewestFirst: [
          BodyWeightEntry(measuredOn: DateTime(2026, 8, 1), weightKg: 80),
        ],
      );

      // The July lift has no body weight behind it, so it cannot win.
      expect(best!.achievedOn, DateTime(2026, 8, 10));
      expect(best.ratio, closeTo(1.25, 1e-9));
    });

    test('returns nothing when no lift has a body weight behind it', () {
      final best = bestRelativeStrength(
        exerciseId: 'row',
        exerciseName: 'Barbell row',
        points: [(date: DateTime(2026, 7, 1), estimatedOneRepMaxKg: 100)],
        weightsNewestFirst: const [],
      );

      expect(best, isNull);
    });
  });

  test('rejects an implausible body weight', () {
    expect(
      () => BodyWeightEntry(measuredOn: DateTime.now(), weightKg: 0),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => BodyWeightEntry(measuredOn: DateTime.now(), weightKg: 900),
      throwsA(isA<AssertionError>()),
    );
  });
}
