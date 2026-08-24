import 'package:sqflite/sqflite.dart';

import '../domain/body_weight.dart';

class SqliteBodyWeightRepository implements BodyWeightRepository {
  const SqliteBodyWeightRepository(this._database);

  final Future<Database> _database;

  static const _table = 'body_weight_entries';

  @override
  Future<List<BodyWeightEntry>> getEntries({int limit = 90}) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      orderBy: 'measured_on DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<BodyWeightEntry?> getLatest() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'measured_on DESC', limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<BodyWeightEntry?> getEntryFor(DateTime date) async {
    final db = await _database;
    final day = DateTime(date.year, date.month, date.day);
    // The most recent weigh-in at or before the day. Nothing is carried
    // backwards from a later measurement — that would invent the ratio.
    final rows = await db.query(
      _table,
      where: 'measured_on <= ?',
      whereArgs: [day.millisecondsSinceEpoch],
      orderBy: 'measured_on DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<void> save(BodyWeightEntry entry) async {
    final db = await _database;
    // measured_on is the primary key, so a second weigh-in the same day
    // replaces the first instead of adding a duplicate point.
    await db.insert(_table, {
      'measured_on': entry.measuredOn.millisecondsSinceEpoch,
      'weight_kg': entry.weightKg,
      'notes': entry.notes,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(DateTime measuredOn) async {
    final db = await _database;
    final day = DateTime(measuredOn.year, measuredOn.month, measuredOn.day);
    await db.delete(
      _table,
      where: 'measured_on = ?',
      whereArgs: [day.millisecondsSinceEpoch],
    );
  }

  @override
  Future<BodyWeightTrend> getTrend({int days = 90}) async {
    final db = await _database;
    final now = DateTime.now();
    final since = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    final rows = await db.query(
      _table,
      where: 'measured_on >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
      orderBy: 'measured_on DESC',
    );

    if (rows.isEmpty) {
      return const BodyWeightTrend(latest: null, earliest: null, entryCount: 0);
    }
    return BodyWeightTrend(
      latest: _fromRow(rows.first),
      earliest: _fromRow(rows.last),
      entryCount: rows.length,
    );
  }

  BodyWeightEntry _fromRow(Map<String, Object?> row) => BodyWeightEntry(
    measuredOn: DateTime.fromMillisecondsSinceEpoch(
      (row['measured_on']! as num).toInt(),
    ),
    weightKg: (row['weight_kg']! as num).toDouble(),
    notes: (row['notes'] as String?) ?? '',
  );
}
