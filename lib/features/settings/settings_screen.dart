import 'package:flutter/material.dart';
import '../../models/goals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initialGoals, required this.onSave});

  final Goals? initialGoals;
  final Future<void> Function(Goals goals) onSave;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _caloriesController =
      TextEditingController(text: widget.initialGoals?.dailyCalories.toStringAsFixed(0) ?? '');
  late final _proteinController =
      TextEditingController(text: widget.initialGoals?.dailyProtein.toStringAsFixed(0) ?? '');
  late final _carbController =
      TextEditingController(text: widget.initialGoals?.dailyCarb.toStringAsFixed(0) ?? '');
  late final _fatController =
      TextEditingController(text: widget.initialGoals?.dailyFat.toStringAsFixed(0) ?? '');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carb = double.tryParse(_carbController.text);
    final fat = double.tryParse(_fatController.text);

    if (calories == null || protein == null || carb == null || fat == null) {
      setState(() => _error = 'Enter a number for every field.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(Goals(
        dailyCalories: calories,
        dailyProtein: protein,
        dailyCarb: carb,
        dailyFat: fat,
      ));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save goals. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily goals')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('calories_goal_field'),
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories (kcal)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('protein_goal_field'),
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('carb_goal_field'),
              controller: _carbController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carb (g)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('fat_goal_field'),
              controller: _fatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fat (g)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save goals'),
            ),
          ],
        ),
      ),
    );
  }
}
