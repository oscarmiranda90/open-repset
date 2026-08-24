import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class RepSetMotion {
  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 320);
  static const expressive = Duration(milliseconds: 520);

  static const sheetAnimation = AnimationStyle(
    duration: standard,
    reverseDuration: Duration(milliseconds: 240),
  );
}

class RepSetPress extends StatefulWidget {
  const RepSetPress({required this.child, this.scale = .97, super.key});

  final Widget child;
  final double scale;

  @override
  State<RepSetPress> createState() => _RepSetPressState();
}

class _RepSetPressState extends State<RepSetPress> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: reduceMotion ? Duration.zero : RepSetMotion.instant,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class RepSetEntrance extends StatefulWidget {
  const RepSetEntrance({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  State<RepSetEntrance> createState() => _RepSetEntranceState();
}

/// A shallow physical unfold for a newly inserted workout set.
///
/// The keyed set row keeps this state after list rebuilds, so it only plays for
/// the new row instead of replaying every set when the workout changes.
class RepSetFoldIn extends StatefulWidget {
  const RepSetFoldIn({required this.child, super.key});

  final Widget child;

  @override
  State<RepSetFoldIn> createState() => _RepSetFoldInState();
}

/// Full-surface left-to-right reveal used when entering a major feature.
class RepSetDirectionalReveal extends StatefulWidget {
  const RepSetDirectionalReveal({
    required this.trigger,
    required this.child,
    this.accent = const Color(0xffd7ff4f),
    super.key,
  });

  final int trigger;
  final Widget child;
  final Color accent;

  @override
  State<RepSetDirectionalReveal> createState() =>
      _RepSetDirectionalRevealState();
}

class _RepSetDirectionalRevealState extends State<RepSetDirectionalReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(covariant RepSetDirectionalReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _play();
  }

  void _play() {
    if (!mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
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
      child: widget.child,
      builder: (context, child) {
        final reveal = Curves.easeInOutCubicEmphasized.transform(
          const Interval(0, .72).transform(_controller.value),
        );
        final sweep = Curves.easeInOutCubicEmphasized.transform(
          const Interval(.12, 1).transform(_controller.value),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(clipper: _HorizontalRevealClipper(reveal), child: child),
            Positioned.fill(
              child: IgnorePointer(
                child: FractionalTranslation(
                  translation: Offset(-1 + (2 * sweep), 0),
                  child: ColoredBox(color: widget.accent),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _HorizontalRevealClipper extends CustomClipper<Rect> {
  const _HorizontalRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_HorizontalRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _RepSetFoldInState extends State<RepSetFoldIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RepSetMotion.expressive,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      // The clip is only needed while the row unfolds. Once settled, removing
      // it lets elevated details (such as the RPE bubble) paint above the row.
      if (_controller.isCompleted) return child!;
      final unfold = Curves.easeOutBack
          .transform(_controller.value)
          .clamp(0.0, 1.0)
          .toDouble();
      final reveal = Curves.easeOutCubic.transform(_controller.value);
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: reveal,
          child: Opacity(
            opacity: reveal,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateX((1 - unfold) * -math.pi / 2),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class _RepSetEntranceState extends State<RepSetEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RepSetMotion.expressive,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 18 * (1 - _curved.value)),
        child: Transform.scale(
          scale: .985 + (.015 * _curved.value),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: widget.child,
    ),
  );
}
