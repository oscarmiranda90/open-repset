import 'package:flutter_test/flutter_test.dart';
import 'package:repset/data/http_workout_planner.dart';
import 'package:repset/domain/session_plan.dart';
import 'package:repset/domain/workout_planner.dart';

void main() {
  // The planning origin has no production default, matching the catalogue
  // boundary: a community build must not reach RepSet's private backend.
  test('a build without a planning origin reports itself unconfigured', () {
    expect(HttpWorkoutPlanner().isConfigured, isFalse);
  });

  test('an unconfigured planner refuses to call out rather than guessing', () {
    final planner = HttpWorkoutPlanner();

    expect(
      () => planner.interpret(
        request: 'legs',
        vocabulary: const CatalogueVocabulary(
          bodyParts: ['Lower body'],
          targets: ['Quads'],
          equipment: ['Barbell'],
        ),
      ),
      throwsA(isA<WorkoutPlannerException>()),
    );
  });
}
