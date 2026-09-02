import 'food_item.dart';

class MealEntry {
  MealEntry({
    this.id,
    this.photoUrl,
    this.note,
    required this.eatenAt,
    required this.items,
  });

  final String? id;
  String? photoUrl;
  String? note;
  DateTime eatenAt;
  List<FoodItem> items;

  double get totalCalories => items.fold(0, (sum, i) => sum + i.calories);
  double get totalProtein => items.fold(0, (sum, i) => sum + i.protein);
  double get totalCarb => items.fold(0, (sum, i) => sum + i.carb);
  double get totalFat => items.fold(0, (sum, i) => sum + i.fat);

  factory MealEntry.fromRow(Map<String, dynamic> row, List<FoodItem> items) {
    return MealEntry(
      id: row['id'] as String,
      photoUrl: row['photo_url'] as String?,
      note: row['note'] as String?,
      eatenAt: DateTime.parse(row['eaten_at'] as String),
      items: items,
    );
  }
}
