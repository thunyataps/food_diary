import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/weekly_summary_card.dart';
import 'package:food_diary/models/goals.dart';

import '../../test_utils.dart';

void main() {
  group('WeeklySummaryCard', () {
    testWidgets(
      'shows plain averages with no progress bars when goals are null',
      (tester) async {
        await tester.pumpWidget(
          localizedApp(
            const Scaffold(
              body: WeeklySummaryCard(
                averages: WeeklyAverages(410, 22, 65, 17),
              ),
            ),
          ),
        );

        expect(find.text('7-day average'), findsOneWidget);
        expect(find.text('410 kcal'), findsOneWidget);
        expect(find.text('22 g'), findsOneWidget);
        expect(find.text('65 g'), findsOneWidget);
        expect(find.text('17 g'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'shows current/goal text and a progress bar per macro when goals are set',
      (tester) async {
        final goals = Goals(
          dailyCalories: 2000,
          dailyProtein: 100,
          dailyCarb: 250,
          dailyFat: 70,
        );
        await tester.pumpWidget(
          localizedApp(
            Scaffold(
              body: WeeklySummaryCard(
                averages: const WeeklyAverages(500, 25, 60, 15),
                goals: goals,
              ),
            ),
          ),
        );

        expect(find.text('500 / 2000 kcal'), findsOneWidget);
        expect(find.text('25 / 100 g'), findsOneWidget);
        expect(find.text('60 / 250 g'), findsOneWidget);
        expect(find.text('15 / 70 g'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
        expect(find.byType(CircularProgressIndicator), findsNothing);

        final caloriesBar = tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('weekly_calories_progress_bar')),
        );
        expect(caloriesBar.value, closeTo(0.25, 0.001));
      },
    );
  });
}
