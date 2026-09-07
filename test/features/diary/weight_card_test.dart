import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/weight_card.dart';
import 'package:food_diary/models/weight_log.dart';

void main() {
  testWidgets('starts empty and saves an entered weight', (tester) async {
    double? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeightCard(
          initialWeight: null,
          onSave: (w) async => saved = w,
        ),
      ),
    ));

    expect(find.byKey(const Key('weight_field')), findsOneWidget);
    expect(find.text('68.5'), findsNothing);

    await tester.enterText(find.byKey(const Key('weight_field')), '68.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, 68.5);
  });

  testWidgets('prefills the field when a weight log already exists for the day', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeightCard(
          initialWeight: WeightLog(loggedDate: DateTime(2026, 3, 5), weightKg: 70),
          onSave: (w) async {},
        ),
      ),
    ));

    expect(find.text('70'), findsOneWidget);
  });

  testWidgets('shows an error and does not save for a non-numeric value', (tester) async {
    var saveCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeightCard(initialWeight: null, onSave: (w) async => saveCalls++),
      ),
    ));

    await tester.enterText(find.byKey(const Key('weight_field')), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.text('Enter a valid weight.'), findsOneWidget);
  });

  testWidgets('a failed save shows an error and lets the user retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeightCard(
          initialWeight: null,
          onSave: (w) async => throw Exception('offline'),
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('weight_field')), '68.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save weight. Try again.'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
