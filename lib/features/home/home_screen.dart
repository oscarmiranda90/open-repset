import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/account/account_service.dart';
import '../../core/account/max_access.dart';
import '../../core/ads/official_ads_service.dart';
import '../../core/ads/official_banner_slot.dart';
import '../../core/motion/repset_motion.dart';
import '../../domain/workout_session.dart';
import '../history/history_page.dart';
import '../history/history_bloc.dart';
import '../library/exercise_library_page.dart';
import '../progress/progress_bloc.dart';
import '../paywall/max_paywall_page.dart';
import '../progress/progress_page.dart';
import '../settings/settings_page.dart';
import '../you/muscle_coverage_bloc.dart';
import '../you/you_page.dart';
import '../templates/template_bloc.dart';
import '../templates/templates_page.dart';
import '../workout/active_workout_page.dart';
import '../workout/workout_bloc.dart';
import '../workout/workout_elapsed_time.dart';
import 'dot_pattern.dart';
import 'home_tiles.dart';
import 'macos_spring_dock.dart';
import 'train_prompt_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.accountService, this.adsService});

  final AccountService? accountService;
  final OfficialAdsService? adsService;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeTab _tab = _HomeTab.today;
  bool _showWorkout = false;
  int _workoutRevealTrigger = 0;
  int _lastCelebratedCompletion = 0;

  void _openWorkout() => setState(() {
    _showWorkout = true;
    _workoutRevealTrigger++;
  });

  void _returnHome() => setState(() {
    _showWorkout = false;
    _tab = _HomeTab.today;
  });

  void _goToTab(_HomeTab tab) => setState(() {
    _tab = tab;
    _showWorkout = false;
  });

  /// Offers the post-workout interstitial, if this build shows ads at all.
  ///
  /// The service decides eligibility on its own — subscription, consent,
  /// cooldown, how many sessions this person has finished — so the only thing
  /// asked here is that the moment has arrived.
  void _maybeShowCompletionAd() {
    final ads = widget.adsService;
    if (ads == null || !mounted) return;
    // History was only just asked to reload, so its list still predates the
    // session that triggered this. The one that finished is counted here.
    final history = context.read<HistoryBloc>().state.sessions.length + 1;
    ads.maybeShowCompletedWorkoutInterstitial(
      completedWorkoutCount: history,
      hasMaxAccess: context.read<MaxAccessCubit>().state.isActive,
    );
  }

  Future<void> _openPaywall() async {
    final purchases = widget.accountService?.purchases;
    if (purchases == null) return;
    if (!await requireSignInForMax(context, widget.accountService) ||
        !mounted) {
      return;
    }
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MaxPaywallPage(
          purchases: purchases,
          account: widget.accountService,
        ),
      ),
    );
    if ((subscribed ?? false) && mounted) {
      await context.read<MaxAccessCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WorkoutBloc, WorkoutState>(
    listenWhen: (previous, current) =>
        previous.hasActiveSession != current.hasActiveSession ||
        previous.completionSequence != current.completionSequence,
    listener: (context, workout) {
      if (workout.hasActiveSession) {
        _openWorkout();
      } else {
        // A finished session changes both surfaces, so both reload.
        context.read<HistoryBloc>().add(const HistoryLoaded());
        context.read<ProgressBloc>().add(const ProgressLoaded());
        context.read<MuscleCoverageBloc>().add(const MuscleCoverageRequested());
        setState(() {
          _showWorkout = false;
          _tab = _HomeTab.today;
        });
        // Only a finished session earns an interstitial. Discarding one is
        // already a small disappointment, and an ad on top of it would read as
        // a punishment.
        if (workout.completionSequence > _lastCelebratedCompletion) {
          _lastCelebratedCompletion = workout.completionSequence;
          _maybeShowCompletionAd();
        }
      }
    },
    builder: (context, workout) {
      final tabs = [
        _HomeTabSpec(
          tab: _HomeTab.today,
          page: _TodayPage(
            onOpenWorkout: _openWorkout,
            onOpenTemplates: () => _goToTab(_HomeTab.templates),
            onOpenProgress: () => _goToTab(_HomeTab.progress),
            onGoMax: _openPaywall,
          ),
          destination: const NavigationDestination(
            key: Key('today-tab'),
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Today',
          ),
        ),
        _HomeTabSpec(
          tab: _HomeTab.templates,
          page: TemplatesPage(onBack: _returnHome),
          destination: const NavigationDestination(
            key: Key('templates-tab'),
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Templates',
          ),
        ),
        const _HomeTabSpec(
          tab: _HomeTab.history,
          page: HistoryPage(),
          destination: NavigationDestination(
            key: Key('history-tab'),
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ),
        const _HomeTabSpec(
          tab: _HomeTab.library,
          page: ExerciseLibraryPage(),
          destination: NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
        ),
        _HomeTabSpec(
          tab: _HomeTab.progress,
          page: ProgressPage(onBack: _returnHome),
          destination: const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
        ),
        _HomeTabSpec(
          tab: _HomeTab.you,
          page: YouPage(accountService: widget.accountService),
          destination: NavigationDestination(
            key: Key('you-tab'),
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'You',
          ),
        ),
        _HomeTabSpec(
          tab: _HomeTab.settings,
          page: SettingsPage(
            accountService: widget.accountService,
            adsService: widget.adsService,
          ),
          destination: const NavigationDestination(
            key: Key('settings-tab'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ),
      ];
      final selectedIndex = tabs.indexWhere((item) => item.tab == _tab);
      final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
      // Templates and Progress are reachable from the home tiles, so the dock
      // stays down to the surfaces that are not one tap away already.
      final dockTabs = tabs
          .where(
            (item) =>
                item.tab != _HomeTab.templates && item.tab != _HomeTab.progress,
          )
          .toList(growable: false);
      final dockIndex = dockTabs.indexWhere((item) => item.tab == _tab);
      final showingWorkout = _showWorkout && workout.hasActiveSession;
      final max = context.watch<MaxAccessCubit>().state;
      final monetizationAllowed =
          widget.adsService?.isTestMode == true ||
          (max.isAvailable && max.hasResolved && !max.isActive);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.adsService?.setMonetizationAllowed(monetizationAllowed);
        }
      });
      final showBanner =
          widget.adsService != null &&
          monetizationAllowed &&
          !workout.hasActiveSession &&
          const {
            _HomeTab.today,
            _HomeTab.history,
            _HomeTab.library,
            _HomeTab.you,
          }.contains(_tab);
      return Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: showingWorkout ? 1 : 0,
            children: [
              TickerMode(
                enabled: !showingWorkout,
                child: IndexedStack(
                  index: safeIndex,
                  // IndexedStack keeps every tab mounted, and it does not gate
                  // tickers on its own — without this, off-screen pages keep
                  // animating forever.
                  children: List.generate(
                    tabs.length,
                    (index) => TickerMode(
                      enabled: index == safeIndex,
                      child: tabs[index].page,
                    ),
                    growable: false,
                  ),
                ),
              ),
              RepSetDirectionalReveal(
                trigger: _workoutRevealTrigger,
                child: ActiveWorkoutPage(
                  onBack: _returnHome,
                  adsService: widget.adsService,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: showingWorkout
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showBanner) OfficialBannerSlot(ads: widget.adsService!),
                  if (workout.hasActiveSession && !_showWorkout)
                    _ActiveWorkoutDock(
                      session: workout.session!,
                      onContinue: _openWorkout,
                    ),
                  MacosSpringDock(
                    selectedIndex: dockIndex < 0 ? 0 : dockIndex,
                    items: List.generate(dockTabs.length, (index) {
                      final destination = dockTabs[index].destination;
                      return DockItem(
                        key: destination.key,
                        icon: (destination.icon as Icon).icon!,
                        activeIcon: (destination.selectedIcon as Icon).icon!,
                        label: destination.label,
                        onTap: () => _goToTab(dockTabs[index].tab),
                      );
                    }),
                  ),
                ],
              ),
      );
    },
  );
}

