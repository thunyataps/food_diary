class Goals {
  Goals({
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyCarb,
    required this.dailyFat,
  });

  final double dailyCalories;
  final double dailyProtein;
  final double dailyCarb;
  final double dailyFat;

  factory Goals.fromRow(Map<String, dynamic> row) {
    return Goals(
      dailyCalories: (row['daily_calories'] as num).toDouble(),
      dailyProtein: (row['daily_protein'] as num).toDouble(),
      dailyCarb: (row['daily_carb'] as num).toDouble(),
      dailyFat: (row['daily_fat'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'daily_calories': dailyCalories,
        'daily_protein': dailyProtein,
        'daily_carb': dailyCarb,
        'daily_fat': dailyFat,
      };
}
