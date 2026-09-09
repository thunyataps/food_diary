import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import 'diary_repository.dart';

/// Read-only detail view for one already-saved [MealEntry], with the
/// ability to delete it. Pops with `true` when a delete succeeds so the
/// caller (the Diary screen) knows to refresh its list; pops with no value
/// (or stays on screen) otherwise.
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.entry,
    required this.repository,
  });

  final MealEntry entry;
  final DiaryRepository repository;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  static const _caloriesColor = Color(0xFFC1652F);
  static const _proteinColor = Color(0xFFB5495B);
  static const _carbColor = Color(0xFFD9A441);
  static const _fatColor = Color(0xFF7A8C6B);

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  bool _deleting = false;
  bool _updatingDate = false;

  bool get _busy => _deleting || _updatingDate;

  static String _formatDate(DateTime date) {
    return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _changeDate() async {
    final id = widget.entry.id;
    if (id == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 2, now.month, now.day);
    final currentLocal = widget.entry.eatenAt.toLocal();
    var initialDate = DateTime(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    );
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
    );

    if (picked == null || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final newEatenAt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      currentLocal.hour,
      currentLocal.minute,
      currentLocal.second,
      currentLocal.millisecond,
      currentLocal.microsecond,
    );

    setState(() => _updatingDate = true);
    try {
      await widget.repository.updateMealEatenAt(id, newEatenAt);
      if (mounted) {
        widget.entry.eatenAt = newEatenAt;
        navigator.pop(true);
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not update the date. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingDate = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.entry.id;
    if (id == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete this meal. Please try again.'),
        ),
      );
      return;
    }

    setState(() => _deleting = true);
    try {
      await widget.repository.deleteMealEntry(id);
      if (mounted) navigator.pop(true);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not delete this meal. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final note = entry.note;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Logged on ${_formatDate(entry.eatenAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.id != null)
                TextButton.icon(
                  onPressed: _busy ? null : _changeDate,
                  icon: _updatingDate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_calendar),
                  label: const Text('Change date'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.photoUrl != null) ...[
            _MealDetailPhoto(
              repository: widget.repository,
              photoPath: entry.photoUrl!,
            ),
            const SizedBox(height: 16),
          ],
          if (note != null && note.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(note),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final item in entry.items) _FoodItemDetailCard(item: item),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Totals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _MacroLine(
                    label: 'Calories',
                    value: entry.totalCalories,
                    unit: 'kcal',
                    color: _caloriesColor,
                  ),
                  _MacroLine(
                    label: 'Protein',
                    value: entry.totalProtein,
                    unit: 'g',
                    color: _proteinColor,
                  ),
                  _MacroLine(
                    label: 'Carb',
                    value: entry.totalCarb,
                    unit: 'g',
                    color: _carbColor,
                  ),
                  _MacroLine(
                    label: 'Fat',
                    value: entry.totalFat,
                    unit: 'g',
                    color: _fatColor,
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

class _FoodItemDetailCard extends StatelessWidget {
  const _FoodItemDetailCard({required this.item});
  final FoodItem item;

  static const _caloriesColor = Color(0xFFC1652F);
  static const _proteinColor = Color(0xFFB5495B);
  static const _carbColor = Color(0xFFD9A441);
  static const _fatColor = Color(0xFF7A8C6B);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              item.quantity,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _MacroLine(
              label: 'Calories',
              value: item.calories,
              unit: 'kcal',
              color: _caloriesColor,
            ),
            _MacroLine(
              label: 'Protein',
              value: item.protein,
              unit: 'g',
              color: _proteinColor,
            ),
            _MacroLine(
              label: 'Carb',
              value: item.carb,
              unit: 'g',
              color: _carbColor,
            ),
            _MacroLine(
              label: 'Fat',
              value: item.fat,
              unit: 'g',
              color: _fatColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final double value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            '${value.toStringAsFixed(0)} $unit',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Larger, full-width version of the meal photo, for the detail screen.
/// Mirrors `_MealPhotoThumbnail` in `diary_screen.dart` (fetch a signed URL
/// for the private `meal-photos` object path, fall back to a neutral
/// placeholder on any failure) but sized for a hero image instead of a
/// list-tile thumbnail.
class _MealDetailPhoto extends StatefulWidget {
  const _MealDetailPhoto({required this.repository, required this.photoPath});

  final DiaryRepository repository;
  final String photoPath;

  @override
  State<_MealDetailPhoto> createState() => _MealDetailPhotoState();
}

class _MealDetailPhotoState extends State<_MealDetailPhoto> {
  late Future<String?> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _signedUrlFuture = widget.repository.signedPhotoUrl(widget.photoPath);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FutureBuilder<String?>(
        future: _signedUrlFuture,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done || url == null) {
            return _placeholder(context);
          }
          return Image.network(
            url,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
