import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/settings/settings_screen.dart';
import 'package:food_diary/models/goals.dart';

void main() {
  testWidgets('prefills fields from initialGoals and saves edited values', (tester) async {
    Goals? saved;
    final goals = Goals(dailyCalories: 2000, dailyProtein: 100, dailyCarb: 250, dailyFat: 70);

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        initialGoals: goals,
        onSave: (g) async => saved = g,
      ),
    ));

    expect(find.text('2000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('calories_goal_field')), '1800');
    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.dailyCalories, 1800);
    expect(saved!.dailyProtein, 100);
  });

  testWidgets('starts with empty fields when there are no initial goals', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(initialGoals: null, onSave: (g) async {}),
    ));

    expect(find.text('2000'), findsNothing);
  });

  testWidgets('shows an error and does not save when a field is not a number', (tester) async {
    var saveCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        initialGoals: Goals(dailyCalories: 2000, dailyProtein: 100, dailyCarb: 250, dailyFat: 70),
        onSave: (g) async => saveCalls++,
      ),
    ));

    await tester.enterText(find.byKey(const Key('calories_goal_field')), 'abc');
    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.text('Enter a number for every field.'), findsOneWidget);
  });

  testWidgets('a failed save shows an error and lets the user retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        initialGoals: Goals(dailyCalories: 2000, dailyProtein: 100, dailyCarb: 250, dailyFat: 70),
        onSave: (g) async => throw Exception('offline'),
      ),
    ));

    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save goals. Try again.'), findsOneWidget);
    expect(find.text('Save goals'), findsOneWidget);
  });
}
