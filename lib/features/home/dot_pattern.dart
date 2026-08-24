import 'dart:math' as math;

import 'package:flutter/material.dart';

// `dart:io` does not exist on web, so the environment probe is swapped at
// compile time for a stub there.
import 'test_environment_web.dart'
    if (dart.library.io) 'test_environment_io.dart';

/// A tiled dot grid used as a page backdrop.
///
/// The pattern is decorative only: it fades toward the edges so page content
/// always wins the contrast comparison against it, and its wave motion stops
/// entirely when the platform asks for reduced motion.
class DotPattern extends StatefulWidget {
  const DotPattern({
    super.key,
    this.spacing = 16,
    this.radius = 1.4,
    this.color,
    this.tint = const Color(0xffd7ff4f),
    this.tintStrength = .85,
    this.opacity = .42,
    this.fade = true,
    this.animate = true,
    this.wavePeriod = const Duration(seconds: 14),
    this.waveAmplitude = 2.2,
  });

  /// Distance between dot centres, in logical pixels.
  final double spacing;

  /// Radius of each dot.
  final double radius;

  /// Defaults to the theme's `outlineVariant` so the pattern inverts with the
  /// theme and stays a background texture rather than a foreground element.
  final Color? color;

  /// Brand hue mixed into the dots. The blend is strongest at the centre and
  /// falls off outward, so the grid reads as a lime glow rather than a flat
  /// wash of green.
  final Color tint;

  /// How much [tint] reaches the centre-most dots, from 0 (none) to 1 (full).
  final double tintStrength;

  /// Alpha applied to the dots. High enough to read as texture, low enough that
  /// content on top never has to fight it.
  final double opacity;

  /// Fades the grid out toward the edges, keeping density near the centre.
  final bool fade;

  /// Drives the wave. Callers pass `false` for a still grid; the widget also
  /// stops on its own when the platform requests reduced motion.
  final bool animate;

  /// One full cycle of the slower of the two waves. Long on purpose: the drift
  /// should be noticed only if you look for it.
  final Duration wavePeriod;

  /// Peak dot displacement in logical pixels. Kept well under [spacing] so the
  /// grid never visibly breaks formation.
  final double waveAmplitude;

  @override
  State<DotPattern> createState() => _DotPatternState();
}

class _DotPatternState extends State<DotPattern>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.wavePeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(DotPattern oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wavePeriod != widget.wavePeriod) {
      _controller.duration = widget.wavePeriod;
    }
    _syncPlayback();
  }

  /// A repeating controller is a permanent 60fps repaint, so it only runs when
  /// motion is both wanted and allowed.
  ///
  /// It also stays off under `flutter test`: an endless animation means
  /// `pumpAndSettle` never settles, and a decorative backdrop is not something
  /// widget tests should have to schedule around.
  void _syncPlayback() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldRun =
        widget.animate && !reduceMotion && !isWidgetTestEnvironment;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? Theme.of(context).colorScheme.outlineVariant;
    final resolved = base.withValues(alpha: widget.opacity);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DotPatternPainter(
          spacing: widget.spacing,
          radius: widget.radius,
          color: resolved,
          tint: widget.tint,
          tintStrength: widget.tintStrength.clamp(0.0, 1.0),
          fade: widget.fade,
          phase: _controller,
          amplitude: widget.waveAmplitude,
        ),
        isComplex: true,
        willChange: true,
        size: Size.infinite,
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  _DotPatternPainter({
    required this.spacing,
    required this.radius,
    required this.color,
    required this.tint,
    required this.tintStrength,
    required this.fade,
    required this.phase,
    required this.amplitude,
  }) : super(repaint: phase);

  final double spacing;
  final double radius;
  final Color color;
  final Color tint;
  final double tintStrength;
  final bool fade;

  /// Repaint driver, read as a 0..1 position through the wave cycle. Passing it
  /// to `super.repaint` keeps the animation in the paint phase — no widget
  /// rebuild runs per frame.
  final Animation<double> phase;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || spacing <= 0) return;

    final columns = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    // Centre the grid so the pattern does not appear anchored to one corner.
    final offsetX = (size.width - (columns - 1) * spacing) / 2;
    final offsetY = (size.height - (rows - 1) * spacing) / 2;

    final centre = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.sqrt(
      centre.dx * centre.dx + centre.dy * centre.dy,
    );

    // The fully tinted dot, resolved once rather than per dot.
    final tinted =
        Color.lerp(color, tint.withValues(alpha: color.a), tintStrength) ??
        color;
    final paint = Paint()..color = tinted;

    // Two waves at different speeds and angles. A single sine reads as an
    // obvious repeating ripple; letting two interfere keeps the drift from
    // ever settling into a pattern the eye can lock onto.
    //
    // Both temporal factors must be whole numbers. The controller wraps 1 -> 0,
    // so a fractional factor would leave its wave mid-cycle at the wrap and
    // snap — the seam has to land on an exact multiple of 2π for every wave.
    final t = phase.value * 2 * math.pi;
    const primaryWavelength = 190.0;
    const secondaryWavelength = 310.0;
    const primarySpeed = 1.0;
    const secondarySpeed = 2.0;
    // A constant offset desynchronises the two crests without touching their
    // periods, so the interference stays irregular and the loop stays seamless.
    const secondaryOffset = 2.4;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final baseX = offsetX + column * spacing;
        final baseY = offsetY + row * spacing;

        // Each wave travels along its own diagonal, so the crests sweep across
        // the field instead of pulsing the whole grid in unison.
        final primary = math.sin(
          (baseX + baseY) / primaryWavelength * 2 * math.pi + t * primarySpeed,
        );
        final secondary = math.sin(
          (baseX - baseY * .6) / secondaryWavelength * 2 * math.pi +
              secondaryOffset -
              t * secondarySpeed,
        );

        final position = Offset(
          baseX + primary * amplitude,
          baseY + secondary * amplitude,
        );

        if (!fade) {
          canvas.drawCircle(position, radius, paint);
          continue;
        }
        final distance = (position - centre).distance / maxDistance;
        // Hold full strength through the centre, then fall away near the
        // edges — the radial mask MagicUI applies over its dot grid.
        final strength = (1 - math.pow(distance, 2.6))
            .clamp(0.0, 1.0)
            .toDouble();
        if (strength <= .02) continue;
        // Riding the crest brightens a dot slightly. Without this the motion
        // reads as jitter; with it, the wave looks like light moving across
        // the surface.
        final crest = (.86 + (primary + secondary) * .07).clamp(0.0, 1.0);
        // Lime concentrates where the content sits and drains toward the
        // edges, so the tint reads as a glow instead of a flat green wash.
        final dot = Color.lerp(color, tinted, strength) ?? tinted;
        // The Paint is reused: allocating one per dot would churn a thousand
        // short-lived objects on every repaint.
        paint.color = dot.withValues(alpha: color.a * strength * crest);
        canvas.drawCircle(position, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) =>
      oldDelegate.spacing != spacing ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.tint != tint ||
      oldDelegate.tintStrength != tintStrength ||
      oldDelegate.fade != fade ||
      oldDelegate.amplitude != amplitude ||
      // Per-frame repaints already arrive through `super.repaint`; this only
      // catches the controller itself being swapped out.
      oldDelegate.phase != phase;
}
