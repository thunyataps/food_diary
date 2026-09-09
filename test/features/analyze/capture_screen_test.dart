import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/analyze/analyze_repository.dart';
import 'package:food_diary/features/analyze/analysis_result_screen.dart';
import 'package:food_diary/features/analyze/capture_screen.dart';
import 'package:food_diary/models/food_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _fakeClient() => SupabaseClient(
  'http://localhost:54321',
  'anon',
  // No background token refresh timer — it would outlive the widget test.
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeAnalyzeRepository extends AnalyzeRepository {
  _FakeAnalyzeRepository() : super(_fakeClient());

  List<FoodItem> result = [
    FoodItem(
      name: 'Rice',
      quantity: '1 cup',
      calories: 200,
      protein: 4,
      carb: 45,
      fat: 0.5,
      source: 'ai',
    ),
  ];
  final List<String?> analyzePhotoNotes = [];
  final List<String> analyzeDescriptionCalls = [];

  @override
  Future<List<FoodItem>> analyzePhoto({
    required Uint8List imageBytes,
    required String mimeType,
    String? note,
  }) async {
    analyzePhotoNotes.add(note);
    return result;
  }

  @override
  Future<List<FoodItem>> analyzeDescription({
    required String description,
  }) async {
    analyzeDescriptionCalls.add(description);
    return result;
  }
}

Future<void> _pumpCaptureScreen(
  WidgetTester tester, {
  required AnalyzeRepository analyzeRepository,
  Future<void> Function(List<FoodItem> items, File? photoFile, String? note)?
  onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CaptureScreen(
        analyzeRepository: analyzeRepository,
        onSave: onSave ?? (items, photoFile, note) async {},
      ),
    ),
  );
}

void main() {
  testWidgets('Analyze button is disabled with no photo and an empty note', (
    tester,
  ) async {
    await _pumpCaptureScreen(
      tester,
      analyzeRepository: _FakeAnalyzeRepository(),
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'Analyze button stays disabled with no photo and a whitespace-only note',
    (tester) async {
      await _pumpCaptureScreen(
        tester,
        analyzeRepository: _FakeAnalyzeRepository(),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'Analyze button becomes enabled once the note field has text, with no photo',
    (tester) async {
      await _pumpCaptureScreen(
        tester,
        analyzeRepository: _FakeAnalyzeRepository(),
      );

      await tester.enterText(
        find.byType(TextField),
        '2 fried eggs and a slice of toast',
      );
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'tapping Analyze with no photo and a note calls analyzeDescription and navigates',
    (tester) async {
      final repository = _FakeAnalyzeRepository();
      await _pumpCaptureScreen(tester, analyzeRepository: repository);

      await tester.enterText(
        find.byType(TextField),
        '2 fried eggs and a slice of toast',
      );
      await tester.pump();

      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();

      expect(repository.analyzeDescriptionCalls, [
        '2 fried eggs and a slice of toast',
      ]);
      expect(repository.analyzePhotoNotes, isEmpty);
      expect(find.byType(AnalysisResultScreen), findsOneWidget);
    },
  );
}
