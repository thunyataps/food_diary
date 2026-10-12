import 'localized_text.dart';

enum Equipment { bodyweight, dumbbell, barbell, cable, machine, kettlebell, band }

enum Difficulty { beginner, intermediate, advanced }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.difficulty,
    required this.primary,
    this.secondary = const [],
    required this.steps,
    required this.tips,
    required this.mistakes,
  });

  final String id;
  final LocalizedText name;
  final Equipment equipment;
  final Difficulty difficulty;

  /// Muscle ids this exercise mainly trains.
  final List<String> primary;

  /// Muscle ids that assist.
  final List<String> secondary;
  final LocalizedList steps;
  final LocalizedList tips;
  final LocalizedList mistakes;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    equipment: Equipment.values.byName(json['equipment'] as String),
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    primary: (json['primary'] as List).cast<String>(),
    secondary: (json['secondary'] as List?)?.cast<String>() ?? const [],
    steps: LocalizedList.fromJson(json['steps'] as Map<String, dynamic>),
    tips: LocalizedList.fromJson(json['tips'] as Map<String, dynamic>),
    mistakes: LocalizedList.fromJson(json['mistakes'] as Map<String, dynamic>),
  );
}
