import 'package:flutter/material.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysShown = 60;

class DateScroller extends StatefulWidget {
  const DateScroller({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.today,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Injectable "today" so tests don't depend on the real clock.
  final DateTime? today;

  @override
  State<DateScroller> createState() => _DateScrollerState();
}

class _DateScrollerState extends State<DateScroller> {
  late final ScrollController _scrollController;

  DateTime get _today => widget.today ?? DateTime.now();

  List<DateTime> get _days {
    final todayDate = DateTime(_today.year, _today.month, _today.day);
    return List.generate(
      _daysShown,
      (i) => todayDate.subtract(Duration(days: _daysShown - 1 - i)),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: (_daysShown - 1) * 56.0,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final days = _days;
    return SizedBox(
      height: 68,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          final selected = _isSameDay(day, widget.selectedDay);
          return _DayTile(
            day: day,
            selected: selected,
            onTap: () => widget.onDaySelected(day),
          );
        },
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.selected, required this.onTap});

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: Key('day_tile_${day.year}-${day.month}-${day.day}'),
      onTap: onTap,
      child: Container(
        width: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayLabels[day.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                color: selected ? colorScheme.onPrimary.withValues(alpha: 0.8) : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
