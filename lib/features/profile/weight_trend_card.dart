import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/weight_log.dart';

/// A presentational "weight trend" card for the Profile screen.
///
/// Renders a line chart of [weights] (assumed to already be the data the
/// caller wants shown - e.g. the last 30 days). Does no fetching itself.
class WeightTrendCard extends StatelessWidget {
  const WeightTrendCard({super.key, required this.weights, this.days = 30});

  final List<WeightLog> weights;

  /// The window this card's data represents, used only for the title/labels.
  final int days;

  // The app's primary terracotta seed color (see main.dart's appTheme).
  // Reused here as the chart's single-series color: it's already
  // brand-consistent and, checked with the dataviz skill's palette
  // validator, clears the lightness band, chroma floor, and >=3:1 contrast
  // checks against a white card surface.
  static const _seriesColor = Color(0xFFC1652F);
  static const _gridColor = Color(0xFFE1E0D9);
  static const _mutedTextColor = Color(0xFF898781);

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDate(DateTime date) => '${_monthAbbr[date.month - 1]} ${date.day}';

  static String _formatWeight(double kg) {
    return kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
  }

  /// Rounds [rough] up to a "nice" 1/2/5 * 10^n step, for clean axis ticks.
  static double _niceStep(double rough) {
    if (rough <= 0) return 1;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final normalized = rough / magnitude;
    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }
    return niceNormalized * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Weight trend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Last $days days',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _mutedTextColor),
            ),
            const SizedBox(height: 12),
            if (weights.length < 2) _buildEmptyState(context) else _buildChart(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      key: const Key('weight_trend_empty_state'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.show_chart, color: _mutedTextColor, size: 32),
          const SizedBox(height: 12),
          Text(
            'Log your weight on a few different days to see your trend here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _mutedTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final sorted = [...weights]..sort((a, b) => a.loggedDate.compareTo(b.loggedDate));
    final firstDate = sorted.first.loggedDate;
    final latest = sorted.last;

    final spots = [
      for (final w in sorted)
        FlSpot(w.loggedDate.difference(firstDate).inDays.toDouble(), w.weightKg),
    ];

    final weightValues = sorted.map((w) => w.weightKg);
    final rawMin = weightValues.reduce(math.min);
    final rawMax = weightValues.reduce(math.max);
    final range = rawMax - rawMin;
    final pad = range == 0 ? 1.0 : range * 0.15;
    final yStep = _niceStep((range + pad * 2) / 4);
    final minY = (math.max(0, rawMin - pad) / yStep).floor() * yStep;
    final maxY = ((rawMax + pad) / yStep).ceil() * yStep;

    final maxX = spots.last.x == 0 ? 1.0 : spots.last.x;
    final xStep = _niceStep(maxX / 4);

    return Semantics(
      label: 'Weight trend chart. Latest reading ${_formatWeight(latest.weightKg)} kilograms '
          'on ${_shortDate(latest.loggedDate)}. Range over the period: '
          '${_formatWeight(rawMin)} to ${_formatWeight(rawMax)} kilograms.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Latest: '),
                TextSpan(
                  text: '${_formatWeight(latest.weightKg)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _seriesColor),
                ),
                TextSpan(text: ' on ${_shortDate(latest.loggedDate)}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            key: const Key('weight_trend_chart'),
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yStep,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: _gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: yStep,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(color: _mutedTextColor, fontSize: 11),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: xStep,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final date = firstDate.add(Duration(days: value.round()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _shortDate(date),
                            style: const TextStyle(color: _mutedTextColor, fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    tooltipBorder: const BorderSide(color: _gridColor),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = firstDate.add(Duration(days: spot.x.round()));
                        return LineTooltipItem(
                          '${_formatWeight(spot.y)} kg\n',
                          const TextStyle(color: _seriesColor, fontWeight: FontWeight.w700),
                          children: [
                            TextSpan(
                              text: _shortDate(date),
                              style: const TextStyle(
                                color: _mutedTextColor,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        const FlLine(color: _seriesColor, strokeWidth: 1),
                        FlDotData(
                          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                            radius: 4,
                            color: _seriesColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    isStrokeCapRound: true,
                    color: _seriesColor,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _seriesColor.withValues(alpha: 0.10),
                    ),
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => spot.x == spots.last.x,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 4,
                        color: _seriesColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
