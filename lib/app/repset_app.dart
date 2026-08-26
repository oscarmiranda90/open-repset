import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/account/account_service.dart';
import '../core/account/max_access.dart';
import '../core/ads/official_ads_service.dart';
import '../data/demo_exercise_repository.dart';
import '../data/http_workout_planner.dart';
import '../data/memory_body_weight_repository.dart';
import '../data/memory_muscle_coverage_repository.dart';
import '../data/memory_training_analytics_repository.dart';
import '../data/memory_workout_repository.dart';
import '../domain/app_preferences.dart';
import '../domain/body_weight.dart';
import '../domain/exercise_repository.dart';
import '../domain/muscle_map.dart';
import '../domain/relative_strength_service.dart';
import '../domain/training_analytics.dart';
import '../domain/workout_planner.dart';
import '../domain/workout_repository.dart';
import '../features/home/home_screen.dart';
import '../features/home/session_planner_bloc.dart';
import '../features/onboarding/onboarding_gate.dart';
import '../features/history/history_bloc.dart';
import '../features/library/library_bloc.dart';
import '../features/progress/body_weight_bloc.dart';
import '../features/progress/progress_bloc.dart';
import '../features/you/muscle_coverage_bloc.dart';
import '../features/templates/template_bloc.dart';
import '../features/workout/workout_bloc.dart';

class RepSetApp extends StatelessWidget {
  const RepSetApp({
    super.key,
    this.exerciseRepository,
    this.workoutRepository,
    this.analyticsRepository,
    this.bodyWeightRepository,
    this.muscleCoverageRepository,
    this.workoutPlanner,
    this.accountService,
    this.appPreferences,
    this.adsService,
  });

  final ExerciseRepository? exerciseRepository;
  final WorkoutRepository? workoutRepository;

  /// Falls back to the in-memory implementation so the app still runs when no
  /// database is wired up.
  final TrainingAnalyticsRepository? analyticsRepository;

  final BodyWeightRepository? bodyWeightRepository;
  final MuscleCoverageRepository? muscleCoverageRepository;

  /// Reports itself as unconfigured unless a build supplies a planning origin,
  /// which keeps the prompt surface hidden in community builds.
  final WorkoutPlanner? workoutPlanner;
  final AccountService? accountService;

  /// Falls back to an in-memory store, which makes onboarding reappear on the
  /// next launch rather than silently swallowing the answers.
  final AppPreferencesRepository? appPreferences;
  final OfficialAdsService? adsService;

  @override
  Widget build(BuildContext context) {
    final repository = workoutRepository ?? MemoryWorkoutRepository();
    final analytics =
        analyticsRepository ?? MemoryTrainingAnalyticsRepository(repository);
    final bodyWeight = bodyWeightRepository ?? MemoryBodyWeightRepository();
    final exercises = exerciseRepository ?? DemoExerciseRepository();
    final muscleCoverage =
        muscleCoverageRepository ??
        MemoryMuscleCoverageRepository(repository, exercises);
    final planner =
        workoutPlanner ??
        HttpWorkoutPlanner(
          // The service verifies this token and decides for itself whether the
          // caller may plan a session.
          tokenProvider: () async {
            // A refused or failed token must read as "not signed in", so the
            // service answers with its own sign-in prompt rather than the app
            // failing with an unexplained error.
            try {
              return await accountService?.currentUser?.getIdToken();
            } catch (_) {
              return null;
            }
          },
        );
    // Resolved once and shared: the home banner, the prompt field and the
    // settings card all ask the same question.
    final maxAccess = MaxAccessCubit(accountService?.purchases)..refresh();
    final preferences = appPreferences ?? MemoryAppPreferencesRepository();
    // Exposed to the widget tree as well: the finished-workout summary reads
    // history directly, before the bloc persists the session that would
    // otherwise become part of its own baseline.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WorkoutRepository>.value(value: repository),
        RepositoryProvider<TrainingAnalyticsRepository>.value(value: analytics),
        RepositoryProvider<BodyWeightRepository>.value(value: bodyWeight),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<MaxAccessCubit>.value(value: maxAccess),
          BlocProvider(
            create: (_) => LibraryBloc(exercises)..add(const LibraryStarted()),
          ),
          BlocProvider(
            create: (_) =>
                TemplateBloc(repository)..add(const TemplatesLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                WorkoutBloc(repository)..add(const WorkoutRestored()),
          ),
          BlocProvider(
            create: (_) => HistoryBloc(repository)..add(const HistoryLoaded()),
          ),
          BlocProvider(
            create: (_) => ProgressBloc(
              analytics,
              RelativeStrengthService(analytics, bodyWeight),
            )..add(const ProgressLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                BodyWeightBloc(bodyWeight)..add(const BodyWeightRequested()),
          ),
          BlocProvider(
            create: (_) =>
                MuscleCoverageBloc(muscleCoverage)
                  ..add(const MuscleCoverageRequested()),
          ),
          BlocProvider(create: (_) => SessionPlannerBloc(planner)),
        ],
        child: MaterialApp(
          title: 'RepSet',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: OnboardingGate(
            preferences: preferences,
            accountService: accountService,
            child: HomeScreen(
              accountService: accountService,
              adsService: adsService,
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    const accent = Color(0xffd7ff4f);
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: dark ? const Color(0xff151714) : const Color(0xfff3f5ef),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'SF Pro Display',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: dark ? const Color(0xfff3f5ef) : const Color(0xff171914),
        displayColor: dark ? const Color(0xfff3f5ef) : const Color(0xff171914),
      ),
    );
  }
}
