import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:food_diary/features/muscles/body_viewer.dart';

class FakeBodyViewerController implements BodyViewerController {
  final _events = StreamController<BodyViewerEvent>.broadcast();
  final calls = <String>[];

  void emit(BodyViewerEvent event) => _events.add(event);

  @override
  Stream<BodyViewerEvent> get events => _events.stream;

  @override
  Widget buildView() => const SizedBox.expand(key: Key('fake_body_view'));

  @override
  Future<void> select(String muscleId) async => calls.add('select:$muscleId');

  @override
  Future<void> highlight({
    required List<String> primary,
    required List<String> secondary,
  }) async => calls.add('highlight:${primary.join(',')}|${secondary.join(',')}');

  @override
  Future<void> clear() async => calls.add('clear');

  @override
  Future<void> setView(BodyView view) async => calls.add('setView:${view.name}');

  @override
  Future<void> resetView() async => calls.add('resetView');

  @override
  Future<void> reload() async => calls.add('reload');

  @override
  void dispose() => _events.close();
}