enum _HomeTab { today, library, templates, history, progress, you, settings }

class _HomeTabSpec {
  const _HomeTabSpec({
    required this.tab,
    required this.page,
    required this.destination,
  });

  final _HomeTab tab;
  final Widget page;
  final NavigationDestination destination;
}

class _ActiveWorkoutDock extends StatelessWidget {
  const _ActiveWorkoutDock({required this.session, required this.onContinue});

  final WorkoutSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => RepSetEntrance(
    key: const Key('active-workout-dock'),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onContinue,
        child: Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(16, 7, 10, 7),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                size: 18,
                color: Color(0xffd7ff4f),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        WorkoutElapsedTime(
                          key: const Key('workout-dock-elapsed'),
                          startedAt: session.startedAt,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  ${session.completedSetCount} sets',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              RepSetPress(
                scale: .95,
                child: TextButton(
                  key: const Key('continue-workout-button'),
                  onPressed: onContinue,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffd7ff4f),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 17),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({
    required this.onOpenWorkout,
    required this.onOpenTemplates,
    required this.onOpenProgress,
    required this.onGoMax,
  });

  final VoidCallback onOpenWorkout;
  final VoidCallback onOpenTemplates;
  final VoidCallback onOpenProgress;
  final VoidCallback onGoMax;

  @override
  Widget build(BuildContext context) => BlocBuilder<WorkoutBloc, WorkoutState>(
    builder: (context, workout) {
      // Tapping anywhere off the prompt field dismisses the keyboard, which is
      // what a tap on empty space means everywhere else on the platform.
      // `translucent` lets the tap through to the widgets underneath, so the
      // dismissal never costs the user the control they were reaching for.
      // Until the first entitlement lookup lands, neither surface commits:
      // flashing an upsell at a subscriber is worse than a moment of nothing.
      final maxAccess = context.watch<MaxAccessCubit>().state;
      final offerMax = maxAccess.shouldOffer;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(child: DotPattern()),
            _PageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Topline(
                    label: 'REPSET',
                    showBrandMark: true,
                    onGoMax: offerMax ? onGoMax : null,
                    hasMax: maxAccess.isActive,
                  ),
                  // The prompt is the page's opening move, so it gets room to
                  // breathe after the wordmark rather than sitting on top of it.
                  const SizedBox(height: 34),
                  // Only renders where a planning backend is configured; it
                  // takes no space otherwise, spacing included. During a
                  // session it stays visible but inert: planning would start a
                  // second workout, and a surface that vanishes mid-training
                  // reads as something broken rather than something resolved.
                  TrainPromptSection(
                    onUpgrade: workout.hasActiveSession || !offerMax
                        ? null
                        : onGoMax,
                    disabledLabel: workout.hasActiveSession
                        ? 'Finish your session to plan another'
                        : null,
                  ),
                  // A wider gap than the one inside either block, so the prompt
                  // and the session tiles read as two decisions rather than one
                  // crowded stack.
                  const SizedBox(height: 14),
                  _SessionGrid(
                    workout: workout,
                    onOpenWorkout: onOpenWorkout,
                    onOpenTemplates: onOpenTemplates,
                    onOpenProgress: onOpenProgress,
                  ),
                  if (!workout.hasActiveSession) ...[
                    const SizedBox(height: 28),
                    const _TemplateQuickStart(),
                  ],
                  const SizedBox(height: 30),
                  Text(
                    'Last session',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _LastSession(),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Asymmetric bento: the session action owns the left column at full height,
/// while Templates and Progress stack down the right. On narrow screens the
/// two secondary tiles fall below so nothing is squeezed under ~150px.
class _SessionGrid extends StatelessWidget {
  const _SessionGrid({
    required this.workout,
    required this.onOpenWorkout,
    required this.onOpenTemplates,
    required this.onOpenProgress,
  });

  final WorkoutState workout;
  final VoidCallback onOpenWorkout;
  final VoidCallback onOpenTemplates;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    final active = workout.hasActiveSession;
    final dailyLine = _dailyTrainingLine(DateTime.now());
    final primary = active
        ? _ActiveSessionTile(
            session: workout.session!,
            onPressed: workout.isLoading ? null : onOpenWorkout,
          )
        : PrimarySessionTile(
            eyebrow: dailyLine.source,
            headline: dailyLine.text,
            actionLabel: workout.isLoading ? 'Restoring…' : 'Begin training',
            actionIcon: Icons.bolt_rounded,
            onPressed: workout.isLoading
                ? null
                : () => context.read<WorkoutBloc>().add(const WorkoutStarted()),
          );

    final templates = BlocBuilder<TemplateBloc, TemplateState>(
      builder: (context, state) {
        final count = state.templates.length;
        return HomeNavTile(
          key: const Key('home-templates-tile'),
          compact: true,
          icon: Icons.bookmark_rounded,
          label: 'Templates',
          detail: count == 0
              ? 'Save a session to reuse'
              : '$count saved routine${count == 1 ? '' : 's'}',
          trailingBadge: count == 0 ? null : '$count',
          onTap: onOpenTemplates,
        );
      },
    );

    final progress = HomeNavTile(
      key: const Key('home-progress-tile'),
      compact: true,
      icon: Icons.insights_rounded,
      label: 'Progress',
      detail: active
          ? '${workout.session!.completedSetCount} sets logged today'
          : 'Volume and best sets',
      onTap: onOpenProgress,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below this width the right column cannot hold two legible tiles,
        // so the secondary pair drops beneath the primary action instead.
        if (constraints.maxWidth < 340) {
          return Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 224),
                child: primary,
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: templates),
                    const SizedBox(width: 12),
                    Expanded(child: progress),
                  ],
                ),
              ),
            ],
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 224),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 68, child: primary),
                const SizedBox(width: 12),
                Expanded(
                  flex: 32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: templates),
                      const SizedBox(height: 12),
                      Expanded(child: progress),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DailyTrainingLine {
  const _DailyTrainingLine({required this.text, required this.source});

  final String text;
  final String source;
}

