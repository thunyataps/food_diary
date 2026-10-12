import 'package:flutter/widgets.dart';

enum BodyView { front, back }

sealed class BodyViewerEvent {
  const BodyViewerEvent();
}

class ViewerReady extends BodyViewerEvent {
  const ViewerReady();
}

class MuscleTapped extends BodyViewerEvent {
  const MuscleTapped(this.muscleId);
  final String muscleId;
}

class BackgroundTapped extends BodyViewerEvent {
  const BackgroundTapped();
}

class ViewerFailed extends BodyViewerEvent {
  const ViewerFailed(this.message);
  final String message;
}

/// Turns a message posted by `assets/body_viewer/viewer.js` into an event.
/// Returns null for anything malformed.
BodyViewerEvent? parseViewerMessage(Object? raw) {
  if (raw is! Map) return null;
  return switch (raw['type']) {
    'ready' => const ViewerReady(),
    'muscleTapped' => switch (raw['id']) {
      final String id => MuscleTapped(id),
      _ => null,
    },
    'backgroundTapped' => const BackgroundTapped(),
    'error' => ViewerFailed(raw['message']?.toString() ?? 'unknown error'),
    _ => null,
  };
}

/// The 3D body as seen by screens. The WebView implementation lives in
/// `web_body_viewer_controller.dart`; tests use a fake.
abstract class BodyViewerController {
  Stream<BodyViewerEvent> get events;

  /// The widget that renders the body. Built once by the owning screen.
  Widget buildView();

  /// Highlights one muscle and turns the camera toward it.
  Future<void> select(String muscleId);

  /// Colors an exercise's muscles without moving the camera.
  Future<void> highlight({
    required List<String> primary,
    required List<String> secondary,
  });

  Future<void> clear();
  Future<void> setView(BodyView view);
  Future<void> resetView();

  /// Reloads the page (used by Retry).
  Future<void> reload();

  void dispose();
}
