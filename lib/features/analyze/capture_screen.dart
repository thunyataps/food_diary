import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/image_compression.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/food_item.dart';
import 'analyze_repository.dart';
import 'analysis_result_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.analyzeRepository,
    required this.onSave,
  });

  final AnalyzeRepository analyzeRepository;
  final Future<void> Function(
    List<FoodItem> items,
    File? photoFile,
    String? note,
  )
  onSave;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _noteController = TextEditingController();
  File? _photo;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() => setState(() {});

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _analyze() async {
    if (_photo == null && _noteController.text.trim().isEmpty) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final List<FoodItem> items;
      if (_photo != null) {
        final compressed = await ImageCompressor().compressFoodPhoto(_photo!);
        items = await widget.analyzeRepository.analyzePhoto(
          imageBytes: compressed.bytes,
          mimeType: compressed.mimeType,
          note: _noteController.text,
        );
      } else {
        items = await widget.analyzeRepository.analyzeDescription(
          description: _noteController.text.trim(),
        );
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(
            initialItems: items,
            onSave: (savedItems) =>
                widget.onSave(savedItems, _photo, _noteController.text),
          ),
        ),
      );
    } on AnalyzeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage(AppLocalizations.of(context)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).captureNetworkError);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).captureAppBarTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _photo != null
                    ? Image.file(_photo!, height: 220, fit: BoxFit.cover)
                    : Container(
                        height: 220,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.restaurant_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        AppLocalizations.of(context).captureCameraButton,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        AppLocalizations.of(context).captureGalleryButton,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).captureNoteLabel,
                  helperText: AppLocalizations.of(context).captureNoteHelper,
                  hintText: AppLocalizations.of(context).captureNoteHint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    (_photo == null && _noteController.text.trim().isEmpty) ||
                        _analyzing
                    ? null
                    : _analyze,
                child: Text(
                  _analyzing
                      ? AppLocalizations.of(context).captureAnalyzingButton
                      : AppLocalizations.of(context).captureAnalyzeButton,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
