import 'dart:math' as math;

import 'package:flutter/material.dart';

class DockItem {
  const DockItem({
    this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final Key? key;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
}

/// A touch-friendly interpretation of the macOS dock. Pointer proximity drives
/// neighboring icon scale while selection settles with a spring.
class MacosSpringDock extends StatefulWidget {
  const MacosSpringDock({
    required this.items,
    required this.selectedIndex,
    super.key,
  });

  final List<DockItem> items;
  final int selectedIndex;

  @override
  State<MacosSpringDock> createState() => _MacosSpringDockState();
}

class _MacosSpringDockState extends State<MacosSpringDock> {
  double? _pointerX;
  int? _pressedIndex;

  double _scaleFor(int index, double width) {
    if (_pointerX == null || width <= 0) return 1;
    final slot = width / widget.items.length;
    final center = (slot * index) + (slot / 2);
    final proximity = (1 - ((_pointerX! - center).abs() / (slot * 1.35))).clamp(
      0.0,
      1.0,
    );
    return 1 + (math.sin(proximity * math.pi / 2) * .42);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: LayoutBuilder(
      builder: (context, constraints) => MouseRegion(
        onHover: (event) => setState(() => _pointerX = event.localPosition.dx),
        onExit: (_) => setState(() => _pointerX = null),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.items.length, (index) {
              final item = widget.items[index];
              final active = index == widget.selectedIndex;
              final pressed = index == _pressedIndex;
              return Expanded(
                child: GestureDetector(
                  key: item.key,
                  behavior: HitTestBehavior.opaque,
                  onTap: item.onTap,
                  onTapDown: (_) => setState(() => _pressedIndex = index),
                  onTapCancel: () => setState(() => _pressedIndex = null),
                  onTapUp: (_) => setState(() => _pressedIndex = null),
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: item.label,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.elasticOut,
                      tween: Tween(
                        end:
                            (_scaleFor(index, constraints.maxWidth) *
                                    (pressed ? .9 : 1))
                                .clamp(.8, 1.42),
                      ),
                      builder: (context, scale, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 52,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Transform.translate(
                                offset: Offset(0, -((scale - 1) * 8)),
                                child: Transform.scale(
                                  alignment: Alignment.bottomCenter,
                                  scale: scale,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xffd7ff4f)
                                          : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      active ? item.activeIcon : item.icon,
                                      color: active
                                          ? const Color(0xff171914)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      size: 23,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: Theme.of(context).textTheme.labelSmall!
                                .copyWith(
                                  color: active
                                      ? const Color(0xffd7ff4f)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 10,
                                ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}
