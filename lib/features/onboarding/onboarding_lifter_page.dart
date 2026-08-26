import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';
import 'onboarding_flow.dart';

/// The lifter path: the app is yours, free, and here is what Max adds.
///
/// The order matters. What is free comes first and in full, because that is
/// the promise; Max is offered afterwards as support, not as the price of
/// entry. Nobody reaches the logger through a payment.
class OnboardingLifterPage extends StatelessWidget {
  const OnboardingLifterPage({
    super.key,
    required this.name,
    required this.onContinue,
    this.onOpenPaywall,
  });

  final String name;
  final VoidCallback onContinue;

  /// Absent when this build cannot sell a subscription, such as a fork.
  final VoidCallback? onOpenPaywall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = name.isEmpty ? 'Great.' : 'Great, $name.';
    return OnboardingScaffold(
      footer: OnboardingButton(
        key: const Key('onboarding-lifter-continue'),
        label: 'Start training',
        icon: Icons.arrow_forward_rounded,
        onPressed: onContinue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepSetEntrance(
            child: Text(
              greeting,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.06,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          RepSetEntrance(
            delay: const Duration(milliseconds: 60),
            child: Text(
              'RepSet is a free training logger, built in the open. Log your '
              'sessions — all of it works without an account.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 26),
          for (final (index, item) in const [
            (Icons.check_rounded, 'Every workout, set and rep'),
            (Icons.check_rounded, 'Templates and training history'),
            (Icons.check_rounded, 'Progress and muscle coverage'),
            (Icons.check_rounded, 'Yours on your device, always free'),
          ].indexed) ...[
            RepSetEntrance(
              delay: Duration(milliseconds: 100 + index * 35),
              child: _FreeRow(icon: item.$1, label: item.$2),
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 22),
          if (onOpenPaywall != null)
            RepSetEntrance(
              delay: const Duration(milliseconds: 260),
              child: _MaxInvitation(onTap: onOpenPaywall!),
            ),
        ],
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  const _FreeRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: onboardingAccent.withValues(alpha: .16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: onboardingAccent),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -.15,
          ),
        ),
      ),
    ],
  );
}

class _MaxInvitation extends StatelessWidget {
  const _MaxInvitation({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepSetPress(
      scale: .985,
      child: GestureDetector(
        key: const Key('onboarding-open-paywall'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: onboardingAccent.withValues(alpha: .45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: onboardingAccent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'REPSET MAX',
                  style: TextStyle(
                    color: onboardingAccent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              const Text(
                'Want to help keep this going?',
                style: TextStyle(
                  fontSize: 16.5,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Max removes the ads and unlocks AI session planning. It is '
                'what pays for the development.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Text(
                    'See plans',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: onboardingAccent,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: onboardingAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
