import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repset/domain/muscle_map.dart';
import 'package:repset/features/you/body_map_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(BodyMapLoader.resetForTesting);

  test('parses the shipped body illustration', () async {
    final paths = await BodyMapLoader.load(bundle: rootBundle);

    expect(paths.viewBox.width, greaterThan(0));
    expect(paths.viewBox.height, greaterThan(0));
    expect(paths.silhouette, isNotEmpty);
  });

  test('resolves every muscle group to real geometry', () async {
    final paths = await BodyMapLoader.load(bundle: rootBundle);

    // A group whose svgIds no longer match the asset would never shade, and
    // nothing at runtime would report it — so the contract is asserted here.
    for (final group in MuscleGroup.values) {
      final path = paths.muscles[group];
      expect(path, isNotNull, reason: '${group.label} has no path');
      expect(
        path!.getBounds().isEmpty,
        isFalse,
        reason: '${group.label} parsed to an empty shape',
      );
    }
  });

  test('keeps muscles inside the declared view box', () async {
    final paths = await BodyMapLoader.load(bundle: rootBundle);
    final viewBox = paths.viewBox.inflate(1);

    for (final entry in paths.muscles.entries) {
      final bounds = entry.value.getBounds();
      // Geometry outside the view box means the parser mis-read a command and
      // the muscle would render off-figure.
      expect(
        viewBox.contains(bounds.topLeft) && viewBox.contains(bounds.bottomRight),
        isTrue,
        reason: '${entry.key.label} falls outside the view box: $bounds',
      );
    }
  });

  test('covers both views of the figure', () async {
    final paths = await BodyMapLoader.load(bundle: rootBundle);
    final midline = paths.viewBox.center.dx;

    // The asset places the rear view left of centre and the front view right of
    // it. A group that only ever parsed on one side means the other view is
    // missing from the map.
    final leftGroups = paths.muscles.entries
        .where((entry) => entry.value.getBounds().center.dx < midline)
        .map((entry) => entry.key)
        .toSet();
    final rightGroups = paths.muscles.entries
        .where((entry) => entry.value.getBounds().center.dx >= midline)
        .map((entry) => entry.key)
        .toSet();

    expect(leftGroups, isNotEmpty, reason: 'rear view produced no muscles');
    expect(rightGroups, isNotEmpty, reason: 'front view produced no muscles');
  });

  test('gives the back real area, not just the traps', () async {
    final paths = await BodyMapLoader.load(bundle: rootBundle);
    final back = paths.muscles[MuscleGroup.back]!.getBounds();
    final chest = paths.muscles[MuscleGroup.chest]!.getBounds();

    // Treating the SVG's `back` group as a container once hid every lat path,
    // leaving only the traps — a sliver next to the chest.
    expect(
      back.height,
      greaterThan(chest.height * .5),
      reason: 'back collapsed to $back against a chest of $chest',
    );
  });

  test('keeps the head visible as part of the silhouette', () async {
    final paths = await BodyMapLoader.load(bundle: rootBundle);
    final bodyTop = paths.muscles.values
        .map((path) => path.getBounds().top)
        .reduce((a, b) => a < b ? a : b);
    final silhouetteTop = paths.silhouette
        .map((path) => path.getBounds().top)
        .reduce((a, b) => a < b ? a : b);

    // The head sits above every muscle, so a silhouette that starts no higher
    // than the muscles means it was dropped.
    expect(silhouetteTop, lessThan(bodyTop));
  });

  test('caches the parse across calls', () async {
    final first = await BodyMapLoader.load(bundle: rootBundle);
    final second = await BodyMapLoader.load(bundle: rootBundle);

    // Re-parsing 49 KB of path data on every visit would cost a frame each time.
    expect(identical(first, second), isTrue);
  });
}
