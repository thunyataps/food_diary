import 'package:flutter/material.dart';
import '../../models/goals.dart';
import '../../models/meal_entry.dart';
import '../settings/goals_repository.dart';
import '../settings/settings_screen.dart';
import 'diary_repository.dart';
import 'today_summary_card.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.repository,
    required this.goalsRepository,
    this.onSignOut,
  });
  final DiaryRepository repository;
  final GoalsRepository goalsRepository;

  /// Signs the current user out. When null the sign-out action is hidden
  /// (used by tests that don't wire an auth repository).
  final Future<void> Function()? onSignOut;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _day = DateTime.now();
  late Future<List<MealEntry>> _entriesFuture;
  late Future<Goals?> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.repository.entriesForDay(_day);
    _goalsFuture = widget.goalsRepository.fetchGoals();
  }

  Future<void> _openSettings(Goals? currentGoals) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initialGoals: currentGoals,
          onSave: widget.goalsRepository.saveGoals,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _goalsFuture = widget.goalsRepository.fetchGoals();
      });
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSignOut!();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not sign out. Please try again.')));
      }
    }
  }

  void _changeDay(int deltaDays) {
    setState(() {
      _day = _day.add(Duration(days: deltaDays));
      _entriesFuture = widget.repository.entriesForDay(_day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}'),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(1)),
          FutureBuilder<Goals?>(
            future: _goalsFuture,
            builder: (context, snapshot) => IconButton(
              key: const Key('settings_button'),
              tooltip: 'Daily goals',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _openSettings(snapshot.data),
            ),
          ),
          if (widget.onSignOut != null)
            IconButton(
              key: const Key('sign_out_button'),
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
        ],
      ),
      body: FutureBuilder<List<MealEntry>>(
        future: _entriesFuture,
        builder: (context, entriesSnapshot) {
          if (!entriesSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final entries = entriesSnapshot.data!;
          final totalCalories = entries.fold<double>(0, (s, e) => s + e.totalCalories);
          final totalProtein = entries.fold<double>(0, (s, e) => s + e.totalProtein);
          final totalCarb = entries.fold<double>(0, (s, e) => s + e.totalCarb);
          final totalFat = entries.fold<double>(0, (s, e) => s + e.totalFat);
          return FutureBuilder<Goals?>(
            future: _goalsFuture,
            builder: (context, goalsSnapshot) {
              return ListView(
                children: [
                  TodaySummaryCard(
                    calories: totalCalories,
                    protein: totalProtein,
                    carb: totalCarb,
                    fat: totalFat,
                    goals: goalsSnapshot.data,
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
      ),
    );
  }
}
