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

  group('dayRangeUtc', () {
    test('serializes the local-day bounds as UTC so they match the stored eaten_at', () {
      final range = dayRangeUtc(DateTime(2026, 9, 2, 13, 45));

      // Both bounds must carry an explicit UTC marker — a naive local string
      // would be read by Postgres as UTC and shift every row by the offset.
      expect(range.start.endsWith('Z'), isTrue, reason: range.start);
      expect(range.end.endsWith('Z'), isTrue, reason: range.end);

      // Round-tripping gives back local midnight and local midnight + 1 day,
      // i.e. exactly the calendar day the user is looking at.
      expect(DateTime.parse(range.start).toLocal(), DateTime(2026, 9, 2));
      expect(DateTime.parse(range.end).toLocal(), DateTime(2026, 9, 3));
      expect(
        DateTime.parse(range.end).difference(DateTime.parse(range.start)),
        const Duration(days: 1),
      );
    });

    test('uses the same convention as the insert value (eatenAt.toUtc())', () {
      final eatenAt = DateTime(2026, 9, 2, 13, 45);
      final range = dayRangeUtc(eatenAt);
      final stored = eatenAt.toUtc().toIso8601String();

      // A meal eaten during the day must fall inside that day's query window.
      expect(stored.compareTo(range.start) >= 0, isTrue);
      expect(stored.compareTo(range.end) < 0, isTrue);
    });
  });
}
