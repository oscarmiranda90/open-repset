import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';
import 'onboarding_flow.dart';

/// The last screen, and the only one that is pure theatre.
///
/// Everything before it explained something. This one just sends you off, so
/// it holds a single line, a beat of silence, and the way out.
class OnboardingReadyPage extends StatefulWidget {
  const OnboardingReadyPage({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<OnboardingReadyPage> createState() => _OnboardingReadyPageState();
}

class _OnboardingReadyPageState extends State<OnboardingReadyPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A looping glow paints every frame for as long as this page is up, so it
    // only runs where the platform allows motion.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _BreathingGlow(pulse: _pulse),
      OnboardingScaffold(
        footer: OnboardingButton(
          key: const Key('onboarding-finish'),
          label: 'Go and lift',
          icon: Icons.bolt_rounded,
          onPressed: widget.onFinish,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepSetEntrance(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  'ARE YOU READY?',
                  style: TextStyle(
                    color: onboardingAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              RepSetEntrance(
                delay: const Duration(milliseconds: 320),
                child: Text(
                  'Go and\nlift.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 66,
                    fontWeight: FontWeight.w900,
                    height: .95,
                    letterSpacing: -3.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              RepSetEntrance(
                delay: const Duration(milliseconds: 620),
                child: Container(
                  height: 3,
                  width: 64,
                  decoration: BoxDecoration(
                    color: onboardingAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              RepSetEntrance(
                delay: const Duration(milliseconds: 760),
                child: Text(
                  'The first set is the only one that needs deciding.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// A slow wash of accent light behind the type.
class _BreathingGlow extends StatelessWidget {
  const _BreathingGlow({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-.55, -.45),
            radius: 1.05 + pulse.value * .22,
            colors: [
              onboardingAccent.withValues(alpha: .12 + pulse.value * .05),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}
