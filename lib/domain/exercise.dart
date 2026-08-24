class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.target,
    required this.equipment,
    required this.secondaryMuscles,
    required this.instructions,
    this.mediaUrl,
    this.isFavorite = false,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String bodyPart;
  final String target;
  final String equipment;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? mediaUrl;
  final bool isFavorite;
  final bool isCustom;

  Exercise copyWith({bool? isFavorite}) => Exercise(
    id: id,
    name: name,
    bodyPart: bodyPart,
    target: target,
    equipment: equipment,
    secondaryMuscles: secondaryMuscles,
    instructions: instructions,
    mediaUrl: mediaUrl,
    isFavorite: isFavorite ?? this.isFavorite,
    isCustom: isCustom,
  );
}
