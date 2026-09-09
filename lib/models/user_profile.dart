class UserProfile {
  UserProfile({
    this.name,
    this.age,
    this.heightCm,
    this.bodyFatPct,
    this.muscleMassKg,
  });

  final String? name;
  final int? age;
  final double? heightCm;
  final double? bodyFatPct;
  final double? muscleMassKg;

  factory UserProfile.fromRow(Map<String, dynamic> row) {
    return UserProfile(
      name: row['name'] as String?,
      age: row['age'] as int?,
      heightCm: (row['height_cm'] as num?)?.toDouble(),
      bodyFatPct: (row['body_fat_pct'] as num?)?.toDouble(),
      muscleMassKg: (row['muscle_mass_kg'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toRow(String userId) => {
    'user_id': userId,
    'name': name,
    'age': age,
    'height_cm': heightCm,
    'body_fat_pct': bodyFatPct,
    'muscle_mass_kg': muscleMassKg,
  };
}
