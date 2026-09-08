import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/profile/weight_trend_card.dart';
import 'package:food_diary/models/weight_log.dart';

void main() {
  Widget buildCard(List<WeightLog> weights) {
    return MaterialApp(
      home: Scaffold(body: WeightTrendCard(weights: weights)),
    );
  }

  testWidgets('shows the insufficient-data message with zero entries', (tester) async {
    await tester.pumpWidget(buildCard([]));

    expect(find.byKey(const Key('weight_trend_empty_state')), findsOneWidget);
    expect(find.text('Log your weight on a few different days to see your trend here.'),
        findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('shows the insufficient-data message with a single entry', (tester) async {
    await tester.pumpWidget(buildCard([
      WeightLog(loggedDate: DateTime(2026, 8, 1), weightKg: 70),
    ]));

    expect(find.byKey(const Key('weight_trend_empty_state')), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders a line chart when given two or more entries', (tester) async {
    await tester.pumpWidget(buildCard([
      WeightLog(loggedDate: DateTime(2026, 8, 1), weightKg: 70),
      WeightLog(loggedDate: DateTime(2026, 8, 5), weightKg: 69.5),
      WeightLog(loggedDate: DateTime(2026, 8, 10), weightKg: 69),
    ]));

    expect(find.byKey(const Key('weight_trend_empty_state')), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('the chart data has one spot per input entry', (tester) async {
    await tester.pumpWidget(buildCard([
      WeightLog(loggedDate: DateTime(2026, 8, 1), weightKg: 70),
      WeightLog(loggedDate: DateTime(2026, 8, 5), weightKg: 69.5),
      WeightLog(loggedDate: DateTime(2026, 8, 10), weightKg: 69),
    ]));

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.lineBarsData, hasLength(1));
    expect(lineChart.data.lineBarsData.first.spots, hasLength(3));
  });

  testWidgets('shows the latest reading as a direct label', (tester) async {
    await tester.pumpWidget(buildCard([
      WeightLog(loggedDate: DateTime(2026, 8, 1), weightKg: 70),
      WeightLog(loggedDate: DateTime(2026, 8, 10), weightKg: 68.5),
    ]));

    final finder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('68.5 kg'),
    );
    expect(finder, findsOneWidget);
  });

  testWidgets('the card title names the chart', (tester) async {
    await tester.pumpWidget(buildCard([
      WeightLog(loggedDate: DateTime(2026, 8, 1), weightKg: 70),
      WeightLog(loggedDate: DateTime(2026, 8, 10), weightKg: 68.5),
    ]));

    expect(find.text('Weight trend'), findsOneWidget);
  });
}
