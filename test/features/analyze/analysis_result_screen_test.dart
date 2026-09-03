import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analysis_result_screen.dart';
import 'package:food_diary/models/food_item.dart';

FoodItem _item(String name, {String quantity = '1 serving', double calories = 100}) => FoodItem(
      name: name,
      quantity: quantity,
      calories: calories,
      protein: 1,
      carb: 2,
      fat: 3,
      source: 'ai',
    );

/// Pushes [AnalysisResultScreen] onto a route so pop-on-save behaves as it does
/// in the app (where the screen is always pushed from `CaptureScreen`).
Future<void> _pushScreen(
  WidgetTester tester, {
  required List<FoodItem> initialItems,
  required Future<void> Function(List<FoodItem>) onSave,
}) async {
  // Each card now carries six fields, so the default 800x600 test viewport
  // would push the Save button (and the later cards) out of the hit-test area.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(initialItems: initialItems, onSave: onSave),
          )),
          child: const Text('open review'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open review'));
  await tester.pumpAndSettle();
}

/// The text actually displayed by the field with [key] — this is what goes
/// stale when a card's element is reused across items.
String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextField>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
      )
      .controller!
      .text;
}

void main() {
  testWidgets('editing calories updates the total', (tester) async {
    List<FoodItem>? saved;
    await _pushScreen(
      tester,
      initialItems: [
        FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
      ],
      onSave: (items) async => saved = items,
    );

    expect(find.text('Total: 200 kcal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('calories_field_0')), '300');
    await tester.pump();

    expect(find.text('Total: 300 kcal'), findsOneWidget);

    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.first.calories, 300);
  });

  testWidgets('removing an item deletes its card', (tester) async {
    await _pushScreen(
      tester,
      initialItems: [
        FoodItem(name: 'Rice', quantity: '1 cup', calories: 200, protein: 4, carb: 45, fat: 0.5, source: 'ai'),
      ],
      onSave: (items) async {},
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(find.byKey(const Key('name_field_0')), findsNothing);
  });

  // Regression guard for C3: cards used to be keyed by list index, so deleting a
  // non-last item left the surviving cards displaying the previous item's text.
  testWidgets('deleting the middle item leaves the remaining cards showing their own values',
      (tester) async {
    List<FoodItem>? saved;
    await _pushScreen(
      tester,
      initialItems: [
        _item('Rice', quantity: '1 cup', calories: 200),
        _item('Chicken', quantity: '100 g', calories: 165),
        _item('Salad', quantity: '1 bowl', calories: 50),
      ],
      onSave: (items) async => saved = items,
    );

    expect(find.text('Total: 415 kcal'), findsOneWidget);

    // Delete "Chicken" (the middle card).
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Total: 250 kcal'), findsOneWidget);

    // The surviving cards keep their own identities (ids 0 and 2), and each
    // field still shows the value of the item it is bound to.
    expect(find.byKey(const Key('name_field_1')), findsNothing);
    expect(_fieldText(tester, 'name_field_0'), 'Rice');
    expect(_fieldText(tester, 'quantity_field_0'), '1 cup');
    expect(_fieldText(tester, 'calories_field_0'), '200.0');
    expect(_fieldText(tester, 'name_field_2'), 'Salad');
    expect(_fieldText(tester, 'quantity_field_2'), '1 bowl');
    expect(_fieldText(tester, 'calories_field_2'), '50.0');
    // The deleted item's text must be gone from the tree entirely.
    expect(find.text('Chicken'), findsNothing);
    expect(find.text('100 g'), findsNothing);

    // Editing a surviving card must write into that card's own item, not a
    // neighbour's.
    await tester.enterText(find.byKey(const Key('name_field_2')), 'Green salad');
    await tester.pump();
    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.map((i) => i.name).toList(), ['Rice', 'Green salad']);
  });

  // I2: protein/carb/fat must be correctable, not just calories.
  testWidgets('protein, carb and fat are editable and reach the saved item', (tester) async {
    List<FoodItem>? saved;
    await _pushScreen(
      tester,
      initialItems: [_item('Rice')],
      onSave: (items) async => saved = items,
    );

    await tester.enterText(find.byKey(const Key('protein_field_0')), '12');
    await tester.enterText(find.byKey(const Key('carb_field_0')), '34');
    await tester.enterText(find.byKey(const Key('fat_field_0')), '5.5');
    await tester.pump();

    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.first.protein, 12);
    expect(saved!.first.carb, 34);
    expect(saved!.first.fat, 5.5);
    expect(saved!.first.source, 'user_edited');
  });

  // I1: a successful save dismisses the review screen so it can't be saved twice.
  testWidgets('a successful save pops the review screen', (tester) async {
    var saveCount = 0;
    await _pushScreen(
      tester,
      initialItems: [_item('Rice')],
      onSave: (items) async => saveCount++,
    );

    expect(find.text('Review Analysis'), findsOneWidget);

    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(find.text('Review Analysis'), findsNothing);
    expect(find.text('open review'), findsOneWidget);
  });

  // C2: a failing save must surface the error and re-enable the button rather
  // than hanging forever on "Saving...".
  testWidgets('a failed save shows an error and lets the user retry', (tester) async {
    var attempts = 0;
    await _pushScreen(
      tester,
      initialItems: [_item('Rice')],
      onSave: (items) async {
        attempts++;
        if (attempts == 1) throw Exception('storage exploded');
      },
    );

    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.text('Could not save this meal. Please try again.'), findsOneWidget);
    // Still on the review screen, button back to its idle label (not stuck on "Saving...").
    expect(find.text('Review Analysis'), findsOneWidget);
    expect(find.text('Save to diary'), findsOneWidget);
    expect(find.text('Saving...'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

    // Retrying works and this time dismisses the screen.
    await tester.tap(find.text('Save to diary'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Review Analysis'), findsNothing);

    // Let the SnackBar's auto-dismiss timer fire so it doesn't outlive the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
