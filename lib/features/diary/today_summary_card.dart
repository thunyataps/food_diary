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
            _CaloriesRing(
              calories: calories,
              goal: goals?.dailyCalories,
              color: _caloriesColor,
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

class _CaloriesRing extends StatelessWidget {
  const _CaloriesRing({
    required this.calories,
    required this.goal,
    required this.color,
  });

  final double calories;
  final double? goal;
  final Color color;

  static const _diameter = 132.0;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    if (goal == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Calories', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${calories.toStringAsFixed(0)} kcal',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: _diameter,
          height: _diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: _diameter,
                height: _diameter,
                child: CircularProgressIndicator(
                  key: const Key('calories_progress_ring'),
                  value: progressRatio(calories, goal),
                  strokeWidth: 11,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    calories.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '/ ${goal.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ],
          ),
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
  });

  final String rowKey;
  final String label;
  final double value;
  final double? goal;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    final text = goal != null
        ? '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit'
        : '${value.toStringAsFixed(0)} $unit';
    final labelStyle = Theme.of(context).textTheme.bodyMedium;
    final valueStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: color, fontWeight: FontWeight.w600);

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
                minHeight: 6,
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
