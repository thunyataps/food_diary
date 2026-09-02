import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/models/food_item.dart';

void main() {
  test('computeTotals sums all macro fields across items', () {
    final items = [
      FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
      FoodItem(name: 'Chicken', quantity: '100g', calories: 165, protein: 31, carb: 0, fat: 3.6, source: 'ai'),
    ];
    final totals = computeTotals(items);
    expect(totals.calories, 365);
    expect(totals.protein, 35);
    expect(totals.carb, 45);
    expect(totals.fat, closeTo(4.1, 0.001));
  });
}
