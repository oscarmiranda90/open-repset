/// Mapping between the exercise catalogue's muscle names and the body
/// illustration's groups.
library;

/// A group the body illustration can shade.
///
/// These ids are the `<g id="...">` values in `assets/images/bodymale.svg`,
/// so renaming one here without renaming it in the asset silently stops that
/// muscle from ever lighting up.
enum MuscleGroup {
  chest('Chest', ['pecs']),
  // `back` holds the lat paths of the rear view; traps join it because the
  // catalogue routes trap work here and the two read as one region.
  back('Back', ['back', 'traps']),
  // Shoulders are drawn once per view, so one group shades both.
  shoulders('Shoulders', ['shoulders', 'back_shoulders']),
  biceps('Biceps', ['biceps']),
  triceps('Triceps', ['triceps']),
  forearms('Forearms', ['forearms', 'lower_arms_back']),
  core('Core', ['core']),
  glutes('Glutes', ['glutes']),
  quads('Quads', ['legs']),
  hamstrings('Hamstrings', ['hamstrings']),
  calves('Calves', ['calves', 'lower_legs']),
  neck('Neck', ['neck', 'back_neck']);

  const MuscleGroup(this.label, this.svgIds);

  /// Human-readable name for the legend and detail readouts.
  final String label;

  /// `<g id="...">` values in `assets/images/bodymale.svg` that this group
  /// shades. Renaming one in the asset without renaming it here silently stops
  /// that muscle from ever lighting up, so `muscle_map_test` asserts they all
  /// still resolve.
  final List<String> svgIds;
}

/// Catalogue muscle names resolved to a group.
///
/// The catalogue uses ExerciseDB vocabulary ("pectorals", "lats", "delts"),
/// which does not match the illustration's ids. Keys are lower-cased and
/// matched by substring, so "upper back" and "lats" both reach [MuscleGroup.back].
const _muscleAliases = <String, MuscleGroup>{
  // Chest
  'pectoral': MuscleGroup.chest,
  'chest': MuscleGroup.chest,
  'serratus anterior': MuscleGroup.chest,

  // Back
  'lat': MuscleGroup.back,
  'upper back': MuscleGroup.back,
  'lower back': MuscleGroup.back,
  'spine': MuscleGroup.back,
  'rhomboid': MuscleGroup.back,
  'back': MuscleGroup.back,
  'trap': MuscleGroup.back,

  // Shoulders
  'delt': MuscleGroup.shoulders,
  'shoulder': MuscleGroup.shoulders,
  'rotator cuff': MuscleGroup.shoulders,

  // Arms
  'bicep': MuscleGroup.biceps,
  'tricep': MuscleGroup.triceps,
  'forearm': MuscleGroup.forearms,
  'brachiali': MuscleGroup.biceps,

  // Core
  'abs': MuscleGroup.core,
  'abdominal': MuscleGroup.core,
  'core': MuscleGroup.core,
  'oblique': MuscleGroup.core,

  // Lower body
  'glute': MuscleGroup.glutes,
  'quad': MuscleGroup.quads,
  'hamstring': MuscleGroup.hamstrings,
  'adductor': MuscleGroup.quads,
  'abductor': MuscleGroup.glutes,
  'calf': MuscleGroup.calves,
  'calves': MuscleGroup.calves,
  'soleus': MuscleGroup.calves,
  'leg': MuscleGroup.quads,

  // Neck
  'neck': MuscleGroup.neck,
  'levator scapulae': MuscleGroup.neck,
};

/// Resolves a catalogue muscle name to a group, or null when unmapped.
///
/// Unmapped names return null rather than a fallback group: shading the wrong
/// muscle is worse than shading none, because the map would then report
/// training that never happened.
MuscleGroup? resolveMuscleGroup(String? muscleName) {
  final name = muscleName?.trim().toLowerCase();
  if (name == null || name.isEmpty) return null;

  // Exact match first so a precise name never loses to a broader substring.
  final exact = _muscleAliases[name];
  if (exact != null) return exact;

  for (final entry in _muscleAliases.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Volume attributed to one muscle group over a period.
class MuscleGroupVolume {
  const MuscleGroupVolume({
    required this.group,
    required this.volumeKg,
    required this.setCount,
  });

  final MuscleGroup group;
  final double volumeKg;
  final int setCount;
}

/// The body map's data: volume per group, plus the peak used to normalise it.
class MuscleCoverage {
  const MuscleCoverage({
    required this.volumes,
    required this.unmappedVolumeKg,
    required this.since,
  });

  final Map<MuscleGroup, MuscleGroupVolume> volumes;

  /// Volume from exercises whose muscle could not be resolved. Surfaced rather
  /// than hidden so the map never silently under-reports.
  final double unmappedVolumeKg;

  final DateTime since;

  bool get hasData => volumes.isNotEmpty;

  double get peakVolumeKg => volumes.values.fold<double>(
    0,
    (best, entry) => entry.volumeKg > best ? entry.volumeKg : best,
  );

  double get totalVolumeKg =>
      volumes.values.fold<double>(0, (sum, entry) => sum + entry.volumeKg);

  /// Intensity for [group] from 0 (untrained) to 1 (the most-trained group).
  double intensityOf(MuscleGroup group) {
    final peak = peakVolumeKg;
    if (peak <= 0) return 0;
    return ((volumes[group]?.volumeKg ?? 0) / peak).clamp(0.0, 1.0);
  }

  /// Groups with no logged volume in the period — the actionable half of the
  /// map, since a gap is what a training plan needs to correct.
  List<MuscleGroup> get untrainedGroups => MuscleGroup.values
      .where((group) => (volumes[group]?.volumeKg ?? 0) <= 0)
      .toList(growable: false);
}

/// Reads muscle coverage from training history.
abstract interface class MuscleCoverageRepository {
  /// Volume per muscle group over the last [days].
  Future<MuscleCoverage> getCoverage({int days = 30});
}
