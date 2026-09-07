import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/date_scroller.dart';

void main() {
  testWidgets('shows the last 60 days ending on selectedDay, today included', (tester) async {
    final today = DateTime(2026, 3, 5);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DateScroller(selectedDay: today, today: today, onDaySelected: (_) {}),
      ),
    ));

    expect(find.text('5'), findsOneWidget);
    // 60 days back from March 5 lands in January.
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('tapping a day invokes onDaySelected with that date', (tester) async {
    DateTime? picked;
    final today = DateTime(2026, 3, 5);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DateScroller(
          selectedDay: today,
          today: today,
          onDaySelected: (d) => picked = d,
        ),
      ),
    ));

    // The scroller starts pinned to today; scroll a bit left to bring
    // March 4's tile into the test viewport before tapping it.
    await tester.drag(find.byType(DateScroller), const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day_tile_2026-3-4')));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2026, 3, 4));
  });

  testWidgets('days after today are not shown', (tester) async {
    final today = DateTime(2026, 3, 5);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DateScroller(selectedDay: today, today: today, onDaySelected: (_) {}),
      ),
    ));

    expect(find.text('6'), findsNothing);
  });
}
