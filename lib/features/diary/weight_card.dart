import 'package:flutter/material.dart';
import '../../models/weight_log.dart';

class WeightCard extends StatefulWidget {
  const WeightCard({super.key, required this.initialWeight, required this.onSave});

  final WeightLog? initialWeight;
  final Future<void> Function(double weightKg) onSave;

  @override
  State<WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<WeightCard> {
  late final _controller = TextEditingController(
    text: widget.initialWeight != null ? _formatWeight(widget.initialWeight!.weightKg) : '',
  );
  bool _saving = false;
  String? _error;

  static String _formatWeight(double weightKg) {
    return weightKg == weightKg.roundToDouble()
        ? weightKg.toStringAsFixed(0)
        : weightKg.toString();
  }

  @override
  void didUpdateWidget(WeightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialWeight?.weightKg != oldWidget.initialWeight?.weightKg) {
      _controller.text =
          widget.initialWeight != null ? _formatWeight(widget.initialWeight!.weightKg) : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = double.tryParse(_controller.text);
    if (weight == null || weight <= 0) {
      setState(() => _error = 'Enter a valid weight.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(weight);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save weight. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('weight_field'),
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  errorText: _error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