const _dailyTrainingLines = [
  _DailyTrainingLine(
    text: 'The impediment to action advances action.',
    source: 'MARCUS AURELIUS · MEDITATIONS',
  ),
  _DailyTrainingLine(
    text: 'You have power over your mind — not outside events.',
    source: 'MARCUS AURELIUS · MEDITATIONS',
  ),
  _DailyTrainingLine(
    text: 'He who has a why can bear almost any how.',
    source: 'FRIEDRICH NIETZSCHE · TWILIGHT OF THE IDOLS',
  ),
  _DailyTrainingLine(
    text: 'The last three or four reps are what make the muscle grow.',
    source: 'ARNOLD SCHWARZENEGGER',
  ),
  _DailyTrainingLine(
    text: 'Don’t count the days. Make the days count.',
    source: 'MUHAMMAD ALI',
  ),
  _DailyTrainingLine(
    text: 'The successful warrior is the average man, with laser-like focus.',
    source: 'BRUCE LEE',
  ),
  _DailyTrainingLine(
    text: 'It is not the mountains we conquer, but ourselves.',
    source: 'EDMUND HILLARY',
  ),
  _DailyTrainingLine(
    text: 'We suffer more often in imagination than in reality.',
    source: 'SENECA · LETTERS FROM A STOIC',
  ),
  _DailyTrainingLine(
    text: 'What matters is what you do with the time that is given to you.',
    source: 'J.R.R. TOLKIEN · THE LORD OF THE RINGS',
  ),
  _DailyTrainingLine(
    text: 'The man who moves a mountain begins by carrying away small stones.',
    source: 'CONFUCIUS',
  ),
];

