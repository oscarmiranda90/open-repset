import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';

/// The example requests that cycle through the empty field.
///
/// They teach the input's range by showing it: a muscle with an emphasis,
/// an equipment preference, a time constraint.
const _promptHints = [
  'Legs, but mostly quads…',
  'Chest day — mostly machine based…',
  'Chest and shoulders, a quick one…',
  'Back and biceps, dumbbells only…',
  'Full body, nothing too heavy today…',
];

/// How long each hint rests before the next one takes its place.
const _hintDwell = Duration(seconds: 4);

/// A plain-language field for describing the session you want.
///
/// Only rendered when a planning backend is configured, so a build without one
/// shows nothing rather than an input that cannot answer.
class TrainPromptField extends StatefulWidget {
  const TrainPromptField({
    required this.onSubmitted,
    this.isBusy = false,
    this.busyLabel,
    this.onBlocked,
    this.disabledLabel,
    super.key,
  });

  final ValueChanged<String> onSubmitted;

  /// When set, the field never accepts input: tapping it runs this instead.
  /// Used to offer a subscription rather than let someone type a request that
  /// will not be served.
  final VoidCallback? onBlocked;

  final bool isBusy;

  /// What the field is doing while [isBusy], shown in place of the hint.
  final String? busyLabel;

  /// When set, the field is inert and says why. Unlike [onBlocked], which
  /// leads somewhere, this is a state the person has to leave on their own.
  final String? disabledLabel;

  @override
  State<TrainPromptField> createState() => _TrainPromptFieldState();
}

class _TrainPromptFieldState extends State<TrainPromptField>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shimmer;
  Timer? _hintTimer;
  final _hintIndex = ValueNotifier(0);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    // A slow travel of brightness around the border. Long enough to read as
    // the surface being alive rather than as something demanding attention.
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _startHintCycle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A repeating controller paints every frame for as long as the page lives,
    // so it only runs when the platform allows motion.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_shimmer.isAnimating) _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintIndex.dispose();
    _shimmer.dispose();
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  // The cycling hint is a suggestion, not a caption. Once the field is in use
  // it would only pull attention away from what is being typed.
  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _hintTimer?.cancel();
    } else if (_hintTimer?.isActive != true) {
      _startHintCycle();
    }
    setState(() {});
  }

  void _startHintCycle() {
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(_hintDwell, (_) {
      if (!mounted) return;
      // Only the hint label listens, so rotating it never rebuilds the field
      // or restarts the border animation.
      _hintIndex.value = (_hintIndex.value + 1) % _promptHints.length;
    });
  }

  void _submit() {
    if (widget.disabledLabel != null) return;
    final blocked = widget.onBlocked;
    if (blocked != null) {
      blocked();
      return;
    }
    final request = _controller.text.trim();
    if (request.isEmpty || widget.isBusy) return;
    _focusNode.unfocus();
    widget.onSubmitted(request);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = _focusNode.hasFocus;
    final disabled = widget.disabledLabel != null;
    final canSubmit =
        !disabled && (widget.onBlocked != null || (_hasText && !widget.isBusy));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            'What do you want to train today?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
            ),
          ),
        ),
        Opacity(
          opacity: disabled ? .55 : 1,
          child: _GlowFrame(
            shimmer: _shimmer,
            focused: focused,
            // A dormant field should not glow: the light is what says the
            // surface is listening.
            active: !disabled && (focused || widget.isBusy),
            child: _buildField(scheme, focused: focused, canSubmit: canSubmit),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    ColorScheme scheme, {
    required bool focused,
    required bool canSubmit,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // The field's own hintText cannot cross-fade, so the rotating
                // suggestion sits behind a transparent-placeholder field.
                IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _hintIndex,
                    builder: (context, index, _) => _RotatingHint(
                      text:
                          widget.disabledLabel ??
                          (widget.isBusy
                              ? widget.busyLabel ?? 'Planning your session…'
                              : _promptHints[index]),
                      visible: !_hasText,
                      color: scheme.onSurfaceVariant.withValues(alpha: .75),
                    ),
                  ),
                ),
                TextField(
                  key: const Key('train-prompt-field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.isBusy && widget.disabledLabel == null,
                  readOnly: widget.onBlocked != null,
                  onTap: widget.onBlocked,
                  maxLines: 1,
                  maxLength: 200,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.1,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(onPressed: canSubmit ? _submit : null),
        ],
      ),
    );
  }
}

