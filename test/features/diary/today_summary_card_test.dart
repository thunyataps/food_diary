import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/today_summary_card.dart';
import 'package:food_diary/models/goals.dart';

void main() {
  group('progressRatio', () {
    test('returns the plain ratio between 0 and 1', () {
      expect(progressRatio(500, 2000), 0.25);
    });

    test('clamps above-goal values to 1', () {
      expect(progressRatio(3000, 2000), 1);
    });

    test('clamps negative current values to 0', () {
      expect(progressRatio(-10, 2000), 0);
    });

    test('returns 0 when the goal is zero or negative', () {
      expect(progressRatio(500, 0), 0);
      expect(progressRatio(500, -100), 0);
    });
  });

  group('TodaySummaryCard', () {
    testWidgets('shows plain totals with no progress bars when goals are null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TodaySummaryCard(calories: 450, protein: 20, carb: 60, fat: 15, goals: null),
        ),
      ));

      expect(find.text('450 kcal'), findsOneWidget);
      expect(find.text('20 g'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows current/goal text and a progress bar per macro when goals are set', (tester) async {
      final goals = Goals(dailyCalories: 2000, dailyProtein: 100, dailyCarb: 250, dailyFat: 70);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodaySummaryCard(calories: 500, protein: 25, carb: 60, fat: 15, goals: goals),
        ),
      ));

      expect(find.text('500 / 2000 kcal'), findsOneWidget);
      expect(find.text('25 / 100 g'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));

      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('calories_progress_bar')),
      );
      expect(bar.value, closeTo(0.25, 0.001));
    });
  });
}
