import 'package:flutter/material.dart';

import '../../domain/muscle_map.dart';
import 'body_map_paths.dart';

const _accent = Color(0xffd7ff4f);

/// Front and back body views shaded by how much each muscle was trained.
///
/// The scale runs from the surface colour to the brand lime rather than
/// green-to-red: a heat scale would imply that training a muscle hard is a
/// hazard, when the actionable signal is the opposite — the muscles left dark.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.coverage,
    this.selected,
    this.onSelected,
  });

  final MuscleCoverage coverage;
  final MuscleGroup? selected;
  final ValueChanged<MuscleGroup?>? onSelected;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  late final Future<BodyMapPaths> _paths = BodyMapLoader.load();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<BodyMapPaths>(
      future: _paths,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Reserves the figure's space so the surrounding layout does not jump
          // when the illustration resolves.
          return const AspectRatio(
            aspectRatio: 1,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final paths = snapshot.data!;
        // A lighter plate behind the figure: on the dark page the illustration's
        // own greys sat too close to the background for the body to read as a
        // shape at all.
        final plate = Color.lerp(scheme.surface, scheme.onSurface, .13)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AspectRatio(
              aspectRatio: paths.viewBox.width / paths.viewBox.height,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.onSelected == null
                      ? null
                      : (details) => _handleTap(details, paths, constraints),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BodyMapPainter(
                        paths: paths,
                        coverage: widget.coverage,
                        selected: widget.selected,
                        // The body itself sits clearly above its plate rather
                        // than dissolving into it.
                        silhouetteColor: Color.lerp(
                          plate,
                          scheme.onSurface,
                          .1,
                        )!,
                        restColor: Color.lerp(plate, scheme.onSurface, .3)!,
                        activeColor: _accent,
                        outlineColor: plate,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(
    TapUpDetails details,
    BodyMapPaths paths,
    BoxConstraints constraints,
  ) {
    final scale = constraints.maxWidth / paths.viewBox.width;
    if (scale <= 0) return;
    // The tap arrives in widget space; hit-testing happens in the SVG's own
    // coordinates, so it is mapped back rather than scaling every path.
    final local = Offset(
      details.localPosition.dx / scale + paths.viewBox.left,
      details.localPosition.dy / scale + paths.viewBox.top,
    );

    for (final entry in paths.muscles.entries) {
      if (entry.value.contains(local)) {
        final next = widget.selected == entry.key ? null : entry.key;
        widget.onSelected!(next);
        return;
      }
    }
    // Tapping the body outside a muscle clears the selection.
    widget.onSelected!(null);
  }
}

class _BodyMapPainter extends CustomPainter {
  const _BodyMapPainter({
    required this.paths,
    required this.coverage,
    required this.selected,
    required this.silhouetteColor,
    required this.restColor,
    required this.activeColor,
    required this.outlineColor,
  });

  final BodyMapPaths paths;
  final MuscleCoverage coverage;
  final MuscleGroup? selected;
  final Color silhouetteColor;
  final Color restColor;
  final Color activeColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || paths.viewBox.isEmpty) return;

    final scale = size.width / paths.viewBox.width;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-paths.viewBox.left, -paths.viewBox.top);

    final silhouettePaint = Paint()..color = silhouetteColor;
    for (final path in paths.silhouette) {
      canvas.drawPath(path, silhouettePaint);
    }

    // Separator strokes scale with the figure so they stay hairline-thin at any
    // widget size instead of thickening as the map grows.
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / scale
      ..color = outlineColor;

    for (final entry in paths.muscles.entries) {
      final intensity = coverage.intensityOf(entry.key);
      final isSelected = selected == entry.key;
      final isDimmed = selected != null && !isSelected;

      // Untrained muscles stay at rest colour: they are the gap the athlete
      // needs to see, not something to hide.
      var fill = intensity <= 0
          ? restColor
          : Color.lerp(restColor, activeColor, .25 + intensity * .75)!;
      if (isDimmed) {
        fill = fill.withValues(alpha: fill.a * .35);
      }

      canvas.drawPath(entry.value, Paint()..color = fill);
      canvas.drawPath(entry.value, outlinePaint);

      if (isSelected) {
        canvas.drawPath(
          entry.value,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 / scale
            ..color = activeColor,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyMapPainter oldDelegate) =>
      oldDelegate.coverage != coverage ||
      oldDelegate.selected != selected ||
      oldDelegate.paths != paths ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.restColor != restColor;
}

/// Explains what the shading means.
class BodyMapLegend extends StatelessWidget {
  const BodyMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Mirrors the painter's rest colour so the legend describes the actual map.
    final plate = Color.lerp(scheme.surface, scheme.onSurface, .13)!;
    final rest = Color.lerp(plate, scheme.onSurface, .3)!;
    return Row(
      children: [
        Text(
          'Untrained',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: [rest, Color.lerp(rest, _accent, .45)!, _accent],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Most volume',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