/// The field's border and the light behind it.
///
/// The border is a gradient rather than a flat colour so a bright band can
/// travel around it, which reads as a surface that is listening. Focus raises
/// the whole thing: the accent takes over the band and a soft glow lifts off
/// the background.
class _GlowFrame extends StatelessWidget {
  const _GlowFrame({
    required this.shimmer,
    required this.focused,
    required this.active,
    required this.child,
  });

  static const _accent = Color(0xffd7ff4f);
  static const _radius = 26.0;

  final Animation<double> shimmer;
  final bool focused;

  /// Whether the field is focused or working. Both deserve the lit state.
  final bool active;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resting = scheme.outlineVariant.withValues(alpha: .55);

    // The glow reacts to focus, so it is the only part that interpolates. The
    // travelling band is painted straight from the controller: handing a new
    // gradient to an AnimatedContainer every frame restarted its 260 ms tween
    // before it could finish, which is what made the light stick in place
    // instead of moving.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: active
            ? [
                // Kept wide and low-alpha so it reads as light rather than as
                // a drop shadow.
                BoxShadow(
                  color: _accent.withValues(alpha: .16),
                  blurRadius: 26,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: _accent.withValues(alpha: .07),
                  blurRadius: 44,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: CustomPaint(
        painter: _SweepBorderPainter(
          progress: shimmer,
          radius: _radius,
          thickness: focused ? 1.6 : 1.1,
          resting: resting,
          accent: _accent,
          focused: focused,
        ),
        child: Padding(
          padding: EdgeInsets.all(focused ? 1.6 : 1.1),
          child: child,
        ),
      ),
    );
  }
}

/// Paints the border as a rotating sweep gradient.
///
/// `repaint: progress` keeps the animation in the paint phase, so the band
/// travels without rebuilding the field or its text on every frame.
class _SweepBorderPainter extends CustomPainter {
  _SweepBorderPainter({
    required this.progress,
    required this.radius,
    required this.thickness,
    required this.resting,
    required this.accent,
    required this.focused,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double radius;
  final double thickness;
  final Color resting;
  final Color accent;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final band = focused ? accent : Color.lerp(resting, accent, .55)!;
    final base = focused ? accent.withValues(alpha: .45) : resting;
    final trough = focused ? accent.withValues(alpha: .22) : resting;

    final gradient = SweepGradient(
      transform: GradientRotation(progress.value * 2 * math.pi),
      colors: [base, band, base, trough, base],
      stops: const [0, .12, .28, .64, 1],
    );

    // Stroking an inset rounded rect keeps the band an even width; painting a
    // filled shape and covering it would leave the corners heavier.
    final outline = RRect.fromRectAndRadius(
      rect.deflate(thickness / 2),
      Radius.circular(radius - thickness / 2),
    );
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SweepBorderPainter oldDelegate) =>
      oldDelegate.focused != focused ||
      oldDelegate.thickness != thickness ||
      oldDelegate.resting != resting ||
      oldDelegate.accent != accent;
}

class _RotatingHint extends StatelessWidget {
  const _RotatingHint({
    required this.text,
    required this.visible,
    required this.color,
  });

  final String text;
  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: const Duration(milliseconds: 160),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          letterSpacing: -.1,
        ),
      ),
    ),
  );
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    return RepSetPress(
      scale: .92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xffd7ff4f)
              : scheme.onSurfaceVariant.withValues(alpha: .14),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          key: const Key('train-prompt-send'),
          onPressed: onPressed,
          tooltip: 'Plan this session',
          padding: EdgeInsets.zero,
          iconSize: 19,
          icon: Icon(
            Icons.arrow_upward_rounded,
            color: enabled
                ? const Color(0xff171914)
                : scheme.onSurfaceVariant.withValues(alpha: .5),
          ),
        ),
      ),
    );
  }
}
