import 'package:flutter_test/flutter_test.dart';
import 'package:repset/domain/exercise.dart';
import 'package:repset/domain/session_plan.dart';
import 'package:repset/domain/workout_planner.dart';
import 'package:repset/features/home/session_planner_bloc.dart';

class _FakePlanner implements WorkoutPlanner {
  _FakePlanner({this.query, this.plan, this.error});

  final SessionPlanQuery? query;
  final SessionPlan? plan;
  final Object? error;

  List<Exercise>? receivedCandidates;
  CatalogueVocabulary? receivedVocabulary;

  @override
  bool get isConfigured => true;

  @override
  Future<SessionPlanQuery> interpret({
    required String request,
    required CatalogueVocabulary vocabulary,
  }) async {
    receivedVocabulary = vocabulary;
    if (error != null) throw error!;
    return query!;
  }

  @override
  Future<SessionPlan> select({
    required String request,
    required SessionPlanQuery query,
    required List<Exercise> candidates,
  }) async {
    receivedCandidates = candidates;
    if (error != null) throw error!;
    return plan!;
  }
}

const _catalogue = [
  Exercise(
    id: 'back-squat',
    name: 'Back squat',
    bodyPart: 'Lower body',
    target: 'Quads',
    equipment: 'Barbell',
    secondaryMuscles: ['Glutes'],
    instructions: [],
  ),
  Exercise(
    id: 'bench-press',
    name: 'Bench press',
    bodyPart: 'Upper body',
    target: 'Chest',
    equipment: 'Barbell',
    secondaryMuscles: [],
    instructions: [],
  ),
];

void main() {
  test('pairs a plan with the catalogue records it names', () async {
    final planner = _FakePlanner(
      query: const SessionPlanQuery(targets: ['Quads']),
      plan: const SessionPlan(
        title: 'Quad focus',
        entries: [
          PlannedExercise(
            exerciseId: 'back-squat',
            setCount: 4,
            repetitions: 8,
          ),
        ],
      ),
    );
    final bloc = SessionPlannerBloc(planner);

    bloc.add(
      const SessionPlanRequested(
        request: 'legs, mostly quads',
        catalogue: _catalogue,
      ),
    );
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<SessionPlannerState>(
          (state) =>
              state.stage == SessionPlanStage.ready &&
              state.planned.length == 1 &&
              state.planned.single.exercise.id == 'back-squat' &&
              state.planned.single.plan.setCount == 4,
        ),
      ),
    );
    await bloc.close();
  });

  test('offers the planner only the shortlisted candidates', () async {
    final planner = _FakePlanner(
      query: const SessionPlanQuery(targets: ['Quads']),
      plan: const SessionPlan(
        title: 'Quad focus',
        entries: [
          PlannedExercise(
            exerciseId: 'back-squat',
            setCount: 3,
            repetitions: 10,
          ),
        ],
      ),
    );
    final bloc = SessionPlannerBloc(planner);

    bloc.add(
      const SessionPlanRequested(request: 'quads', catalogue: _catalogue),
    );
    await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.ready,
    );

    expect(planner.receivedCandidates?.map((it) => it.id), ['back-squat']);
    // The vocabulary, not the records, is what the first call carries.
    expect(planner.receivedVocabulary?.targets, contains('Quads'));
    await bloc.close();
  });

  test('drops planned entries that no candidate backs', () async {
    final planner = _FakePlanner(
      query: const SessionPlanQuery(targets: ['Quads']),
      plan: const SessionPlan(
        title: 'Quad focus',
        entries: [
          PlannedExercise(
            exerciseId: 'back-squat',
            setCount: 3,
            repetitions: 10,
          ),
          PlannedExercise(
            exerciseId: 'invented-lift',
            setCount: 3,
            repetitions: 10,
          ),
        ],
      ),
    );
    final bloc = SessionPlannerBloc(planner);

    bloc.add(
      const SessionPlanRequested(request: 'quads', catalogue: _catalogue),
    );
    final state = await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.ready,
    );

    expect(state.planned.map((entry) => entry.exercise.id), ['back-squat']);
    await bloc.close();
  });

  test('reports a planner failure with its own message', () async {
    final bloc = SessionPlannerBloc(
      _FakePlanner(error: const WorkoutPlannerException('Too many requests.')),
    );

    bloc.add(
      const SessionPlanRequested(request: 'quads', catalogue: _catalogue),
    );
    final state = await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.failed,
    );

    expect(state.message, 'Too many requests.');
    await bloc.close();
  });

  test('fails plainly when nothing in the catalogue matches', () async {
    final bloc = SessionPlannerBloc(
      _FakePlanner(query: const SessionPlanQuery(targets: ['Calves'])),
    );

    bloc.add(
      const SessionPlanRequested(request: 'calves', catalogue: _catalogue),
    );
    final state = await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.failed,
    );

    expect(state.message, contains('Nothing in your library'));
    await bloc.close();
  });

  test('an unloaded catalogue never reaches the planner', () async {
    final bloc = SessionPlannerBloc(_FakePlanner());

    bloc.add(const SessionPlanRequested(request: 'quads', catalogue: []));
    final state = await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.failed,
    );

    expect(state.message, contains('has not loaded'));
    await bloc.close();
  });

  test('a request after a failure is not swallowed', () async {
    // The first attempt fails and leaves the bloc holding that outcome. A
    // second attempt has to run rather than be rejected as a duplicate.
    final planner = _FakePlanner(
      query: const SessionPlanQuery(targets: ['Calves']),
    );
    final bloc = SessionPlannerBloc(planner);

    bloc.add(
      const SessionPlanRequested(request: 'calves', catalogue: _catalogue),
    );
    await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.failed,
    );

    bloc.add(
      const SessionPlanRequested(request: 'quads', catalogue: _catalogue),
    );
    final second = await bloc.stream.firstWhere(
      (state) => state.stage == SessionPlanStage.interpreting,
    );

    expect(second.request, 'quads');
    await bloc.close();
  });
}
