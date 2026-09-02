import 'package:flutter/material.dart';
import '../../models/food_item.dart';

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key, required this.initialItems, required this.onSave});

  final List<FoodItem> initialItems;
  final Future<void> Function(List<FoodItem> items) onSave;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late List<FoodItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initialItems);
  }

  double get _totalCalories => _items.fold(0, (sum, i) => sum + i.calories);

  void _updateItem(int index, FoodItem updated) => setState(() => _items[index] = updated);
  void _removeItem(int index) => setState(() => _items.removeAt(index));
  void _addItem() => setState(() => _items.add(FoodItem(
        name: '',
        quantity: '',
        calories: 0,
        protein: 0,
        carb: 0,
        fat: 0,
        source: 'user_edited',
      )));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < _items.length; i++)
            _FoodItemCard(
              key: ValueKey('item_$i'),
              item: _items[i],
              onChanged: (updated) => _updateItem(i, updated),
              onRemove: () => _removeItem(i),
            ),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add item')),
          const Divider(),
          Text('Total: ${_totalCalories.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _items.isEmpty
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(_items);
                    if (mounted) setState(() => _saving = false);
                  },
            child: Text(_saving ? 'Saving...' : 'Save to diary'),
          ),
        ],
      ),
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({super.key, required this.item, required this.onChanged, required this.onRemove});

  final FoodItem item;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  FoodItem _copyWith(FoodItem item, {String? name, String? quantity, double? calories}) {
    return FoodItem(
      id: item.id,
      name: name ?? item.name,
      quantity: quantity ?? item.quantity,
      calories: calories ?? item.calories,
      protein: item.protein,
      carb: item.carb,
      fat: item.fat,
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
              key: const Key('name_field'),
              initialValue: item.name,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => onChanged(_copyWith(item, name: v)),
            ),
            TextFormField(
              key: const Key('quantity_field'),
              initialValue: item.quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (v) => onChanged(_copyWith(item, quantity: v)),
            ),
            TextFormField(
              key: const Key('calories_field'),
              initialValue: item.calories.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories'),
              onChanged: (v) => onChanged(_copyWith(item, calories: double.tryParse(v) ?? 0)),
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
