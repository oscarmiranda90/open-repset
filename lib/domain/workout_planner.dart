import 'exercise.dart';
import 'session_plan.dart';

/// Turns a plain-language training request into a session plan.
///
/// The contract is deliberately two-stage. A catalogue holds thousands of
/// exercises, and sending it to a language model on every request would cost
/// more tokens than the request is worth and would grow without bound. Instead:
///
/// 1. [interpret] receives only the catalogue's vocabulary and answers with the
///    terms to search for.
/// 2. The app filters its local catalogue with that query.
/// 3. [select] receives the shortlisted candidates by id and name only, and
///    answers with the chosen ids, sets, and repetitions.
///
/// Both calls stay small and constant in size, and the model can only ever name
/// an exercise the app already offered it.
abstract interface class WorkoutPlanner {
  /// Whether a planning backend is configured for this build.
  ///
  /// Community builds ship without one, so the prompt surface stays hidden
  /// rather than failing when used.
  bool get isConfigured;

  Future<SessionPlanQuery> interpret({
    required String request,
    required CatalogueVocabulary vocabulary,
  });

  Future<SessionPlan> select({
    required String request,
    required SessionPlanQuery query,
    required List<Exercise> candidates,
  });
}

/// Supplies the caller's identity token for a planning request.
///
/// Returns null when nobody is signed in. The planner sends no token in that
/// case and the service answers with the sign-in prompt, which keeps identity
/// out of this layer entirely.
typedef PlannerTokenProvider = Future<String?> Function();

/// Raised when a plan cannot be produced. The message is safe to show.
class WorkoutPlannerException implements Exception {
  const WorkoutPlannerException(this.message);
  final String message;

  @override
  String toString() => message;
}
