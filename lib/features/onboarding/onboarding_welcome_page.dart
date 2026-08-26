import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';
import '../../domain/app_preferences.dart';
import '../home/home_tiles.dart';
import 'onboarding_flow.dart';

/// The opening screen: who RepSet is, and who is holding the phone.
///
/// The name is optional. Asking for it warms the next screens, but refusing to
/// continue without one would be a toll gate on a free logger.
class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key, required this.onContinue});

  final void Function(String name, TrainerPath path) onContinue;

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {
  final _controller = TextEditingController();
  TrainerPath? _path;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(TrainerPath path) => setState(() => _path = path);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OnboardingScaffold(
      footer: OnboardingButton(
        key: const Key('onboarding-continue'),
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: _path == null
            ? null
            : () => widget.onContinue(_controller.text, _path!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepSetEntrance(
            child: Row(
              children: [
                const RepSetBrandMark(size: 40),
                const SizedBox(width: 13),
                Text(
                  'REPSET',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          RepSetEntrance(
            delay: const Duration(milliseconds: 60),
            child: Text(
              'This is RepSet.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.02,
                letterSpacing: -1.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          RepSetEntrance(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Open source gym training.',
              style: TextStyle(
                color: onboardingAccent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
          ),
          const SizedBox(height: 38),
          RepSetEntrance(
            delay: const Duration(milliseconds: 150),
            child: _FieldLabel('Who are you?'),
          ),
          const SizedBox(height: 10),
          RepSetEntrance(
            delay: const Duration(milliseconds: 170),
            child: TextField(
              key: const Key('onboarding-name'),
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Your name',
                counterText: '',
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: onboardingAccent,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          RepSetEntrance(
            delay: const Duration(milliseconds: 210),
            child: _FieldLabel('You are?'),
          ),
          const SizedBox(height: 10),
          RepSetEntrance(
            delay: const Duration(milliseconds: 230),
            child: _PathOption(
              key: const Key('onboarding-path-developer'),
              icon: Icons.terminal_rounded,
              title: 'A developer',
              detail: 'Show me the repository and how to run it',
              selected: _path == TrainerPath.developer,
              onTap: () => _select(TrainerPath.developer),
            ),
          ),
          const SizedBox(height: 10),
          RepSetEntrance(
            delay: const Duration(milliseconds: 260),
            child: _PathOption(
              key: const Key('onboarding-path-lifter'),
              icon: Icons.fitness_center_rounded,
              title: 'I just want to train',
              detail: 'Take me straight to logging workouts',
              selected: _path == TrainerPath.lifter,
              onTap: () => _select(TrainerPath.lifter),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -.35,
    ),
  );
}

class _PathOption extends StatelessWidget {
  const _PathOption({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepSetPress(
      scale: .985,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
          decoration: BoxDecoration(
            color: selected
                ? onboardingAccent.withValues(alpha: .11)
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? onboardingAccent
                  : scheme.outlineVariant.withValues(alpha: .5),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: onboardingAccent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: onboardingAccent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: onboardingAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
