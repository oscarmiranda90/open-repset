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

  test('caches the parse across calls', () async {
    final first = await BodyMapLoader.load(bundle: rootBundle);
    final second = await BodyMapLoader.load(bundle: rootBundle);

    // Re-parsing 49 KB of path data on every visit would cost a frame each time.
    expect(identical(first, second), isTrue);
  });
}
