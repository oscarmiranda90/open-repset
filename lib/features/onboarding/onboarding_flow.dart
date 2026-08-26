import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';
import '../../domain/app_preferences.dart';
import 'onboarding_developer_page.dart';
import 'onboarding_lifter_page.dart';
import 'onboarding_ready_page.dart';
import 'onboarding_welcome_page.dart';

const onboardingAccent = Color(0xffd7ff4f);

/// The first-run introduction.
///
/// It asks two things and then gets out of the way. Nothing here gates the
/// app: whichever path someone picks, they land in the same logger with the
/// same features. The answer only changes what RepSet says to them on the way
/// in — a developer wants the repository, a lifter wants to start training.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onFinished,
    this.onOpenPaywall,
  });

  /// Called with the completed record once the last screen is dismissed.
  final ValueChanged<OnboardingRecord> onFinished;

  /// Offered on the lifter path. Absent when this build cannot sell Max.
  final VoidCallback? onOpenPaywall;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  String _name = '';
  TrainerPath? _path;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() => _controller.nextPage(
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

  void _choosePath(String name, TrainerPath path) {
    setState(() {
      _name = name.trim();
      _path = path;
    });
    _advance();
  }

  void _finish() => widget.onFinished(
    OnboardingRecord(name: _name, path: _path, isComplete: true),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff151714),
    body: SafeArea(
      child: PageView(
        controller: _controller,
        // Progress belongs to the answers, not to a swipe: skipping the
        // question would leave the later screens with nothing to address.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          OnboardingWelcomePage(onContinue: _choosePath),
          if (_path == TrainerPath.developer)
            OnboardingDeveloperPage(name: _name, onContinue: _advance)
          else
            OnboardingLifterPage(
              name: _name,
              onContinue: _advance,
              onOpenPaywall: widget.onOpenPaywall,
            ),
          OnboardingReadyPage(onFinish: _finish),
        ],
      ),
    ),
  );
}

/// Shared chrome for the flow's pages, so they breathe alike.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    required this.footer,
  });

  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 40, 26, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 6, 26, 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: footer,
        ),
      ),
    ],
  );
}

/// The flow's primary action.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 54)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    final text = Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: -.2,
      ),
    );
    return RepSetPress(
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: style.copyWith(
                backgroundColor: const WidgetStatePropertyAll(onboardingAccent),
                foregroundColor: const WidgetStatePropertyAll(
                  Color(0xff171914),
                ),
              ),
              icon: icon == null ? null : Icon(icon, size: 19),
              label: text,
            )
          : TextButton(
              onPressed: onPressed,
              style: style.copyWith(
                foregroundColor: const WidgetStatePropertyAll(Color(0xfff3f5ef)),
              ),
              child: text,
            ),
    );
  }
}
