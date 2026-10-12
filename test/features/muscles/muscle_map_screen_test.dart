import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/muscles/body_viewer.dart';
import 'package:food_diary/features/muscles/muscle_map_screen.dart';
import 'package:food_diary/models/muscle.dart';

import '../../test_utils.dart';
import 'fake_body_viewer_controller.dart';
import 'fixtures.dart';

void main() {
  late FakeBodyViewerController viewer;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<Muscle?> Function(BuildContext)? openMuscleList,
  }) async {
    viewer = FakeBodyViewerController();
    await tester.pumpWidget(
      localizedApp(
        MuscleMapScreen(
          catalog: testCatalog(),
          controllerFactory: () => viewer,
          openMuscleList: openMuscleList,
        ),
      ),
    );
  }

  Future<void> ready(WidgetTester tester) async {
    viewer.emit(const ViewerReady());
    await tester.pump();
  }

  testWidgets('shows a spinner until the viewer is ready', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('muscles_loading')), findsOneWidget);

    await ready(tester);
    expect(find.byKey(const Key('muscles_loading')), findsNothing);
    expect(find.text('Tap a muscle to see exercises'), findsOneWidget);
  });

  testWidgets('tapping a muscle opens its sheet and selects it', (tester) async {
    await pumpScreen(tester);
    await ready(tester);

    viewer.emit(const MuscleTapped('pec_major_clavicular'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('muscle_sheet')), findsOneWidget);
    expect(find.text('Upper chest'), findsOneWidget);
    expect(viewer.calls, contains('select:pec_major_clavicular'));
  });

  testWidgets('ignores taps on unknown muscle ids', (tester) async {
    await pumpScreen(tester);
    await ready(tester);

    viewer.emit(const MuscleTapped('tail_wagger'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('muscle_sheet')), findsNothing);
    expect(viewer.calls, isEmpty);
  });

  testWidgets('expanding an exercise highlights its muscles; collapsing reselects', (tester) async {
    await pumpScreen(tester);
    await ready(tester);
    viewer.emit(const MuscleTapped('pec_major_clavicular'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();
    expect(viewer.calls.last, 'highlight:pec_major_clavicular|deltoid_anterior');

    await tester.tap(find.byKey(const Key('exercise_incline_dumbbell_press')));
    await tester.pumpAndSettle();
    expect(viewer.calls.last, 'select:pec_major_clavicular');
  });

  testWidgets('background tap and close button clear the selection', (tester) async {
    await pumpScreen(tester);
    await ready(tester);
    viewer.emit(const MuscleTapped('deltoid_anterior'));
    await tester.pumpAndSettle();

    viewer.emit(const BackgroundTapped());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_sheet')), findsNothing);
    expect(viewer.calls.last, 'clear');

    viewer.emit(const MuscleTapped('deltoid_anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle_sheet_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_sheet')), findsNothing);
    expect(viewer.calls.last, 'clear');
  });

  testWidgets('view buttons drive the viewer', (tester) async {
    await pumpScreen(tester);
    await ready(tester);

    await tester.tap(find.byKey(const Key('muscles_view_back')));
    await tester.tap(find.byKey(const Key('muscles_view_front')));
    await tester.tap(find.byKey(const Key('muscles_view_reset')));
    expect(viewer.calls, ['setView:back', 'setView:front', 'resetView']);
  });

  testWidgets('a viewer error shows retry and list', (tester) async {
    await pumpScreen(tester);
    viewer.emit(const ViewerFailed('boom'));
    await tester.pump();

    expect(find.byKey(const Key('muscles_error')), findsOneWidget);
    expect(find.text("Couldn't load the 3D body."), findsOneWidget);
    expect(find.byKey(const Key('muscles_error_open_list')), findsOneWidget);
  });

  testWidgets('times out to the error panel', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const Key('muscles_error')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('muscles_error')), findsOneWidget);
  });

  testWidgets('retry reloads and waits again', (tester) async {
    await pumpScreen(tester);
    viewer.emit(const ViewerFailed('boom'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('muscles_retry')));
    await tester.pump();
    expect(viewer.calls, ['reload']);
    expect(find.byKey(const Key('muscles_loading')), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const Key('muscles_error')), findsOneWidget);
  });

  testWidgets('choosing a muscle from the list opens it', (tester) async {
    final catalog = testCatalog();
    await pumpScreen(
      tester,
      openMuscleList: (_) async => catalog.muscleById('subscapularis'),
    );
    await ready(tester);

    await tester.tap(find.byKey(const Key('muscles_list_button')));
    await tester.pumpAndSettle();

    expect(find.text('Subscapularis'), findsOneWidget);
    expect(viewer.calls, contains('select:subscapularis'));
  });

  testWidgets('credits button shows the Z-Anatomy credit', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('muscles_credits_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Z-Anatomy'), findsOneWidget);
  });
}
