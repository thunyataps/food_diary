import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analysis_result_screen.dart';
import 'package:food_diary/models/food_item.dart';

void main() {
  testWidgets('editing calories updates the total', (tester) async {
    List<FoodItem>? saved;
    await tester.pumpWidget(MaterialApp(
      home: AnalysisResultScreen(
        initialItems: [
          FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
        ],
        onSave: (items) async => saved = items,
      ),
    ));

    expect(find.text('Total: 200 kcal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('calories_field')), '300');
    await tester.pump();

    expect(find.text('Total: 300 kcal'), findsOneWidget);

    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.first.calories, 300);
  });

  testWidgets('removing an item deletes its card', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AnalysisResultScreen(
        initialItems: [
          FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
        ],
        onSave: (items) async {},
      ),
    ));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(find.byKey(const Key('name_field')), findsNothing);
  });
}
