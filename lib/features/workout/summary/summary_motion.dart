import 'dart:math' as math;

import 'package:flutter/material.dart';

const summaryAccent = Color(0xffd7ff4f);

/// Drives a one-shot animation that starts after [delay].
///
/// The animation lab's equivalent is private and its demos carry hard-coded
/// content, so the summary owns a version that takes real data and can be
/// sequenced into a longer choreography.
class SummaryStage extends StatefulWidget {
  const SummaryStage({
    super.key,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
  });

  final Duration duration;
  final Duration delay;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<SummaryStage> createState() => _SummaryStageState();
}

class _SummaryStageState extends State<SummaryStage>
    with SingleTickerProviderStateMixin {
  // The delay is modelled as dead time at the head of the controller rather
  // than a `Future.delayed`, so the whole sequence advances with the animation
  // clock. That keeps it deterministic and lets `pumpAndSettle` reach the end.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  late final double _delayFraction = _resolveDelayFraction();

  double _resolveDelayFraction() {
    final total = (widget.delay + widget.duration).inMicroseconds;
    if (total <= 0) return 0;
    return widget.delay.inMicroseconds / total;
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery cannot be read during initState, and the reduced-motion check
    // needs it, so the sequence starts here instead.
    if (_started) return;
    _started = true;
    // Reduced motion still gets the final frame, just without the travel.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  /// Maps the controller onto 0..1 of the visible animation, holding at 0 for
  /// the leading delay.
  double get _progress {
    final raw = _controller.value;
    if (raw <= _delayFraction) return 0;
    if (_delayFraction >= 1) return 1;
    return ((raw - _delayFraction) / (1 - _delayFraction)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _progress),
  );
}

/// Vertical shutter that opens over the summary content.
class SummaryShutter extends StatelessWidget {
  const SummaryShutter({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => SummaryStage(
    duration: const Duration(milliseconds: 620),
    delay: delay,
    builder: (context, progress) {
      final eased = Curves.easeOutCubic.transform(progress);
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: eased.clamp(.001, 1.0),
          child: Opacity(opacity: eased, child: child),
        ),
      );
    },
  );
}

/// Feeds the receipt downward out of an unseen printer slot.
///
/// This is the animation lab's `receipt-ticker-print` motion — clipped travel
/// from above with an `easeOutBack` overshoot — applied to real session data
/// instead of the demo's fixed lines.
class ReceiptTickerPrint extends StatelessWidget {
  const ReceiptTickerPrint({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.travel = 120,
  });

  final Widget child;
  final Duration delay;

  /// How far above its resting place the receipt starts.
  final double travel;

  @override
  Widget build(BuildContext context) => SummaryStage(
    duration: const Duration(milliseconds: 1050),
    delay: delay,
    builder: (context, progress) {
      final eased = Curves.easeOutBack.transform(progress).clamp(0.0, 1.0);
      return ClipRect(
        child: Transform.translate(
          offset: Offset(0, -travel * (1 - eased)),
          child: child,
        ),
      );
    },
  );
}

/// Slides a row up into place. Staggering the [delay] across a list produces
/// the folding-sets cascade.
class FoldingRow extends StatelessWidget {
  const FoldingRow({super.key, required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => SummaryStage(
    duration: const Duration(milliseconds: 460),
    delay: delay,
    builder: (context, progress) {
      final eased = Curves.easeOutCubic.transform(progress);
      return Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - eased)),
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateX((1 - eased) * .55),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Counts a number up to [value] while fading in.
class MetricFlip extends StatelessWidget {
  const MetricFlip({
    super.key,
    required this.value,
    required this.label,
    this.suffix = '',
    this.fractionDigits = 0,
    this.delay = Duration.zero,
    this.emphasised = false,
  });

  final double value;
  final String label;
  final String suffix;
  final int fractionDigits;
  final Duration delay;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SummaryStage(
      duration: const Duration(milliseconds: 900),
      delay: delay,
      builder: (context, progress) {
        final eased = Curves.easeOutCubic.transform(progress);
        final shown = value * eased;
        return Opacity(
          opacity: Curves.easeOut.transform(progress.clamp(0.0, 1.0)),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0015)
              ..rotateX((1 - eased) * .9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_format(shown)}$suffix',
                  maxLines: 1,
                  style: TextStyle(
                    color: emphasised ? summaryAccent : scheme.onSurface,
                    fontSize: emphasised ? 27 : 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.9,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _format(double raw) {
    if (fractionDigits > 0) return raw.toStringAsFixed(fractionDigits);
    final rounded = raw.round();
    if (rounded < 1000) return '$rounded';
    final text = '$rounded';
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index++) {
      if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
      buffer.write(text[index]);
    }
    return buffer.toString();
  }
}

/// Expanding rings behind a personal-record badge.
class RecordRipple extends StatelessWidget {
  const RecordRipple({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => SummaryStage(
    duration: const Duration(milliseconds: 1200),
    delay: delay,
    builder: (context, progress) => CustomPaint(
      painter: _RipplePainter(progress),
      child: Opacity(
        opacity: Curves.easeOut.transform(progress.clamp(0.0, 1.0)),
        child: child,
      ),
    ),
  );
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final reach = size.longestSide * .6;
    for (var index = 0; index < 3; index++) {
      final local = ((progress * 1.45) - (index * .22)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOut.transform(local);
      canvas.drawCircle(
        center,
        reach * .34 + (reach * .66 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - (eased * 1.5)
          ..color = summaryAccent.withValues(alpha: .55 * (1 - eased)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Radial burst that fires once behind the summary header.
class SuccessBurst extends StatelessWidget {
  const SuccessBurst({super.key, this.delay = Duration.zero, this.rays = 12});

  final Duration delay;
  final int rays;

  @override
  Widget build(BuildContext context) => SummaryStage(
    duration: const Duration(milliseconds: 1100),
    delay: delay,
    builder: (context, progress) =>
        CustomPaint(painter: _BurstPainter(progress, rays)),
  );
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.progress, this.rays);

  final double progress;
  final int rays;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = summaryAccent.withValues(alpha: .8 * fade);

    final reach = size.shortestSide * .5;
    for (var index = 0; index < rays; index++) {
      final angle = (index / rays) * 2 * math.pi;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (reach * .28 + reach * .5 * eased),
        center + direction * (reach * .42 + reach * .62 * eased),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.rays != rays;
}

/// Horizontal bar that grows to [fraction] of the available width.
class GrowingBar extends StatelessWidget {
  const GrowingBar({
    super.key,
    required this.fraction,
    required this.delay,
    this.color = summaryAccent,
    this.height = 6,
  });

  final double fraction;
  final Duration delay;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SummaryStage(
    duration: const Duration(milliseconds: 720),
    delay: delay,
    builder: (context, progress) {
      final eased = Curves.easeOutCubic.transform(progress);
      return ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: (fraction.clamp(0.0, 1.0)) * eased,
          minHeight: height,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: .09),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    },
  );
}

/// Spinning plate mark used as the summary's loading state.
class RollingPlate extends StatefulWidget {
  const RollingPlate({super.key, this.size = 34});

  final double size;

  @override
  State<RollingPlate> createState() => _RollingPlateState();
}

class _RollingPlateState extends State<RollingPlate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Transform.rotate(
      angle: _controller.value * 2 * math.pi,
      child: Icon(
        Icons.donut_large_rounded,
        size: widget.size,
        color: summaryAccent,
      ),
    ),
  );
}
