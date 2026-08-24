import 'package:flutter/material.dart';

import '../../core/motion/repset_motion.dart';

const _accent = Color(0xffd7ff4f);

/// The brand mark, rendered from the launcher icon source so the in-app
/// identity and the home-screen icon never drift apart.
class RepSetBrandMark extends StatelessWidget {
  const RepSetBrandMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .26),
    child: Image.asset(
      'assets/icon/brand_mark.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// The primary call to action. Owns the accent colour and the largest
/// type on the page so there is never ambiguity about the next action.
class PrimarySessionTile extends StatelessWidget {
  const PrimarySessionTile({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
  });

  final String eyebrow;
  final String headline;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: .72),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.04,
                  letterSpacing: -.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RepSetPress(
            child: FilledButton.icon(
              key: const Key('primary-session-action'),
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                foregroundColor: scheme.primary,
                minimumSize: const Size(double.infinity, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: Icon(actionIcon, size: 19),
              label: Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A secondary navigation tile. Carries a real, verifiable count — never a
/// fabricated metric — so the surface stays honest about what it knows.
class HomeNavTile extends StatelessWidget {
  const HomeNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.trailingBadge,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final String? trailingBadge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepSetPress(
      scale: .97,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 15,
              compact ? 11 : 14,
              compact ? 10 : 13,
              compact ? 11 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: compact ? 17 : 19, color: _accent),
                    const Spacer(),
                    if (trailingBadge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          trailingBadge!,
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 13.5 : 14.5,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: compact ? 10.5 : 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: compact ? 12 : 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
