import 'exercise.dart';
import 'session_plan.dart';

/// Narrows a catalogue down to the exercises a planning request can draw from.
///
/// This runs on device, between the planner's two calls. It is what keeps the
/// second prompt small: a catalogue of any size collapses to a few dozen
/// candidates before anything is sent over the network.
class CatalogueShortlist {
  const CatalogueShortlist._();

  /// How many candidates a request may offer the planner.
  ///
  /// Enough for a varied choice, small enough that the prompt stays cheap.
  static const maxCandidates = 40;

  /// Reads the closed vocabulary a catalogue describes itself with.
  static CatalogueVocabulary vocabularyOf(List<Exercise> catalogue) {
    final bodyParts = <String>{};
    final targets = <String>{};
    final equipment = <String>{};
    for (final exercise in catalogue) {
      if (exercise.bodyPart.isNotEmpty) bodyParts.add(exercise.bodyPart);
      if (exercise.target.isNotEmpty) targets.add(exercise.target);
      if (exercise.equipment.isNotEmpty) equipment.add(exercise.equipment);
      targets.addAll(exercise.secondaryMuscles.where((it) => it.isNotEmpty));
    }
    return CatalogueVocabulary(
      bodyParts: _sorted(bodyParts),
      targets: _sorted(targets),
      equipment: _sorted(equipment),
    );
  }

  /// Selects the candidates that match [query], best match first.
  ///
  /// Ranking matters more than filtering here. The planner sees a capped list,
  /// so the exercises most central to the request have to survive the cap:
  /// a primary-target match outranks a secondary-muscle one, and the emphasised
  /// muscle outranks the rest.
  static List<Exercise> candidatesFor(
    List<Exercise> catalogue, {
    required SessionPlanQuery query,
    int limit = maxCandidates,
  }) {
    if (query.isEmpty) return const [];
    final targets = _normalizedSet(query.targets);
    final bodyParts = _normalizedSet(query.bodyParts);
    final equipment = _normalizedSet(query.equipment);
    final emphasis = _normalize(query.emphasis ?? '');

    // Equipment asked for but absent from the catalogue cannot be honoured, and
    // treating it as a requirement would answer "nothing matches" to someone
    // whose muscles are covered several times over.
    final available = catalogue
        .map((exercise) => _normalize(exercise.equipment))
        .toSet();
    final usableEquipment = equipment.intersection(available);

    final scored = <_ScoredExercise>[];
    for (final exercise in catalogue) {
      if (usableEquipment.isNotEmpty &&
          !usableEquipment.contains(_normalize(exercise.equipment))) {
        continue;
      }
      final score = _scoreOf(
        exercise,
        targets: targets,
        bodyParts: bodyParts,
        emphasis: emphasis,
      );
      if (score > 0) scored.add(_ScoredExercise(exercise, score));
    }

    // A stable tie-break keeps the same request returning the same shortlist,
    // so a retry does not silently change what the planner was offered.
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.exercise.name.toLowerCase().compareTo(
        b.exercise.name.toLowerCase(),
      );
    });

    return scored
        .take(limit)
        .map((item) => item.exercise)
        .toList(growable: false);
  }

  static int _scoreOf(
    Exercise exercise, {
    required Set<String> targets,
    required Set<String> bodyParts,
    required String emphasis,
  }) {
    final target = _normalize(exercise.target);
    final secondary = _normalizedSet(exercise.secondaryMuscles);

    var score = 0;
    if (targets.contains(target)) score += 10;
    if (secondary.any(targets.contains)) score += 4;
    if (bodyParts.contains(_normalize(exercise.bodyPart))) score += 2;
    // Only lifts that already matched can be promoted; emphasis reorders the
    // shortlist, it does not widen it.
    if (score > 0 && emphasis.isNotEmpty) {
      if (target == emphasis) {
        score += 8;
      } else if (secondary.contains(emphasis)) {
        score += 3;
      }
    }
    if (score > 0 && exercise.isFavorite) score += 1;
    return score;
  }

  static List<String> _sorted(Set<String> values) =>
      values.toList(growable: false)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  static Set<String> _normalizedSet(Iterable<String> values) => values
      .map(_normalize)
      .where((value) => value.isNotEmpty)
      .toSet();

  static String _normalize(String value) => value.trim().toLowerCase();
}

class _ScoredExercise {
  const _ScoredExercise(this.exercise, this.score);
  final Exercise exercise;
  final int score;
}
