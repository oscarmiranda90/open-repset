/// The result of turning a plain-language training request into a session.
///
/// A plan only ever references catalogue exercises by id. The planner picks
/// from a candidate list the app supplies, so a plan can never introduce an
/// exercise that is not already in the local catalogue.
class SessionPlan {
  const SessionPlan({required this.title, required this.entries});

  final String title;
  final List<PlannedExercise> entries;

  bool get isEmpty => entries.isEmpty;
}

class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    required this.setCount,
    required this.repetitions,
    this.notes = '',
  });

  final String exerciseId;
  final int setCount;
  final int repetitions;
  final String notes;
}

/// The filter a request maps onto before the catalogue is searched.
///
/// This is the first-stage output: the model reads the user's sentence and the
/// catalogue's vocabulary, then answers with the terms to search for. Keeping
/// the model on vocabulary rather than on records is what stops the prompt from
/// growing with the catalogue.
class SessionPlanQuery {
  const SessionPlanQuery({
    required this.targets,
    this.bodyParts = const [],
    this.equipment = const [],
    this.emphasis,
    this.exerciseCount = 5,
  });

  /// Muscles to draw from, matched against `Exercise.target` and
  /// `Exercise.secondaryMuscles`.
  final List<String> targets;

  final List<String> bodyParts;

  /// When empty, every equipment type is allowed.
  final List<String> equipment;

  /// A target from [targets] that should receive the most exercises.
  final String? emphasis;

  final int exerciseCount;

  bool get isEmpty => targets.isEmpty && bodyParts.isEmpty;
}

/// The closed vocabulary of a catalogue, derived from the catalogue itself.
///
/// Sent to the planner in place of the exercises. A catalogue of fifty
/// thousand records still describes itself with a few dozen terms, so this
/// stays small no matter how the catalogue grows.
class CatalogueVocabulary {
  const CatalogueVocabulary({
    required this.bodyParts,
    required this.targets,
    required this.equipment,
  });

  final List<String> bodyParts;
  final List<String> targets;
  final List<String> equipment;

  bool get isEmpty => targets.isEmpty && bodyParts.isEmpty;
}
