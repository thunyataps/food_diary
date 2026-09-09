import 'package:flutter/material.dart';

import '../../models/goals.dart';
import 'diary_repository.dart' show WeeklyAverages;
import 'today_summary_card.dart' show progressRatio;

/// Shows the 7-day averages of the four macros as a sibling to
/// [TodaySummaryCard] — same colors, same [progressRatio] clamping logic,
/// same current/goal text pattern. Unlike the "today" card, calories here
/// gets a linear bar (not a ring): the ring is the "today" card's hero
/// element, and a second big ring on the same screen would compete with it
/// for attention, so all four macros use the same simpler bar treatment.
class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key, required this.averages, this.goals});

  final WeeklyAverages averages;
  final Goals? goals;

  static const _caloriesColor = Color(0xFFC1652F);
  static const _proteinColor = Color(0xFFB5495B);
  static const _carbColor = Color(0xFFD9A441);
  static const _fatColor = Color(0xFF7A8C6B);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7-day average',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _WeeklyMacroRow(
              rowKey: 'weekly_calories',
              label: 'Calories',
              value: averages.calories,
              goal: goals?.dailyCalories,
              unit: 'kcal',
              color: _caloriesColor,
            ),
            _WeeklyMacroRow(
              rowKey: 'weekly_protein',
              label: 'Protein',
              value: averages.protein,
              goal: goals?.dailyProtein,
              unit: 'g',
              color: _proteinColor,
            ),
            _WeeklyMacroRow(
              rowKey: 'weekly_carb',
              label: 'Carb',
              value: averages.carb,
              goal: goals?.dailyCarb,
              unit: 'g',
              color: _carbColor,
            ),
            _WeeklyMacroRow(
              rowKey: 'weekly_fat',
              label: 'Fat',
              value: averages.fat,
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

class _WeeklyMacroRow extends StatelessWidget {
  const _WeeklyMacroRow({
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
    final valueStyle = Theme.of(context).textTheme.bodyMedium
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
