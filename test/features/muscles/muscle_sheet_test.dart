import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_sheet.dart';
import 'package:food_diary/models/exercise.dart';

import '../../test_utils.dart';
import 'fixtures.dart';

void main() {
  final catalog = testCatalog();

  Future<List<Exercise?>> pumpSheet(
    WidgetTester tester,
    String muscleId, {
    Locale locale = const Locale('en'),
    VoidCallback? onClose,
  }) async {
    final expanded = <Exercise?>[];
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: Stack(
            children: [
              MuscleSheet(
                muscle: catalog.muscleById(muscleId)!,
                exercises: catalog.exercisesFor(muscleId),
                muscleNameOf: (id) => catalog.muscleById(id)!.name.en,
                onExerciseExpanded: expanded.add,
                onClose: onClose ?? () {},
              ),
            ],
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return expanded;
  }

  testWidgets('shows the muscle and its exercises with roles', (tester) async {
    await pumpSheet(tester, 'pec_major_clavicular');

    expect(find.text('Upper chest'), findsOneWidget);
    expect(find.text('Upper chest description'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);
    expect(find.text('Front Raise'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Secondary'), findsOneWidget);
    expect(find.text('Dumbbell · Beginner'), findsNWidgets(2));
  });

  testWidgets('expanding an exercise shows details and reports it', (tester) async {
    final expanded = await pumpSheet(tester, 'pec_major_clavicular');

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();

    expect(find.text('How to do it'), findsOneWidget);
    expect(find.text('1. Step one'), findsOneWidget);
    expect(find.text('• A tip'), findsOneWidget);
    expect(find.text('• A mistake'), findsOneWidget);
    expect(find.textContaining('Front delt'), findsOneWidget);
    expect(expanded.single?.id, 'incline_dumbbell_press');

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();
    expect(find.text('How to do it'), findsNothing);
    expect(expanded.last, isNull);
  });

  testWidgets('shows the deep note for deep muscles', (tester) async {
    await pumpSheet(tester, 'subscapularis');
    expect(find.text('Deep muscle — not visible on the 3D body.'), findsOneWidget);
  });

  testWidgets('renders Thai content', (tester) async {
    await pumpSheet(tester, 'pec_major_clavicular', locale: const Locale('th'));
    expect(find.text('อกบน'), findsOneWidget);
    expect(find.text('มัดหลัก'), findsOneWidget);
  });

  testWidgets('close button calls onClose', (tester) async {
    var closed = false;
    await pumpSheet(tester, 'deltoid_anterior', onClose: () => closed = true);
    await tester.tap(find.byKey(const Key('muscle_sheet_close')));
    expect(closed, isTrue);
  });
}
