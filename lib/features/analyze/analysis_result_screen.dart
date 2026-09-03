import 'package:flutter/material.dart';
import '../../models/food_item.dart';

/// A [FoodItem] paired with a stable, per-session identity.
///
/// The review list is edited in place (items added and removed), so cards must
/// be keyed by identity rather than by list position — otherwise Flutter reuses
/// a positional key's element after a delete and its `TextFormField`s keep
/// showing the previous item's text while writing edits into a different item.
class _IdentifiedItem {
  _IdentifiedItem(this.id, this.item);
  final int id;
  FoodItem item;
}

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key, required this.initialItems, required this.onSave});

  final List<FoodItem> initialItems;
  final Future<void> Function(List<FoodItem> items) onSave;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late List<_IdentifiedItem> _entries;
  int _nextId = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entries = [for (final item in widget.initialItems) _IdentifiedItem(_nextId++, item)];
  }

  double get _totalCalories => _entries.fold(0, (sum, e) => sum + e.item.calories);

  void _updateItem(_IdentifiedItem entry, FoodItem updated) => setState(() => entry.item = updated);

  void _removeItem(_IdentifiedItem entry) => setState(() => _entries.remove(entry));

  void _addItem() => setState(() => _entries.add(_IdentifiedItem(
        _nextId++,
        FoodItem(
          name: '',
          quantity: '',
          calories: 0,
          protein: 0,
          carb: 0,
          fat: 0,
          source: 'user_edited',
        ),
      )));

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.onSave([for (final e in _entries) e.item]);
      if (mounted) navigator.pop();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not save this meal. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in _entries)
            _FoodItemCard(
              key: ValueKey('item_${entry.id}'),
              id: entry.id,
              item: entry.item,
              onChanged: (updated) => _updateItem(entry, updated),
              onRemove: () => _removeItem(entry),
            ),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add item')),
          const Divider(),
          Text('Total: ${_totalCalories.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _entries.isEmpty ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save to diary'),
          ),
        ],
      ),
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({
    super.key,
    required this.id,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  /// Stable per-session identity of [item]; keys the text fields so they are
  /// never reused across items when the list is reordered by a delete.
  final int id;
  final FoodItem item;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  FoodItem _copyWith(
    FoodItem item, {
    String? name,
    String? quantity,
    double? calories,
    double? protein,
    double? carb,
    double? fat,
  }) {
    return FoodItem(
      id: item.id,
      name: name ?? item.name,
      quantity: quantity ?? item.quantity,
      calories: calories ?? item.calories,
      protein: protein ?? item.protein,
      carb: carb ?? item.carb,
      fat: fat ?? item.fat,
      source: 'user_edited',
      confidence: item.confidence,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowConfidence = item.confidence == 'low';
    return Card(
      color: lowConfidence ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (lowConfidence)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Low confidence - please check', style: TextStyle(color: Colors.orange)),
              ),
            TextFormField(
              key: Key('name_field_$id'),
              initialValue: item.name,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => onChanged(_copyWith(item, name: v)),
            ),
            TextFormField(
              key: Key('quantity_field_$id'),
              initialValue: item.quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (v) => onChanged(_copyWith(item, quantity: v)),
            ),
            TextFormField(
              key: Key('calories_field_$id'),
              initialValue: item.calories.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories'),
              onChanged: (v) => onChanged(_copyWith(item, calories: double.tryParse(v) ?? 0)),
            ),
            TextFormField(
              key: Key('protein_field_$id'),
              initialValue: item.protein.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
              onChanged: (v) => onChanged(_copyWith(item, protein: double.tryParse(v) ?? 0)),
            ),
            TextFormField(
              key: Key('carb_field_$id'),
              initialValue: item.carb.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carbs (g)'),
              onChanged: (v) => onChanged(_copyWith(item, carb: double.tryParse(v) ?? 0)),
            ),
            TextFormField(
              key: Key('fat_field_$id'),
              initialValue: item.fat.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fat (g)'),
              onChanged: (v) => onChanged(_copyWith(item, fat: double.tryParse(v) ?? 0)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onRemove),
            ),
          ],
        ),
      ),
    );
  }
}
