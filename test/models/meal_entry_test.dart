import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/models/meal_entry.dart';
import 'package:food_diary/models/food_item.dart';

void main() {
  test('totalCalories and totalProtein sum all items', () {
    final entry = MealEntry(
      eatenAt: DateTime.now(),
      items: [
        FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
        FoodItem(name: 'Chicken', quantity: '100g', calories: 165, protein: 31, carb: 0, fat: 3.6, source: 'ai'),
      ],
    );
    expect(entry.totalCalories, 365);
    expect(entry.totalProtein, 35);
  });
}
