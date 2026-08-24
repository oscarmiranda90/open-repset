import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Native Flutter interpretations of interaction ideas from
/// https://github.com/yui540/css-animations (MIT).
///
/// These widgets intentionally expose a [trigger] instead of owning a button,
/// so production features can replay them from BLoC state changes later.
class CompletionPop extends StatefulWidget {
  const CompletionPop({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  State<CompletionPop> createState() => _CompletionPopState();
}

class _CompletionPopState extends State<CompletionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1.22), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.22, end: .92), weight: 25),
    TweenSequenceItem(tween: Tween(begin: .92, end: 1), weight: 25),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CompletionPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _controller, curve: const Interval(0, .2)),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

class DirectionalReveal extends StatefulWidget {
  const DirectionalReveal({
    required this.trigger,
    required this.child,
    this.accent = const Color(0xffd7ff4f),
    super.key,
  });

  final int trigger;
  final Widget child;
  final Color accent;

  @override
  State<DirectionalReveal> createState() => _DirectionalRevealState();
}

class _DirectionalRevealState extends State<DirectionalReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DirectionalReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final reveal = Curves.easeInOutCubicEmphasized.transform(
          const Interval(0, .72).transform(_controller.value),
        );
        final sweep = Curves.easeInOutCubicEmphasized.transform(
          const Interval(.12, 1).transform(_controller.value),
        );
        return Stack(
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: reveal,
                child: child,
              ),
            ),
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(-1 + (2 * sweep), 0),
                child: ColoredBox(color: widget.accent),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    ),
  );
}

class DominoSets extends StatefulWidget {
  const DominoSets({required this.trigger, super.key});

  final int trigger;

  @override
  State<DominoSets> createState() => _DominoSetsState();
}

class _DominoSetsState extends State<DominoSets>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DominoSets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _turnFor(int index) {
    final start = .12 + (index * .09);
    final progress = Curves.easeInOut.transform(
      Interval(start, math.min(start + .58, 1)).transform(_controller.value),
    );
    final settled = progress < .8 ? progress / .8 : 1 - ((1 - progress) * .08);
    final target = index == 3 ? math.pi / 2 : 1.05 + (index * .04);
    return target * settled;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => SizedBox(
      height: 84,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Transform.rotate(
              angle: _turnFor(index),
              alignment: Alignment.bottomRight,
              child: Container(
                width: 18,
                height: 58,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xffd7ff4f),
                    const Color(0xff66705c),
                    index / 5,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class RestBell extends StatefulWidget {
  const RestBell({required this.trigger, super.key});

  final int trigger;

  @override
  State<RestBell> createState() => _RestBellState();
}

class _RestBellState extends State<RestBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 840),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RestBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _sequence(List<double> values) {
    final segment = _controller.value * (values.length - 1);
    final index = segment.floor().clamp(0, values.length - 2);
    return values[index] +
        ((values[index + 1] - values[index]) * (segment - index));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(_sequence([22, -11, 6, 0]), _sequence([-48, 8, 0, 4, 0])),
      child: Transform.rotate(
        angle: _sequence([.78, -.28, .14, 0]),
        alignment: const Alignment(0, -.8),
        child: child,
      ),
    ),
    child: Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        Icons.timer_outlined,
        size: 38,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    ),
  );
}

class SuccessBurst extends StatefulWidget {
  const SuccessBurst({required this.trigger, super.key});

