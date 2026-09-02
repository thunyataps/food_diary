import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analyze_repository.dart';

void main() {
  test('parseAnalyzeResponse maps items to FoodItem list', () {
    final data = {
      'items': [
        {
          'name': 'Rice',
          'quantity': '1 cup',
          'calories': 200,
          'protein': 4,
          'carb': 45,
          'fat': 0.5,
          'confidence': 'high',
        }
      ]
    };
    final items = parseAnalyzeResponse(data);
    expect(items.length, 1);
    expect(items.first.name, 'Rice');
    expect(items.first.confidence, 'high');
  });
}
