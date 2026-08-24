import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../../core/svg/svg_path_parser.dart';
import '../../domain/muscle_map.dart';

/// Parsed geometry of the body illustration.
class BodyMapPaths {
  const BodyMapPaths({
    required this.muscles,
    required this.silhouette,
    required this.viewBox,
  });

  /// One combined path per muscle group present in the asset.
  final Map<MuscleGroup, Path> muscles;

  /// The unshaded body outline drawn underneath the muscles.
  final List<Path> silhouette;

  /// The asset's coordinate space, used to fit it to any widget size.
  final Rect viewBox;
}

/// Loads and parses `assets/images/bodymale.svg`.
///
/// The parse is cached for the process: the asset is ~49 KB of path data and
/// re-parsing it on every visit to You would cost a visible frame each time.
class BodyMapLoader {
  BodyMapLoader._();

  static Future<BodyMapPaths>? _pending;

  /// Groups drawn as the base body rather than as trainable muscle.
  static const _silhouetteIds = {
    'body_background',
    'back_body_background',
    'hands',
    'back_feets',
    'hair',
    'hair_back',
  };

  /// Containers that merely wrap other groups; shading them would flood the
  /// whole figure.
  static const _containerIds = {'bodysvg', 'full_bodies', 'back'};

  static Future<BodyMapPaths> load({AssetBundle? bundle}) =>
      _pending ??= _parse(bundle ?? rootBundle);

  /// Drops the cache so a test can parse against a different bundle.
  static void resetForTesting() => _pending = null;

  static Future<BodyMapPaths> _parse(AssetBundle bundle) async {
    final source = await bundle.loadString('assets/images/bodymale.svg');
    final document = XmlDocument.parse(source);

    final root = document.findAllElements('svg').first;
    final viewBox = _parseViewBox(root.getAttribute('viewBox'));

    // Ids are resolved once into the group that owns them, so the document is
    // walked a single time.
    final idToGroup = <String, MuscleGroup>{
      for (final group in MuscleGroup.values)
        for (final id in group.svgIds) id: group,
    };

    final muscles = <MuscleGroup, Path>{};
    final silhouette = <Path>[];

    for (final element in document.findAllElements('g')) {
      final id = element.getAttribute('id');
      if (id == null || _containerIds.contains(id)) continue;

      final group = idToGroup[id];
      final isSilhouette = _silhouetteIds.contains(id);
      if (group == null && !isSilhouette) continue;

      final combined = Path();
      // `findElements` stays at the direct children so a nested group is not
      // counted twice — once on its own and once inside its parent.
      for (final pathElement in element.findAllElements('path')) {
        final data = pathElement.getAttribute('d');
        if (data == null || data.isEmpty) continue;
        combined.addPath(parseSvgPath(data), Offset.zero);
      }

      if (isSilhouette) {
        silhouette.add(combined);
      } else {
        final existing = muscles[group!];
        if (existing == null) {
          muscles[group] = combined;
        } else {
          // A group spanning front and back views arrives as two elements.
          existing.addPath(combined, Offset.zero);
        }
      }
    }

    return BodyMapPaths(
      muscles: muscles,
      silhouette: silhouette,
      viewBox: viewBox,
    );
  }

  static Rect _parseViewBox(String? value) {
    if (value == null) return const Rect.fromLTWH(0, 0, 2667, 2667);
    final parts = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList(growable: false);
    if (parts.length != 4) return const Rect.fromLTWH(0, 0, 2667, 2667);
    return Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
  }
}
