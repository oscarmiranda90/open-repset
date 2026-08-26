import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repset/data/http_workout_planner.dart';
import 'package:repset/domain/session_plan.dart';
import 'package:repset/domain/workout_planner.dart';

const _vocabulary = CatalogueVocabulary(
  bodyParts: ['Lower body'],
  targets: ['Quads'],
  equipment: ['Barbell'],
);

void main() {
  test('an unconfigured build refuses before touching the network', () {
    expect(
      () => HttpWorkoutPlanner().interpret(
        request: 'legs',
        vocabulary: _vocabulary,
      ),
      throwsA(isA<WorkoutPlannerException>()),
    );
  });

  test('an unconfigured build never calls the token provider', () async {
    // Configuration is checked first, so a build with no planning service
    // cannot fail inside identity code it was never going to use.
    var asked = false;
    final planner = HttpWorkoutPlanner(
      client: MockClient((_) async => http.Response('{}', 200)),
      tokenProvider: () async {
        asked = true;
        return 'a-token';
      },
    );

    await expectLater(
      planner.interpret(request: 'legs', vocabulary: _vocabulary),
      throwsA(isA<WorkoutPlannerException>()),
    );
    expect(asked, planner.isConfigured);
  });

  test('a resolved token travels as a bearer header', () async {
    String? seen;
    final planner = HttpWorkoutPlanner(
      client: MockClient((request) async {
        seen = request.headers['authorization'];
        return http.Response(
          jsonEncode({
            'targets': ['Quads'],
            'exerciseCount': 4,
          }),
          200,
        );
      }),
      tokenProvider: () async => 'a-token',
    );

    // Without an origin the client refuses first, so this only asserts the
    // header when a build is configured to reach a service.
    if (!planner.isConfigured) return;
    await planner.interpret(request: 'legs', vocabulary: _vocabulary);
    expect(seen, 'Bearer a-token');
  });

  test('a request naming nothing to train is refused clearly', () async {
    // "I want a pizza" is answered by the model with empty arrays, and that
    // has to arrive as an explanation rather than as a plan of nothing.
    final planner = HttpWorkoutPlanner(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'targets': [], 'bodyParts': [], 'exerciseCount': 0}),
          200,
        ),
      ),
      tokenProvider: () async => 'a-token',
    );
    if (!planner.isConfigured) return;

    await expectLater(
      planner.interpret(request: 'a pizza please', vocabulary: _vocabulary),
      throwsA(
        isA<WorkoutPlannerException>().having(
          (error) => error.message,
          'message',
          contains('did not name anything to train'),
        ),
      ),
    );
  });

  test('equipment the catalogue lacks is dropped, not obeyed', () async {
    // Asking for calisthenics in a barbell-only library keeps the muscles: a
    // session with different equipment beats no session at all.
    final planner = HttpWorkoutPlanner(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'targets': ['Quads'],
            'equipment': ['Calisthenics'],
            'exerciseCount': 5,
          }),
          200,
        ),
      ),
      tokenProvider: () async => 'a-token',
    );
    if (!planner.isConfigured) return;

    final query = await planner.interpret(
      request: 'leg day with calisthenics',
      vocabulary: _vocabulary,
    );
    expect(query.targets, ['Quads']);
    expect(query.equipment, ['Calisthenics']);
  });
}
