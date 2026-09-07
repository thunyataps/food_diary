import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/models/weight_log.dart';

void main() {
  test('formatLoggedDate pads month and day to two digits', () {
    expect(formatLoggedDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('formatLoggedDate handles double-digit month and day', () {
    expect(formatLoggedDate(DateTime(2026, 12, 25)), '2026-12-25');
  });

  test('WeightLog.fromRow parses the date and weight columns', () {
    final log = WeightLog.fromRow({'logged_date': '2026-03-05', 'weight_kg': 68.5});
    expect(log.loggedDate, DateTime(2026, 3, 5));
    expect(log.weightKg, 68.5);
  });
}
