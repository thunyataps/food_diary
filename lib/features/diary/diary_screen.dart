import 'package:flutter/material.dart';
import '../../models/goals.dart';
import '../../models/meal_entry.dart';
import '../../models/weight_log.dart';
import '../settings/goals_repository.dart';
import 'date_scroller.dart';
import 'diary_repository.dart';
import 'today_summary_card.dart';
import 'weight_card.dart';
import 'weight_repository.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.repository,
    required this.goalsRepository,
    required this.weightRepository,
  });
  final DiaryRepository repository;
  final GoalsRepository goalsRepository;
  final WeightRepository weightRepository;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _day = DateTime.now();
  late Future<List<MealEntry>> _entriesFuture;
  late Future<Goals?> _goalsFuture;
  late Future<WeightLog?> _weightFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.repository.entriesForDay(_day);
    _goalsFuture = widget.goalsRepository.fetchGoals();
    _weightFuture = widget.weightRepository.fetchWeightForDate(_day);
  }

  Future<void> _saveWeight(double weightKg) async {
    await widget.weightRepository.saveWeightForDate(_day, weightKg);
    if (mounted) {
      setState(() {
        _weightFuture = widget.weightRepository.fetchWeightForDate(_day);
      });
    }
  }

  void _selectDay(DateTime day) {
    setState(() {
      _day = day;
      _entriesFuture = widget.repository.entriesForDay(_day);
      _weightFuture = widget.weightRepository.fetchWeightForDate(_day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Diary')),
      body: Column(
        children: [
          DateScroller(selectedDay: _day, onDaySelected: _selectDay),
          Expanded(
            child: FutureBuilder<List<MealEntry>>(
              future: _entriesFuture,
              builder: (context, entriesSnapshot) {
                if (!entriesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = entriesSnapshot.data!;
                final totalCalories = entries.fold<double>(0, (s, e) => s + e.totalCalories);
                final totalProtein = entries.fold<double>(0, (s, e) => s + e.totalProtein);
                final totalCarb = entries.fold<double>(0, (s, e) => s + e.totalCarb);
                final totalFat = entries.fold<double>(0, (s, e) => s + e.totalFat);
                return FutureBuilder<Goals?>(
                  future: _goalsFuture,
                  builder: (context, goalsSnapshot) {
                    return FutureBuilder<WeightLog?>(
                      future: _weightFuture,
                      builder: (context, weightSnapshot) {
                        return ListView(
                          children: [
                            TodaySummaryCard(
                              calories: totalCalories,
                              protein: totalProtein,
                              carb: totalCarb,
                              fat: totalFat,
                              goals: goalsSnapshot.data,
                            ),
                            WeightCard(
                              key: ValueKey(_day),
                              initialWeight: weightSnapshot.data,
                              onSave: _saveWeight,
                            ),
                            if (entries.isEmpty)
                              _EmptyMealsState(colorScheme: Theme.of(context).colorScheme)
                            else
                              for (final e in entries)
                                Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    leading: e.photoUrl == null
                                        ? null
                                        : _MealPhotoThumbnail(
                                            repository: widget.repository,
                                            photoPath: e.photoUrl!,
                                          ),
                                    title: Text(e.items.map((it) => it.name).join(', ')),
                                    subtitle: Text('${e.totalCalories.toStringAsFixed(0)} kcal'),
                                  ),
                                ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly placeholder shown below the summary cards when a day has no
/// logged meals yet.
class _EmptyMealsState extends StatelessWidget {
  const _EmptyMealsState({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No meals logged yet',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap Add meal to log what you ate',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Small rounded-square thumbnail for a meal photo. The stored `photoPath`
/// is an object path in the private `meal-photos` bucket, so it must be
/// exchanged for a temporary signed URL before it can be loaded as an image.
/// Any failure along the way (signing, or the image itself) falls back to a
/// neutral placeholder icon rather than a blank space or a crash.
class _MealPhotoThumbnail extends StatefulWidget {
  const _MealPhotoThumbnail({required this.repository, required this.photoPath});

  final DiaryRepository repository;
  final String photoPath;

  @override
  State<_MealPhotoThumbnail> createState() => _MealPhotoThumbnailState();
}

class _MealPhotoThumbnailState extends State<_MealPhotoThumbnail> {
  late Future<String?> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _signedUrlFuture = widget.repository.signedPhotoUrl(widget.photoPath);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<String?>(
        future: _signedUrlFuture,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done || url == null) {
            return _placeholder(context);
          }
          return Image.network(
            url,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
