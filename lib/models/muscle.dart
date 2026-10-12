import 'localized_text.dart';

enum MuscleGroup {
  chest('chest'),
  shoulders('shoulders'),
  back('back'),
  arms('arms'),
  core('core'),
  hips('hips'),
  thighs('thighs'),
  lowerLegs('lower_legs'),
  neck('neck');

  const MuscleGroup(this.jsonName);
  final String jsonName;

  static MuscleGroup fromJson(String value) => values.firstWhere(
    (g) => g.jsonName == value,
    orElse: () => throw FormatException('Unknown muscle group: $value'),
  );
}

class Muscle {
  const Muscle({
    required this.id,
    required this.group,
    this.deep = false,
    required this.name,
    required this.anatomical,
    required this.description,
  });

  final String id;
  final MuscleGroup group;

  /// True when the muscle has no mesh in the 3D model (not visible from
  /// outside); it is reachable from the muscle list only.
  final bool deep;
  final LocalizedText name;
  final String anatomical;
  final LocalizedText description;

  factory Muscle.fromJson(Map<String, dynamic> json) => Muscle(
    id: json['id'] as String,
    group: MuscleGroup.fromJson(json['group'] as String),
    deep: json['deep'] as bool? ?? false,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    anatomical: json['anatomical'] as String,
    description: LocalizedText.fromJson(
      json['description'] as Map<String, dynamic>,
    ),
  );
}
