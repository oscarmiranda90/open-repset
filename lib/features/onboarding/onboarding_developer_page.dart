import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/repset_motion.dart';
import 'onboarding_flow.dart';

const _repositoryUrl = 'github.com/oscarcrescente/open-repset';

/// The lines the terminal types out, in order.
///
/// Written as a session someone could actually run: clone, install, launch.
/// A fork gets the demo catalogue and no keys, which is the whole point of the
/// community build, so the last line says so rather than leaving it to be
/// discovered.
const _lines = [
  _TerminalLine.command('git clone https://$_repositoryUrl'),
  _TerminalLine.output('Cloning into open-repset…'),
  _TerminalLine.command('cd open-repset && flutter pub get'),
  _TerminalLine.output('Got dependencies.'),
  _TerminalLine.command('flutter run'),
  _TerminalLine.output('Launching lib/main.dart…'),
  _TerminalLine.comment('# Runs on the built-in demo exercise library.'),
  _TerminalLine.comment('# No keys, no telemetry, no account required.'),
  _TerminalLine.comment('# Point it at your own catalogue and services'),
  _TerminalLine.comment('# with --dart-define. See the README.'),
];

enum _LineKind { command, output, comment }

class _TerminalLine {
  const _TerminalLine.command(this.text) : kind = _LineKind.command;
  const _TerminalLine.output(this.text) : kind = _LineKind.output;
  const _TerminalLine.comment(this.text) : kind = _LineKind.comment;

  final String text;
  final _LineKind kind;
}

/// The developer path: what this project is and how to run it yourself.
class OnboardingDeveloperPage extends StatefulWidget {
  const OnboardingDeveloperPage({
    super.key,
    required this.name,
    required this.onContinue,
  });

  final String name;
  final VoidCallback onContinue;

  @override
  State<OnboardingDeveloperPage> createState() =>
      _OnboardingDeveloperPageState();
}

class _OnboardingDeveloperPageState extends State<OnboardingDeveloperPage> {
  Timer? _timer;
  int _visible = 0;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 260), (timer) {
      if (!mounted) return timer.cancel();
      if (_visible >= _lines.length) return timer.cancel();
      setState(() => _visible++);
    });
  }

  /// Tapping the terminal reveals the rest at once. Nobody should have to sit
  /// through an animation to read something they already understand.
  void _revealAll() {
    if (_visible >= _lines.length) return;
    _timer?.cancel();
    setState(() => _visible = _lines.length);
  }

  Future<void> _copyClone() async {
    await Clipboard.setData(
      const ClipboardData(text: 'git clone https://$_repositoryUrl'),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.name.isEmpty
        ? 'Welcome, developer.'
        : 'Welcome, ${widget.name}.';
    return OnboardingScaffold(
      footer: OnboardingButton(
        key: const Key('onboarding-developer-continue'),
        label: 'Got it',
        icon: Icons.arrow_forward_rounded,
        onPressed: widget.onContinue,
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
              'The whole app is public. Read it, fork it, run it against your '
              'own services — no keys of ours required.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          RepSetEntrance(
            delay: const Duration(milliseconds: 110),
            child: _Terminal(
              lines: _lines.take(_visible).toList(growable: false),
              typing: _visible < _lines.length,
              onTap: _revealAll,
            ),
          ),
          const SizedBox(height: 14),
          RepSetEntrance(
            delay: const Duration(milliseconds: 150),
            child: _CopyRow(copied: _copied, onCopy: _copyClone),
          ),
        ],
      ),
    );
  }
}

class _Terminal extends StatelessWidget {
  const _Terminal({
    required this.lines,
    required this.typing,
    required this.onTap,
  });

  static const _shell = Color(0xff101208);
  static const _dim = Color(0xff7f8a72);

  final List<_TerminalLine> lines;
  final bool typing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      // Reserves the finished height so the card does not grow line by line
      // and shove the rest of the screen around while it types.
      constraints: const BoxConstraints(minHeight: 268),
      decoration: BoxDecoration(
        color: _shell,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onboardingAccent.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TerminalBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines) ...[
                  _TerminalRow(line: line),
                  const SizedBox(height: 5),
                ],
                if (typing) const _Caret(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TerminalBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: onboardingAccent.withValues(alpha: .18)),
      ),
    ),
    child: Row(
      children: [
        for (final color in const [
          Color(0xff4a4f42),
          Color(0xff4a4f42),
          onboardingAccent,
        ]) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        const SizedBox(width: 6),
        const Text(
          'open-repset — zsh',
          style: TextStyle(
            color: _Terminal._dim,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

class _TerminalRow extends StatelessWidget {
  const _TerminalRow({required this.line});

  final _TerminalLine line;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: switch (line.kind) {
        _LineKind.command => const Color(0xfff3f5ef),
        _LineKind.output => _Terminal._dim,
        _LineKind.comment => onboardingAccent.withValues(alpha: .85),
      },
    );
    return RepSetEntrance(
      key: ValueKey(line.text),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.kind == _LineKind.command) ...[
            const Text(
              '\$',
              style: TextStyle(
                color: onboardingAccent,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Expanded(child: Text(line.text, style: style)),
        ],
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _blink.repeat();
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _blink.drive(
      TweenSequence([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 1),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
      ]),
    ),
    child: Container(width: 8, height: 14, color: onboardingAccent),
  );
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.copied, required this.onCopy});

  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => RepSetPress(
    scale: .98,
    child: GestureDetector(
      key: const Key('onboarding-copy-clone'),
      onTap: onCopy,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
              color: onboardingAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                copied ? 'Copied to clipboard' : _repositoryUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
