import 'package:flutter/material.dart';

import 'adapted_animations.dart';

class AnimationLabPage extends StatefulWidget {
  const AnimationLabPage({super.key});

  @override
  State<AnimationLabPage> createState() => _AnimationLabPageState();
}

class _AnimationLabPageState extends State<AnimationLabPage> {
  final Map<String, int> _triggers = {};

  int _trigger(String id) => _triggers[id] ?? 0;

  void _replay(String id) {
    setState(() => _triggers[id] = _trigger(id) + 1);
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const Key('animation-lab'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'DEV / MOTION',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  const _DebugBadge(),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Animation\nLab.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: .92,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Native Flutter studies adapted for RepSet. Tap any card to replay it.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        sliver: SliverList.list(
          children: [
            _DemoCard(
              title: 'Set complete',
              description: 'Overshoot and settle for a completed set.',
              useCase: 'Workout set checkbox',
              onReplay: () => _replay('pop'),
              child: CompletionPop(
                trigger: _trigger('pop'),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xffd7ff4f),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 42,
                    color: Color(0xff171914),
                  ),
                ),
              ),
            ),
            _DemoCard(
              title: 'Split gate reveal',
              description:
                  'Two weighted doors part to expose a changed workout state.',
              useCase: 'Store confirmation or exercise detail',
              onReplay: () => _replay('split-gate'),
              child: SizedBox(
                width: 220,
                height: 104,
                child: SplitGateReveal(
                  trigger: _trigger('split-gate'),
                  child: const _SummaryPreview(),
                ),
              ),
            ),
            _DemoCard(
              title: 'Horizontal shutter slide',
              description:
                  'Slats cross the surface, then pull the next state into focus.',
              useCase: 'Changing workout views',
              onReplay: () => _replay('horizontal-shutter'),
              child: SizedBox(
                width: 220,
                height: 104,
                child: HorizontalShutterSlide(
                  trigger: _trigger('horizontal-shutter'),
                ),
              ),
            ),
            _DemoCard(
              title: 'Receipt ticker print',
              description:
                  'A compact receipt feeds out with a mechanical paper stop.',
              useCase: 'Workout complete summary',
              onReplay: () => _replay('receipt'),
              child: ReceiptTickerPrint(trigger: _trigger('receipt')),
            ),
            _DemoCard(
              title: 'Circuit trace draw',
              description:
                  'A signal travels the route before the value becomes live.',
              useCase: 'Sync and calculation feedback',
              onReplay: () => _replay('circuit'),
              child: CircuitTraceDraw(trigger: _trigger('circuit')),
            ),
            _DemoCard(
              title: 'Scroll canvas unroll',
              description: 'A training surface unrolls from its leading edge.',
              useCase: 'Opening an active plan',
              onReplay: () => _replay('canvas'),
              child: ScrollCanvasUnroll(trigger: _trigger('canvas')),
            ),
            _DemoCard(
              title: 'Kinetic tension capsule',
              description:
                  'A capsule stretches, overshoots, and holds under tension.',
              useCase: 'Rest timer and status changes',
              onReplay: () => _replay('capsule'),
              child: KineticTensionCapsule(trigger: _trigger('capsule')),
            ),
            _DemoCard(
              title: 'Card deck fan cascade',
              description:
                  'Training cards fan outward in a quick, ordered cascade.',
              useCase: 'Exercise selection',
              onReplay: () => _replay('deck'),
              child: CardDeckFanCascade(trigger: _trigger('deck')),
            ),
            _DemoCard(
              title: 'Matrix grid loader',
              description:
                  'A signal scans a matrix instead of spinning in place.',
              useCase: 'Offline sync and imports',
              onReplay: () => _replay('matrix'),
              child: MatrixGridLoader(trigger: _trigger('matrix')),
            ),
            _DemoCard(
              title: 'Directional reveal',
              description: 'A fast mask and accent sweep with a decisive edge.',
              useCase: 'Exercise added confirmation',
              onReplay: () => _replay('reveal'),
              child: SizedBox(
                width: 210,
                height: 82,
                child: DirectionalReveal(
                  trigger: _trigger('reveal'),
                  child: const _ExercisePreview(),
                ),
              ),
            ),
            _DemoCard(
              title: 'Set domino',
              description: 'Staggered rotation turns a list into one motion.',
              useCase: 'Exercise set progression',
              onReplay: () => _replay('domino'),
              child: DominoSets(trigger: _trigger('domino')),
            ),
            _DemoCard(
              title: 'Rest timer alert',
              description: 'Arrival, recoil, and a compact bell-like shake.',
              useCase: 'Rest period finished',
              onReplay: () => _replay('bell'),
              child: RestBell(trigger: _trigger('bell')),
            ),
            _DemoCard(
              title: 'Success burst',
              description: 'Particles and a restrained elastic confirmation.',
              useCase: 'Workout or personal record',
              onReplay: () => _replay('burst'),
              child: SuccessBurst(trigger: _trigger('burst')),
            ),
            _DemoCard(
              title: 'Summary shutter',
              description:
                  'Staggered panels conceal and reveal changed content.',
              useCase: 'Finished-workout summary',
              onReplay: () => _replay('shutter'),
              child: SizedBox(
                width: 220,
                height: 110,
                child: ShutterReveal(
                  trigger: _trigger('shutter'),
                  child: const _SummaryPreview(),
                ),
              ),
            ),
            _DemoCard(
              title: 'Rolling plate',
              description: 'A weight plate rolls in and settles under tension.',
              useCase: 'Adding weight or loading a workout',
              onReplay: () => _replay('rolling'),
              child: RollingPlate(trigger: _trigger('rolling')),
            ),
            _DemoCard(
              title: 'Brake slide',
              description:
                  'Fast lateral arrival with a compact braking recoil.',
              useCase: 'Add-set action or compact toast',
              onReplay: () => _replay('brake'),
              child: BrakeSlide(trigger: _trigger('brake')),
            ),
            _DemoCard(
              title: 'Record ripple',
              description:
                  'Concentric energy rings celebrate without confetti.',
              useCase: 'Personal record indicator',
              onReplay: () => _replay('ripple'),
              child: RecordRipple(trigger: _trigger('ripple')),
            ),
            _DemoCard(
              title: 'Metric flip',
              description:
                  'A physical flip makes a changed value unmistakable.',
              useCase: 'Weight, repetitions, or unit changes',
              onReplay: () => _replay('flip'),
              child: FlipMetric(trigger: _trigger('flip')),
            ),
            _DemoCard(
              title: 'Folding sets',
              description: 'Rows unfold in sequence with shallow 3D depth.',
              useCase: 'Opening an exercise in active workout',
              onReplay: () => _replay('fold'),
              child: FoldingSets(trigger: _trigger('fold')),
            ),
            _DemoCard(
              title: 'Growing chart',
              description:
                  'Staggered bars overshoot before reaching their data.',
              useCase: 'Progress and workout volume charts',
              onReplay: () => _replay('chart'),
              child: GrowingChart(trigger: _trigger('chart')),
            ),
            _DemoCard(
              title: 'Orbit loader',
              description: 'Two offset masses make loading feel mechanical.',
              useCase: 'Short sync or calculation states',
              onReplay: () => _replay('orbit'),
              child: OrbitLoader(trigger: _trigger('orbit')),
            ),
            _DemoCard(
              title: 'Curtain reveal',
              description: 'Paired panels open around a completed result.',
              useCase: 'Workout summary or unlocked milestone',
              onReplay: () => _replay('curtain'),
              child: SizedBox(
                width: 220,
                height: 110,
                child: CurtainReveal(
                  trigger: _trigger('curtain'),
                  child: const _SummaryPreview(),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.description,
    required this.useCase,
    required this.onReplay,
    required this.child,
  });

  final String title;
  final String description;
  final String useCase;
  final VoidCallback onReplay;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onReplay,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    key: Key(
                      'replay-${title.toLowerCase().replaceAll(' ', '-')}',
                    ),
                    tooltip: 'Replay $title',
                    onPressed: onReplay,
                    icon: const Icon(Icons.replay_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: child,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.north_east_rounded, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      useCase,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _DebugBadge extends StatelessWidget {
  const _DebugBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xffd7ff4f),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'DEBUG ONLY',
      style: TextStyle(
        color: Color(0xff171914),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        CircleAvatar(child: Icon(Icons.fitness_center, size: 18)),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bench press',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Added to workout',
                maxLines: 1,
                style: TextStyle(fontSize: 11, height: 1.1),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryPreview extends StatelessWidget {
  const _SummaryPreview();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '4,820 kg',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            'WORKOUT VOLUME',
            style: TextStyle(fontSize: 10, letterSpacing: 1),
          ),
        ],
      ),
    ),
  );
}
