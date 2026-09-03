import 'package:flutter/material.dart';
import '../../models/goals.dart';

double progressRatio(double current, double goal) {
  if (goal <= 0) return 0;
  final ratio = current / goal;
  if (ratio < 0) return 0;
  if (ratio > 1) return 1;
  return ratio;
}

class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({
    super.key,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
    this.goals,
  });

  final double calories;
  final double protein;
  final double carb;
  final double fat;
  final Goals? goals;

  static const _caloriesColor = Color(0xFFC1652F);
  static const _proteinColor = Color(0xFFB5495B);
  static const _carbColor = Color(0xFFD9A441);
  static const _fatColor = Color(0xFF7A8C6B);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's summary", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _MacroRow(
              rowKey: 'calories',
              label: 'Calories',
              value: calories,
              goal: goals?.dailyCalories,
              unit: 'kcal',
              color: _caloriesColor,
              big: true,
            ),
            const SizedBox(height: 8),
            _MacroRow(
              rowKey: 'protein',
              label: 'Protein',
              value: protein,
              goal: goals?.dailyProtein,
              unit: 'g',
              color: _proteinColor,
            ),
            _MacroRow(
              rowKey: 'carb',
              label: 'Carb',
              value: carb,
              goal: goals?.dailyCarb,
              unit: 'g',
              color: _carbColor,
            ),
            _MacroRow(
              rowKey: 'fat',
              label: 'Fat',
              value: fat,
              goal: goals?.dailyFat,
              unit: 'g',
              color: _fatColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
    this.big = false,
  });

  final String rowKey;
  final String label;
  final double value;
  final double? goal;
  final String unit;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    final text = goal != null
        ? '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit'
        : '${value.toStringAsFixed(0)} $unit';
    final labelStyle =
        big ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    final valueStyle = (big ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: color, fontWeight: big ? FontWeight.bold : FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: labelStyle),
              Text(text, style: valueStyle),
            ],
          ),
          if (goal != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                key: Key('${rowKey}_progress_bar'),
                value: progressRatio(value, goal),
                minHeight: big ? 10 : 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
