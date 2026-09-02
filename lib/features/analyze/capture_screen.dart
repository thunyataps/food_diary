import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/image_compression.dart';
import '../../models/food_item.dart';
import 'analyze_repository.dart';
import 'analysis_result_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.analyzeRepository, required this.onSave});

  final AnalyzeRepository analyzeRepository;
  final Future<void> Function(List<FoodItem> items, File? photoFile, String? note) onSave;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _noteController = TextEditingController();
  File? _photo;
  bool _analyzing = false;
  String? _error;

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _analyze() async {
    if (_photo == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final compressed = await ImageCompressor().compressFoodPhoto(_photo!);
      final items = await widget.analyzeRepository.analyzePhoto(
        imageBytes: compressed.bytes,
        mimeType: compressed.mimeType,
        note: _noteController.text,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(
            initialItems: items,
            onSave: (savedItems) => widget.onSave(savedItems, _photo, _noteController.text),
          ),
        ),
      );
    } on AnalyzeException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_photo != null) Image.file(_photo!, height: 200),
            Row(
              children: [
                TextButton(onPressed: () => _pickPhoto(ImageSource.camera), child: const Text('Camera')),
                TextButton(onPressed: () => _pickPhoto(ImageSource.gallery), child: const Text('Gallery')),
              ],
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional) - e.g. "Thai green curry"'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _photo == null || _analyzing ? null : _analyze,
              child: Text(_analyzing ? 'Analyzing...' : 'Analyze'),
            ),
          ],
        ),
      ),
    );
  }
}