  final int trigger;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant SuccessBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final pop = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: 1.55), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.55, end: .96), weight: 25),
        TweenSequenceItem(tween: Tween(begin: .96, end: 1.08), weight: 20),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 15),
      ]).transform(const Interval(.1, .72).transform(_controller.value));
      return SizedBox.square(
        dimension: 112,
        child: CustomPaint(
          painter: _BurstPainter(progress: _controller.value),
          child: Center(
            child: Transform.scale(
              scale: pop,
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xffd7ff4f),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Color(0xff171914)),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final particleProgress = Curves.easeOutCubic.transform(
      const Interval(.05, .75).transform(progress),
    );
    final fade = 1 - const Interval(.55, 1).transform(progress);
    final colors = [
      const Color(0xffd7ff4f),
      const Color(0xfffe587a),
      const Color(0xff52a8ff),
      const Color(0xffffc857),
    ];

    final ringProgress = const Interval(0, .7).transform(progress);
    canvas.drawCircle(
      center,
      16 + (32 * ringProgress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(
          0xffd7ff4f,
        ).withValues(alpha: .55 * (1 - ringProgress)),
    );

    for (var index = 0; index < 10; index++) {
      final angle = (-math.pi / 2) + ((math.pi * 2 / 10) * index);
      final distance = 18 + (34 * particleProgress);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        point,
        math.max(0, (3.5 - (index % 3)) * fade),
        Paint()..color = colors[index % colors.length].withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

typedef MotionBuilder = Widget Function(BuildContext context, double progress);

class SplitGateReveal extends StatelessWidget {
  const SplitGateReveal({
    required this.trigger,
    required this.child,
    super.key,
  });
  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 760),
    builder: (context, progress) {
      final open = Curves.easeOutBack.transform(progress).clamp(0.0, 1.0);
      return Stack(
        children: [
          Positioned.fill(child: child),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: Transform.translate(
                    offset: Offset(-112 * open, 0),
                    child: const ColoredBox(color: Color(0xffd7ff4f)),
                  ),
                ),
                Expanded(
                  child: Transform.translate(
                    offset: Offset(112 * open, 0),
                    child: const ColoredBox(color: Color(0xffb8d944)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class HorizontalShutterSlide extends StatelessWidget {
  const HorizontalShutterSlide({required this.trigger, super.key});
  final int trigger;
  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 900),
    builder: (context, progress) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xffd7ff4f),
              alignment: Alignment.center,
              child: const Text(
                'SESSION READY',
                style: TextStyle(
                  color: Color(0xff171914),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          ...List.generate(5, (i) {
            final p = Curves.easeInOutCubic.transform(
              Interval(i * .08, .62 + i * .06).transform(progress),
            );
            return Positioned(
              left: -220 + (440 * p),
              top: i * 21.0,
              width: 220,
              height: 19,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            );
          }),
        ],
      ),
    ),
  );
}

class ReceiptTickerPrint extends StatelessWidget {
  const ReceiptTickerPrint({required this.trigger, super.key});
  final int trigger;
  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1050),
    builder: (context, progress) {
      final p = Curves.easeOutBack.transform(progress).clamp(0.0, 1.0);
      return ClipRect(
        child: Transform.translate(
          offset: Offset(0, -82 * (1 - p)),
          child: Container(
            width: 128,
            padding: const EdgeInsets.all(8),
            color: const Color(0xffe8eadf),
            child: const DefaultTextStyle(
              style: TextStyle(
                color: Color(0xff171914),
                fontFamily: 'monospace',
                fontSize: 8,
                height: 1.25,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('REPSET / RECEIPT'),
                  Text('-----------------------'),
                  Text('Bench press      3 x 8'),
                  Text('Volume       2,400 kg'),
                  Text('-----------------------'),
                  Text('SESSION SAVED'),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class CircuitTraceDraw extends StatelessWidget {
  const CircuitTraceDraw({required this.trigger, super.key});
  final int trigger;
  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1100),
    builder: (context, p) => CustomPaint(
      painter: _CircuitPainter(p),
      child: const SizedBox(width: 210, height: 104),
    ),
  );
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(12, 75)
      ..lineTo(58, 75)
      ..lineTo(58, 30)
      ..lineTo(116, 30)
      ..lineTo(116, 68)
      ..lineTo(188, 68);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(
      0,
      metric.length * Curves.easeInOutCubic.transform(progress),
    );
    final paint = Paint()
      ..color = const Color(0xffd7ff4f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawn, paint);
    for (final point in [
      const Offset(12, 75),
      const Offset(58, 30),
      const Offset(116, 68),
      const Offset(188, 68),
    ]) {
      canvas.drawCircle(
        point,
        6,
        Paint()..color = const Color(0xffd7ff4f).withValues(alpha: progress),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter old) => old.progress != progress;
}

class ScrollCanvasUnroll extends StatelessWidget {
  const ScrollCanvasUnroll({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 860),
    builder: (context, progress) {
      final reveal = Curves.easeOutBack.transform(progress).clamp(0.0, 1.0);
      return SizedBox(
        width: 212,
        height: 102,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: 26,
              height: 86,
              decoration: const BoxDecoration(
                color: Color(0xffd7ff4f),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(22),
                  right: Radius.circular(5),
                ),
              ),
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: reveal,
                child: Container(
                  width: 186,
                  height: 86,
                  margin: const EdgeInsets.only(left: 18),
                  padding: const EdgeInsets.all(14),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Text(
                    'PUSH\nDAY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: .9,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class KineticTensionCapsule extends StatelessWidget {
  const KineticTensionCapsule({required this.trigger, super.key});
  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 900),
    builder: (context, progress) {
      final stretch =
          1 +
          (math.sin(progress * math.pi) * .55) -
          (math.sin(progress * math.pi * 3) * (1 - progress) * .1);
      return Transform.scale(
        scaleX: stretch,
        child: Container(
          width: 130,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xffd7ff4f),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'REST 01:30',
            style: TextStyle(
              color: Color(0xff171914),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    },
  );
}

class CardDeckFanCascade extends StatelessWidget {
  const CardDeckFanCascade({required this.trigger, super.key});
  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1000),
    builder: (context, progress) => SizedBox(
      width: 220,
      height: 110,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: List.generate(4, (index) {
          final value = Curves.easeOutBack.transform(
            Interval(index * .09, .68 + index * .08).transform(progress),
          );
          final offset = (index - 1.5) * 36 * value;
          return Transform.translate(
            offset: Offset(offset, 10 * (1 - value)),
            child: Transform.rotate(
              angle: (index - 1.5) * .14 * value,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 58,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == 3
                      ? const Color(0xffd7ff4f)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class MatrixGridLoader extends StatelessWidget {
  const MatrixGridLoader({required this.trigger, super.key});
  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1200),
    builder: (context, progress) => SizedBox(
      width: 138,
      height: 104,
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: List.generate(30, (index) {
          final wave =
              ((progress * 9) - ((index % 6) * .58 + (index ~/ 6) * .34)).abs();
          final lit = (1 - wave).clamp(0.0, 1.0);
          return SizedBox(
            width: 19,
            height: 16.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  const Color(0xffd7ff4f),
                  lit,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class _TriggeredMotion extends StatefulWidget {
  const _TriggeredMotion({
    required this.trigger,
    required this.duration,
    required this.builder,
  });

  final int trigger;
  final Duration duration;
  final MotionBuilder builder;

  @override
  State<_TriggeredMotion> createState() => _TriggeredMotionState();
}

class _TriggeredMotionState extends State<_TriggeredMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _TriggeredMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

class RollingPlate extends StatelessWidget {
  const RollingPlate({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 760),
    builder: (context, progress) {
      final arrival = Curves.easeOutCubic.transform(progress);
      final settle = math.sin(progress * math.pi * 3) * (1 - progress) * .12;
      return Transform.translate(
        offset: Offset(-74 + (148 * arrival), 0),
        child: Transform.rotate(
          angle: (math.pi * 2 * arrival) + settle,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xffd7ff4f),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xff171914), width: 7),
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 7,
                backgroundColor: Color(0xff171914),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class BrakeSlide extends StatelessWidget {
  const BrakeSlide({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 780),
    builder: (context, progress) {
      final arrival = Curves.easeOutBack.transform(progress);
      final angle =
          (-.28 * (1 - progress)) +
          (math.sin(progress * math.pi * 4) * (1 - progress) * .045);
      return Transform.translate(
        offset: Offset(130 * (1 - arrival), 0),
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 146,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 7),
                Text(
                  'ADD SET',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class RecordRipple extends StatelessWidget {
  const RecordRipple({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1200),
    builder: (context, progress) => CustomPaint(
      painter: _RipplePainter(progress),
      child: const SizedBox.square(
        dimension: 120,
        child: Center(
          child: Text(
            'PR',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xffd7ff4f),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var index = 0; index < 3; index++) {
      final local = ((progress * 1.45) - (index * .22)).clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(local);
      canvas.drawCircle(
        center,
        18 + (39 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - (eased * 1.5)
          ..color = const Color(
            0xffd7ff4f,
          ).withValues(alpha: .75 * (1 - eased)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class FlipMetric extends StatelessWidget {
  const FlipMetric({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 900),
    builder: (context, progress) {
      final eased = Curves.easeInOutBack.transform(progress);
      final secondHalf = eased >= .5;
      final angle = secondHalf ? math.pi * (eased - 1) : math.pi * eased;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateX(angle),
        child: Container(
          width: 144,
          height: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: secondHalf
                ? const Color(0xffd7ff4f)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            secondHalf ? '102.5 KG' : '100.0 KG',
            style: TextStyle(
              color: secondHalf
                  ? const Color(0xff171914)
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
        ),
      );
    },
  );
}

class FoldingSets extends StatelessWidget {
  const FoldingSets({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1050),
    builder: (context, progress) => SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final start = index * .12;
          final local = Curves.easeOutBack.transform(
            Interval(start, .72 + start).transform(progress),
          );
          return Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .002)
              ..rotateX((1 - local) * -math.pi / 2),
            child: Opacity(
              opacity: local.clamp(0, 1),
              child: Container(
                height: 34,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text('${80 + (index * 5)} kg'),
                    const SizedBox(width: 12),
                    const Text('8 reps', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class GrowingChart extends StatelessWidget {
  const GrowingChart({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1000),
    builder: (context, progress) => SizedBox(
      width: 150,
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(6, (index) {
          final start = index * .07;
          final local = Curves.easeOutBack.transform(
            Interval(start, .65 + start).transform(progress),
          );
          final target = 30.0 + ([12, 34, 24, 52, 43, 62][index]);
          return Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 13,
                height: target * local,
                decoration: BoxDecoration(
                  color: index == 5
                      ? const Color(0xffd7ff4f)
                      : Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class OrbitLoader extends StatelessWidget {
  const OrbitLoader({required this.trigger, super.key});

  final int trigger;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1100),
    builder: (context, progress) => Transform.rotate(
      angle: Curves.easeInOutCubic.transform(progress) * math.pi * 2,
      child: SizedBox.square(
        dimension: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 5,
                ),
                shape: BoxShape.circle,
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Color(0xffd7ff4f),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.rotate(
                angle: -progress * math.pi * 4,
                child: const CircleAvatar(
                  radius: 6,
                  backgroundColor: Color(0xfffe587a),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CurtainReveal extends StatelessWidget {
  const CurtainReveal({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) => _TriggeredMotion(
    trigger: trigger,
    duration: const Duration(milliseconds: 1150),
    builder: (context, progress) {
      final open = Curves.easeInOutCubicEmphasized.transform(progress);
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            FractionalTranslation(
              translation: Offset(-open, 0),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: .51,
                  heightFactor: 1,
                  child: ColoredBox(color: Color(0xffd7ff4f)),
                ),
              ),
            ),
            FractionalTranslation(
              translation: Offset(open, 0),
              child: const Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: .51,
                  heightFactor: 1,
                  child: ColoredBox(color: Color(0xffa9ca3f)),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class ShutterReveal extends StatefulWidget {
  const ShutterReveal({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  State<ShutterReveal> createState() => _ShutterRevealState();
}

class _ShutterRevealState extends State<ShutterReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ShutterReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _panelScale(int index) {
    final delay = index * .035;
    final close = Curves.easeInOut.transform(
      Interval(delay, .36 + delay).transform(_controller.value),
    );
    final open = Curves.easeInOut.transform(
      Interval(.56 + delay, .88 + delay).transform(_controller.value),
    );
    return (close - open).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          ...List.generate(4, (index) {
            return Align(
              alignment: Alignment(-1 + (index * 2 / 3), 0),
              child: FractionallySizedBox(
                widthFactor: .255,
                heightFactor: 1,
                child: Transform.scale(
                  scaleY: _panelScale(index),
                  alignment: Alignment.topCenter,
                  child: ColoredBox(
                    color: index.isEven
                        ? const Color(0xffd7ff4f)
                        : const Color(0xffa9ca3f),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      child: widget.child,
    ),
  );
}
