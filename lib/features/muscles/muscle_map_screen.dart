import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/exercise.dart';
import '../../models/muscle.dart';
import 'body_viewer.dart';
import 'muscle_catalog.dart';
import 'muscle_list_screen.dart';
import 'muscle_sheet.dart';
import 'web_body_viewer_controller.dart';

enum _ViewerStatus { loading, ready, failed }

/// The Muscles tab: a 3D body; tapping a muscle opens its exercises.
class MuscleMapScreen extends StatefulWidget {
  const MuscleMapScreen({
    super.key,
    required this.catalog,
    this.controllerFactory = WebBodyViewerController.new,
    this.readyTimeout = const Duration(seconds: 10),
    this.openMuscleList,
  });

  final MuscleCatalog catalog;
  final BodyViewerController Function() controllerFactory;
  final Duration readyTimeout;

  /// Shows the muscle list and returns the chosen muscle. Defaults to [pushMuscleList]; overridden in tests.
  final Future<Muscle?> Function(BuildContext context)? openMuscleList;

  @override
  State<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends State<MuscleMapScreen> {
  late final BodyViewerController _viewer;
  late final Widget _view;
  late final StreamSubscription<BodyViewerEvent> _sub;
  Timer? _timeout;
  _ViewerStatus _status = _ViewerStatus.loading;
  Muscle? _selected;

  @override
  void initState() {
    super.initState();
    _viewer = widget.controllerFactory();
    _view = _viewer.buildView();
    _sub = _viewer.events.listen(_onEvent);
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub.cancel();
    _viewer.dispose();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(widget.readyTimeout, () {
      if (mounted && _status == _ViewerStatus.loading) {
        setState(() => _status = _ViewerStatus.failed);
      }
    });
  }

  void _onEvent(BodyViewerEvent event) {
    switch (event) {
      case ViewerReady():
        _timeout?.cancel();
        setState(() => _status = _ViewerStatus.ready);
      case MuscleTapped(:final muscleId):
        _openMuscle(muscleId);
      case BackgroundTapped():
        if (_selected != null) _closeMuscle();
      case ViewerFailed():
        _timeout?.cancel();
        setState(() => _status = _ViewerStatus.failed);
    }
  }

  void _openMuscle(String id) {
    final muscle = widget.catalog.muscleById(id);
    if (muscle == null) return;
    setState(() => _selected = muscle);
    _viewer.select(id);
  }

  void _closeMuscle() {
    setState(() => _selected = null);
    _viewer.clear();
  }

  void _onExerciseExpanded(Exercise? exercise) {
    final selected = _selected;
    if (selected == null) return;
    if (exercise == null) {
      _viewer.select(selected.id);
    } else {
      _viewer.highlight(
        primary: exercise.primary,
        secondary: exercise.secondary,
      );
    }
  }

  void _retry() {
    setState(() => _status = _ViewerStatus.loading);
    _startTimeout();
    _viewer.reload();
  }

  Future<void> _openList() async {
    final open =
        widget.openMuscleList ??
        (BuildContext context) => pushMuscleList(context, widget.catalog);
    final muscle = await open(context);
    if (muscle != null && mounted) _openMuscle(muscle.id);
  }

  void _showCredits() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.musclesCreditsTooltip),
        content: Text(l10n.musclesCreditsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.musclesClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.musclesAppBarTitle),
        actions: [
          IconButton(
            key: const Key('muscles_list_button'),
            icon: const Icon(Icons.list),
            tooltip: l10n.musclesListTooltip,
            onPressed: _openList,
          ),
          IconButton(
            key: const Key('muscles_credits_button'),
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.musclesCreditsTooltip,
            onPressed: _showCredits,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _view),
          if (_status == _ViewerStatus.loading)
            const Center(
              child: CircularProgressIndicator(key: Key('muscles_loading')),
            ),
          if (_status == _ViewerStatus.failed)
            Center(
              child: Card(
                key: const Key('muscles_error'),
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.musclesLoadError),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('muscles_retry'),
                        onPressed: _retry,
                        child: Text(l10n.musclesRetry),
                      ),
                      TextButton(
                        key: const Key('muscles_error_open_list'),
                        onPressed: _openList,
                        child: Text(l10n.musclesOpenList),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_status == _ViewerStatus.ready && selected == null) ...[
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Text(
                l10n.musclesTapHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('muscles_view_front'),
                    onPressed: () => _viewer.setView(BodyView.front),
                    child: Text(l10n.musclesViewFront),
                  ),
                  OutlinedButton(
                    key: const Key('muscles_view_back'),
                    onPressed: () => _viewer.setView(BodyView.back),
                    child: Text(l10n.musclesViewBack),
                  ),
                  OutlinedButton(
                    key: const Key('muscles_view_reset'),
                    onPressed: _viewer.resetView,
                    child: Text(l10n.musclesResetView),
                  ),
                ],
              ),
            ),
          ],
          if (selected != null)
            MuscleSheet(
              key: ValueKey(selected.id),
              muscle: selected,
              exercises: widget.catalog.exercisesFor(selected.id),
              muscleNameOf: (id) =>
                  widget.catalog.muscleById(id)?.name.resolve(locale) ?? id,
              onExerciseExpanded: _onExerciseExpanded,
              onClose: _closeMuscle,
            ),
        ],
      ),
    );
  }
}
