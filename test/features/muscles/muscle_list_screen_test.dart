import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/muscle_list_screen.dart';
import 'package:food_diary/models/muscle.dart';

import '../../test_utils.dart';
import 'fixtures.dart';

void main() {
  testWidgets('lists muscles grouped and filters by search', (tester) async {
    await tester.pumpWidget(localizedApp(MuscleListScreen(catalog: testCatalog())));

    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Shoulders'), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_pec_major_clavicular')), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_subscapularis')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('muscle_search_field')), 'delt');
    await tester.pump();
    expect(find.byKey(const Key('muscle_tile_deltoid_anterior')), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_pec_major_clavicular')), findsNothing);
    expect(find.text('Chest'), findsNothing);

    await tester.enterText(find.byKey(const Key('muscle_search_field')), 'zzz');
    await tester.pump();
    expect(find.text('No muscles found'), findsOneWidget);
  });

  testWidgets('searches Thai names', (tester) async {
    await tester.pumpWidget(
      localizedApp(MuscleListScreen(catalog: testCatalog()), locale: const Locale('th')),
    );
    await tester.enterText(find.byKey(const Key('muscle_search_field')), 'อกบน');
    await tester.pump();
    expect(find.byKey(const Key('muscle_tile_pec_major_clavicular')), findsOneWidget);
    expect(find.byKey(const Key('muscle_tile_deltoid_anterior')), findsNothing);
  });

  testWidgets('tapping a muscle pops it', (tester) async {
    Muscle? chosen;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await pushMuscleList(context, testCatalog()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle_tile_subscapularis')));
    await tester.pumpAndSettle();
    expect(chosen?.id, 'subscapularis');
  });
}
