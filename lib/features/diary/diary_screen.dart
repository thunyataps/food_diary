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
                            for (final e in entries)
                              Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: ListTile(
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
