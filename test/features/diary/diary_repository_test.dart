import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/models/food_item.dart';
import 'package:food_diary/models/meal_entry.dart';

void main() {
  test('computeTotals sums all macro fields across items', () {
    final items = [
      FoodItem(
        name: 'Rice',
        quantity: '1 cup',
        calories: 200,
        protein: 4,
        carb: 45,
        fat: 0.5,
        source: 'ai',
      ),
      FoodItem(
        name: 'Chicken',
        quantity: '100g',
        calories: 165,
        protein: 31,
        carb: 0,
        fat: 3.6,
        source: 'ai',
      ),
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

  group('weekRangeUtc', () {
    test('serializes the 7-local-day bounds (ending on endDay) as UTC', () {
      final range = weekRangeUtc(DateTime(2026, 9, 2, 13, 45));

      expect(range.start.endsWith('Z'), isTrue, reason: range.start);
      expect(range.end.endsWith('Z'), isTrue, reason: range.end);

      // The window ends at local midnight after endDay (i.e. includes all of
      // endDay), and starts exactly 7 days before that.
      expect(DateTime.parse(range.end).toLocal(), DateTime(2026, 9, 3));
      expect(DateTime.parse(range.start).toLocal(), DateTime(2026, 8, 27));
      expect(
        DateTime.parse(range.end).difference(DateTime.parse(range.start)),
        const Duration(days: 7),
      );
    });

    test('uses the same convention as the insert value (eatenAt.toUtc())', () {
      final eatenAt = DateTime(2026, 9, 2, 13, 45);
      final range = weekRangeUtc(eatenAt);
      final stored = eatenAt.toUtc().toIso8601String();

      expect(stored.compareTo(range.start) >= 0, isTrue);
      expect(stored.compareTo(range.end) < 0, isTrue);
    });
  });

  group('computeWeeklyAverages', () {
    test('averages each macro across a fixed denominator of 7 days', () {
      // Only 2 entries logged, but the denominator must still be 7 (a
      // sparsely-logged week should show a lower average, not one skewed up
      // by dividing by the count of logged days).
      final entries = [
        MealEntry(
          eatenAt: DateTime(2026, 9, 1),
          items: [
            FoodItem(
              name: 'Oats',
              quantity: '1 bowl',
              calories: 300,
              protein: 14,
              carb: 154,
              fat: 21,
              source: 'ai',
            ),
          ],
        ),
        MealEntry(
          eatenAt: DateTime(2026, 9, 2),
          items: [
            FoodItem(
              name: 'Chicken',
              quantity: '200g',
              calories: 400,
              protein: 42,
              carb: 0,
              fat: 7,
              source: 'ai',
            ),
          ],
        ),
      ];

      final averages = computeWeeklyAverages(entries);

      // Sums: calories 700, protein 56, carb 154, fat 28 — each divided by 7.
      expect(averages.calories, 100);
      expect(averages.protein, 8);
      expect(averages.carb, 22);
      expect(averages.fat, 4);
    });

    test('returns all zeros for an empty week', () {
      final averages = computeWeeklyAverages([]);
      expect(averages.calories, 0);
      expect(averages.protein, 0);
      expect(averages.carb, 0);
      expect(averages.fat, 0);
    });
  });
}
