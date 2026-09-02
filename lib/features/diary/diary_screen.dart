import 'package:flutter/material.dart';
import '../../models/meal_entry.dart';
import 'diary_repository.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.repository});
  final DiaryRepository repository;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _day = DateTime.now();
  late Future<List<MealEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.repository.entriesForDay(_day);
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
        actions: [IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDay(1))],
      ),
      body: FutureBuilder<List<MealEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snapshot.data!;
          final totalCalories = entries.fold<double>(0, (s, e) => s + e.totalCalories);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Total today: ${totalCalories.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ListTile(
                      title: Text(e.items.map((it) => it.name).join(', ')),
                      subtitle: Text('${e.totalCalories.toStringAsFixed(0)} kcal'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
