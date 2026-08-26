/// How someone answered the onboarding, which shapes what the app says to them
/// afterwards rather than what it lets them do. Both paths get the same app.
enum TrainerPath {
  developer,
  lifter;

  static TrainerPath? parse(String? value) => switch (value) {
    'developer' => TrainerPath.developer,
    'lifter' => TrainerPath.lifter,
    _ => null,
  };
}

/// What the app remembers about itself between launches.
///
/// Deliberately narrow: this is for flags and choices, never for training data.
class OnboardingRecord {
  const OnboardingRecord({this.name = '', this.path, this.isComplete = false});

  final String name;
  final TrainerPath? path;
  final bool isComplete;
}

abstract interface class AppPreferencesRepository {
  Future<OnboardingRecord> readOnboarding();
  Future<void> saveOnboarding(OnboardingRecord record);
}

/// Used when no database is available, such as in tests and on the web.
///
/// Onboarding then reappears on the next launch, which is the right failure:
/// showing a welcome twice is better than losing a person's answers to a
/// silently missing store.
class MemoryAppPreferencesRepository implements AppPreferencesRepository {
  MemoryAppPreferencesRepository({OnboardingRecord? initial})
    : _record = initial ?? const OnboardingRecord();

  /// Starts as though onboarding has already run. Tests and previews that only
  /// care about the app itself use this rather than stepping through a welcome
  /// they are not exercising.
  MemoryAppPreferencesRepository.onboarded()
    : _record = const OnboardingRecord(isComplete: true);

  OnboardingRecord _record;

  @override
  Future<OnboardingRecord> readOnboarding() async => _record;

  @override
  Future<void> saveOnboarding(OnboardingRecord record) async {
    _record = record;
  }
}
