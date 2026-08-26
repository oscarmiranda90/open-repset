import 'package:flutter_test/flutter_test.dart';
import 'package:repset/domain/catalogue_shortlist.dart';
import 'package:repset/domain/exercise.dart';
import 'package:repset/domain/session_plan.dart';

Exercise _exercise({
  required String id,
  String? name,
  String bodyPart = 'Lower body',
  required String target,
  String equipment = 'Barbell',
  List<String> secondaryMuscles = const [],
  bool isFavorite = false,
}) => Exercise(
  id: id,
  name: name ?? id,
  bodyPart: bodyPart,
  target: target,
  equipment: equipment,
  secondaryMuscles: secondaryMuscles,
  instructions: const [],
  isFavorite: isFavorite,
);

void main() {
  group('vocabularyOf', () {
    test('collects the closed vocabulary, secondary muscles included', () {
      final vocabulary = CatalogueShortlist.vocabularyOf([
        _exercise(id: 'squat', target: 'Quads', secondaryMuscles: ['Glutes']),
        _exercise(
          id: 'bench',
          bodyPart: 'Upper body',
          target: 'Chest',
          equipment: 'Dumbbell',
        ),
      ]);

      expect(vocabulary.bodyParts, ['Lower body', 'Upper body']);
      expect(vocabulary.targets, ['Chest', 'Glutes', 'Quads']);
      expect(vocabulary.equipment, ['Barbell', 'Dumbbell']);
    });

    test('drops empty fields rather than offering blank terms', () {
      final vocabulary = CatalogueShortlist.vocabularyOf([
        _exercise(id: 'plank', bodyPart: '', target: 'Abs', equipment: ''),
      ]);

      expect(vocabulary.bodyParts, isEmpty);
      expect(vocabulary.equipment, isEmpty);
      expect(vocabulary.targets, ['Abs']);
    });
  });

  group('candidatesFor', () {
    final catalogue = [
      _exercise(id: 'leg-extension', target: 'Quads', equipment: 'Machine'),
      _exercise(id: 'back-squat', target: 'Quads'),
      _exercise(
        id: 'romanian-deadlift',
        target: 'Hamstrings',
        secondaryMuscles: ['Glutes'],
      ),
      _exercise(
        id: 'hip-thrust',
        target: 'Glutes',
        secondaryMuscles: ['Quads'],
      ),
      _exercise(id: 'bench-press', bodyPart: 'Upper body', target: 'Chest'),
    ];

    test('keeps only exercises the query names', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(targets: ['Quads']),
      );

      expect(
        candidates.map((exercise) => exercise.id),
        containsAll(['back-squat', 'leg-extension', 'hip-thrust']),
      );
      expect(
        candidates.map((exercise) => exercise.id),
        isNot(contains('bench-press')),
      );
    });

    test('ranks the emphasised muscle above the rest of the request', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(
          targets: ['Quads', 'Hamstrings', 'Glutes'],
          emphasis: 'Quads',
        ),
      );

      final quadIndex = candidates.indexWhere((it) => it.id == 'back-squat');
      final hamstringIndex = candidates.indexWhere(
        (it) => it.id == 'romanian-deadlift',
      );
      expect(quadIndex, lessThan(hamstringIndex));
    });

    test('ranks a primary target above a secondary-muscle match', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(targets: ['Quads']),
      );

      expect(
        candidates.indexWhere((it) => it.id == 'back-squat'),
        lessThan(candidates.indexWhere((it) => it.id == 'hip-thrust')),
      );
    });

    test('emphasis reorders the shortlist without widening it', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(targets: ['Quads'], emphasis: 'Chest'),
      );

      expect(
        candidates.map((exercise) => exercise.id),
        isNot(contains('bench-press')),
      );
    });

    test('filters by equipment when the request constrains it', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(
          targets: ['Quads'],
          equipment: ['Machine'],
        ),
      );

      expect(candidates.map((exercise) => exercise.id), ['leg-extension']);
    });

    test('matches vocabulary regardless of casing', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(targets: ['quads']),
      );

      expect(candidates, isNotEmpty);
    });

    test('caps the shortlist so the planner prompt stays bounded', () {
      final large = List.generate(
        200,
        (index) => _exercise(id: 'lift-$index', target: 'Quads'),
        growable: false,
      );

      final candidates = CatalogueShortlist.candidatesFor(
        large,
        query: const SessionPlanQuery(targets: ['Quads']),
      );

      expect(candidates, hasLength(CatalogueShortlist.maxCandidates));
    });

    test('returns the same shortlist for a repeated request', () {
      const query = SessionPlanQuery(targets: ['Quads'], emphasis: 'Quads');
      final first = CatalogueShortlist.candidatesFor(catalogue, query: query);
      final second = CatalogueShortlist.candidatesFor(catalogue, query: query);

      expect(
        first.map((exercise) => exercise.id),
        second.map((exercise) => exercise.id),
      );
    });

    test('an empty query selects nothing', () {
      expect(
        CatalogueShortlist.candidatesFor(
          catalogue,
          query: const SessionPlanQuery(targets: []),
        ),
        isEmpty,
      );
    });
    test('equipment the catalogue lacks does not empty the shortlist', () {
      // Asking for calisthenics in a barbell-and-machine library still returns
      // leg work: the muscles are what the request was really about.
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(
          targets: ['Quads'],
          equipment: ['Calisthenics'],
        ),
      );

      expect(candidates, isNotEmpty);
    });

    test('a mix of present and absent equipment keeps the present one', () {
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(
          targets: ['Quads'],
          equipment: ['Calisthenics', 'Machine'],
        ),
      );

      expect(candidates.map((exercise) => exercise.id), ['leg-extension']);
    });
    test('naming every equipment type constrains nothing', () {
      // A model that lists the whole vocabulary is not expressing a
      // preference, and treating it as one would narrow the shortlist to the
      // first type alphabetically.
      final candidates = CatalogueShortlist.candidatesFor(
        catalogue,
        query: const SessionPlanQuery(
          targets: ['Quads'],
          equipment: ['Barbell', 'Machine'],
        ),
      );

      expect(candidates.length, greaterThan(1));
    });
  });
}
