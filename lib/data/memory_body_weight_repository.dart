import '../domain/body_weight.dart';

/// In-memory body-weight history for the no-database fallback and for tests.
class MemoryBodyWeightRepository implements BodyWeightRepository {
  /// Keyed by day so a repeat weigh-in replaces rather than duplicates.
  final Map<DateTime, BodyWeightEntry> _entries = {};

  List<BodyWeightEntry> get _newestFirst {
    final entries = _entries.values.toList(growable: false)
      ..sort((a, b) => b.measuredOn.compareTo(a.measuredOn));
    return entries;
  }

  @override
  Future<List<BodyWeightEntry>> getEntries({int limit = 90}) async {
    final entries = _newestFirst;
    return entries.length <= limit ? entries : entries.sublist(0, limit);
  }

  @override
  Future<BodyWeightEntry?> getLatest() async {
    final entries = _newestFirst;
    return entries.isEmpty ? null : entries.first;
  }

  @override
  Future<BodyWeightEntry?> getEntryFor(DateTime date) async =>
      resolveWeightFor(_newestFirst, date);

  @override
  Future<void> save(BodyWeightEntry entry) async {
    _entries[entry.measuredOn] = entry;
  }

  @override
  Future<void> delete(DateTime measuredOn) async {
    _entries.remove(
      DateTime(measuredOn.year, measuredOn.month, measuredOn.day),
    );
  }

  @override
  Future<BodyWeightTrend> getTrend({int days = 90}) async {
    final now = DateTime.now();
    final since = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));

    final within = _newestFirst
        .where((entry) => !entry.measuredOn.isBefore(since))
        .toList(growable: false);

    if (within.isEmpty) {
      return const BodyWeightTrend(latest: null, earliest: null, entryCount: 0);
    }
    return BodyWeightTrend(
      latest: within.first,
      earliest: within.last,
      entryCount: within.length,
    );
  }
}
