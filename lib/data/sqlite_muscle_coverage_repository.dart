import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/muscle_map.dart';

/// Volume per muscle group, read from completed training.
///
/// Secondary muscles count at a reduced weight: a bench press trains triceps,
/// but crediting them the full set would make every push day read as an arm
/// day and the map would stop being diagnostic.
class SqliteMuscleCoverageRepository implements MuscleCoverageRepository {
  const SqliteMuscleCoverageRepository(this._database);

  final Future<Database> _database;

  /// Share of a set's volume attributed to each secondary muscle.
  static const _secondaryWeight = .4;

  @override
  Future<MuscleCoverage> getCoverage({int days = 30}) async {
    final db = await _database;
    final now = DateTime.now();
    final since = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    // The exercises table is keyed by (id, language_code); collapsing it to one
    // row per id first stops a translated exercise from counting twice.
    final rows = await db.rawQuery(
      '''
      SELECT
        s.exercise_id AS exercise_id,
        COUNT(s.id) AS set_count,
        COALESCE(SUM(s.load_kg * s.repetitions), 0) AS volume_kg,
        e.target AS target,
        e.body_part AS body_part,
        e.secondary_muscles AS secondary_muscles
      FROM workout_sets s
      INNER JOIN workout_sessions ws ON ws.id = s.session_id
      LEFT JOIN (
        SELECT id, MIN(target) AS target, MIN(body_part) AS body_part,
               MIN(secondary_muscles) AS secondary_muscles
        FROM exercises GROUP BY id
      ) e ON e.id = s.exercise_id
      WHERE ws.completed_at IS NOT NULL
        AND s.is_completed = 1
        AND ws.completed_at >= ?
      GROUP BY s.exercise_id
      ''',
      [since.millisecondsSinceEpoch],
    );

    final volumes = <MuscleGroup, double>{};
    final setCounts = <MuscleGroup, int>{};
    var unmapped = 0.0;

    for (final row in rows) {
      final volume = (row['volume_kg'] as num?)?.toDouble() ?? 0;
      final setCount = (row['set_count'] as num?)?.toInt() ?? 0;
      if (volume <= 0) continue;

      // Target first, body part as the fallback: an exercise missing from the
      // catalogue still carries a name the mapping may recognise.
      final primary =
          resolveMuscleGroup(row['target'] as String?) ??
          resolveMuscleGroup(row['body_part'] as String?);

      if (primary == null) {
        unmapped += volume;
        continue;
      }

      volumes[primary] = (volumes[primary] ?? 0) + volume;
      setCounts[primary] = (setCounts[primary] ?? 0) + setCount;

      for (final group in _secondaryGroups(
        row['secondary_muscles'] as String?,
      )) {
        if (group == primary) continue;
        volumes[group] = (volumes[group] ?? 0) + volume * _secondaryWeight;
        // Sets are not fractional, so a secondary muscle reports the work
        // without inflating the set count it never fully owned.
        setCounts[group] ??= 0;
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

  /// The catalogue stores secondary muscles as a JSON array
  /// (`sqlite_exercise_store` writes them with `jsonEncode`).
  Iterable<MuscleGroup> _secondaryGroups(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map(resolveMuscleGroup)
          .whereType<MuscleGroup>()
          .toSet();
    } on FormatException {
      // Legacy rows may predate the JSON encoding; a delimited string is the
      // only other shape they took.
      return raw
          .split(RegExp(r'[,;|]'))
          .map(resolveMuscleGroup)
          .whereType<MuscleGroup>()
          .toSet();
    }
  }
}