_DailyTrainingLine _dailyTrainingLine(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  final dayIndex = day.difference(DateTime(2024)).inDays;
  return _dailyTrainingLines[dayIndex % _dailyTrainingLines.length];
}

class _ActiveSessionTile extends StatelessWidget {
  const _ActiveSessionTile({required this.session, required this.onPressed});

  final WorkoutSession session;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exercises = session.exercises;
    final visibleExercises = exercises.take(3).toList(growable: false);
    final remainingExerciseCount = exercises.length - visibleExercises.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
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
                      'WORKOUT IN PROGRESS',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: .72),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _LiveSessionTime(startedAt: session.startedAt),
            ],
          ),
          const SizedBox(height: 14),
          if (exercises.isEmpty)
            Text(
              'Add your first exercise when you’re ready.',
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: .72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in visibleExercises.asMap().entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RepSetFoldIn(
                      key: ValueKey('active-exercise-${entry.value.id}'),
                      child: _ActiveExerciseMiniTile(exercise: entry.value),
                    ),
                  ),
                if (remainingExerciseCount > 0)
                  RepSetFoldIn(
                    key: const ValueKey('active-exercise-more'),
                    child: _ActiveExerciseMiniTile(
                      label: '+$remainingExerciseCount more',
                      icon: Icons.add_rounded,
                    ),
                  ),
              ],
            ),
          const Spacer(),
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
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),
              label: const Text(
                'Resume',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSessionTime extends StatelessWidget {
  const _LiveSessionTime({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'ELAPSED',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: .7),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 2),
        WorkoutElapsedTime(
          startedAt: startedAt,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 17,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -.7,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _ActiveExerciseMiniTile extends StatelessWidget {
  const _ActiveExerciseMiniTile({this.exercise, this.label, this.icon});

  final WorkoutExercise? exercise;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final completedSets = exercise?.sets.where((set) => set.isCompleted).length;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.fitness_center_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 12,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                label ?? exercise!.name,
                maxLines: 1,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (exercise != null) ...[
            const SizedBox(width: 6),
            Text(
              '$completedSets/${exercise!.sets.length}',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: .68),
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateQuickStart extends StatelessWidget {
  const _TemplateQuickStart();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TemplateBloc, TemplateState>(
        builder: (context, state) {
          if (state.templates.isEmpty) return const SizedBox.shrink();
          final favorites = state.templates.where(
            (template) => template.isFavorite,
          );
          final templates = (favorites.isEmpty ? state.templates : favorites)
              .take(2)
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                favorites.isEmpty ? 'Recent templates' : 'Favorite templates',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...templates.map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        template.isFavorite
                            ? Icons.star_rounded
                            : Icons.bookmark_rounded,
                        color: const Color(0xffd7ff4f),
                      ),
                      title: Text(
                        template.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('${template.exercises.length} exercises'),
                      trailing: IconButton(
                        key: Key('start-template-${template.id}'),
                        tooltip: 'Start ${template.title}',
                        onPressed: () => context.read<WorkoutBloc>().add(
                          WorkoutStartedFromTemplate(template),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: child,
    ),
  );
}

class _Topline extends StatelessWidget {
  const _Topline({
    required this.label,
    this.showBrandMark = false,
    this.onGoMax,
    this.hasMax = false,
  });

  final String label;

  /// Only the Today page carries the mark; repeating it on every tab would
  /// turn identity into wallpaper.
  final bool showBrandMark;

  /// When set, the topline offers Max in place of the status dot.
  final VoidCallback? onGoMax;

  /// Marks the status dot as a subscriber's, rather than a plain indicator.
  final bool hasMax;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (showBrandMark) ...[
        const RepSetBrandMark(size: 32),
        const SizedBox(width: 11),
      ],
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      const Spacer(),
      if (onGoMax != null)
        _GoMaxBadge(onTap: onGoMax!)
      else if (hasMax)
        const _MaxStatus()
      else
        const Icon(Icons.circle, size: 10, color: Color(0xffd7ff4f)),
    ],
  );
}

/// The subscriber's mark: the same status dot, named and breathing.
///
/// It replaces nothing and asks for nothing — a subscriber has already decided.
/// The pulse is slow enough to read as presence rather than as a notification
/// wanting attention.
class _MaxStatus extends StatefulWidget {
  const _MaxStatus();

  @override
  State<_MaxStatus> createState() => _MaxStatusState();
}

class _MaxStatusState extends State<_MaxStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A permanent loop paints every frame this page is up, so it only runs
    // where the platform allows motion.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_breath.isAnimating) _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'MAX',
        style: TextStyle(
          color: const Color(0xffd7ff4f).withValues(alpha: .9),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(width: 7),
      FadeTransition(
        opacity: _breath.drive(Tween(begin: .45, end: 1)),
        child: const Icon(Icons.circle, size: 10, color: Color(0xffd7ff4f)),
      ),
    ],
  );
}

/// The upsell that sits where the status dot normally does.
///
/// It replaces the dot rather than crowding in beside it: the topline is a
/// single quiet line, and two competing marks would make it noise.
class _GoMaxBadge extends StatelessWidget {
  const _GoMaxBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RepSetPress(
    scale: .94,
    child: GestureDetector(
      key: const Key('go-max-badge'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
        decoration: BoxDecoration(
          color: const Color(0xffd7ff4f).withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xffd7ff4f).withValues(alpha: .5),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No ads? Go Max!',
              style: TextStyle(
                color: Color(0xffd7ff4f),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .2,
              ),
            ),
            SizedBox(width: 1),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Color(0xffd7ff4f),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LastSession extends StatelessWidget {
  const _LastSession();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.fitness_center),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lower body', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('45 min  •  12 working sets'),
            ],
          ),
        ),
        Icon(Icons.chevron_right),
      ],
    ),
  );
}
