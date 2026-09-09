import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/diary_screen.dart';
import 'package:food_diary/features/diary/meal_detail_screen.dart';
import 'package:food_diary/features/diary/weight_repository.dart';
import 'package:food_diary/features/settings/goals_repository.dart';
import 'package:food_diary/models/food_item.dart';
import 'package:food_diary/models/goals.dart';
import 'package:food_diary/models/meal_entry.dart';
import 'package:food_diary/models/weight_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _fakeClient() => SupabaseClient(
  'http://localhost:54321',
  'anon',
  // No background token refresh timer — it would outlive the widget test.
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeDiaryRepository extends DiaryRepository {
  _FakeDiaryRepository() : super(_fakeClient());

  List<MealEntry> entries = [];
  List<MealEntry> weeklyEntries = [];
  String? Function(String path)? signedUrlResponder;
  final List<String> signedPhotoUrlCalls = [];
  final List<String> deleteMealEntryCalls = [];

  @override
  Future<List<MealEntry>> entriesForDay(DateTime day) async => entries;

  @override
  Future<List<MealEntry>> entriesForWeekEnding(DateTime endDay) async =>
      weeklyEntries;

  @override
  Future<String?> signedPhotoUrl(String path) async {
    signedPhotoUrlCalls.add(path);
    return signedUrlResponder?.call(path);
  }

  @override
  Future<void> deleteMealEntry(String mealEntryId) async {
    deleteMealEntryCalls.add(mealEntryId);
  }
}

class _FakeGoalsRepository extends GoalsRepository {
  _FakeGoalsRepository() : super(_fakeClient());
  Goals? goals;

  @override
  Future<Goals?> fetchGoals() async => goals;
}

class _FakeWeightRepository extends WeightRepository {
  _FakeWeightRepository() : super(_fakeClient());

  @override
  Future<WeightLog?> fetchWeightForDate(DateTime date) async => null;

  @override
  Future<void> saveWeightForDate(DateTime date, double weightKg) async {}
}

/// Pumps [DiaryScreen] and settles it. The screen now stacks three summary
/// cards (today, 7-day average, weight) above the meal list, which no
/// longer fits — together with the meal list content most tests also want
/// to see — inside the default 800x600 test viewport's built extent. A
/// taller test surface (same fix already used in
/// `analysis_result_screen_test.dart`) keeps the meal list actually built
/// and findable without every test having to scroll for it first.
Future<void> _pumpDiaryScreen(
  WidgetTester tester, {
  required DiaryRepository repository,
  required GoalsRepository goalsRepository,
  required WeightRepository weightRepository,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: DiaryScreen(
        repository: repository,
        goalsRepository: goalsRepository,
        weightRepository: weightRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows plain totals when no goals are set yet', (tester) async {
    await _pumpDiaryScreen(
      tester,
      repository: _FakeDiaryRepository(),
      goalsRepository: _FakeGoalsRepository(),
      weightRepository: _FakeWeightRepository(),
    );

    // Both the "today" and "7-day average" cards show "0 kcal" here (no
    // entries and no goals in either window).
    expect(find.text('0 kcal'), findsNWidgets(2));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows progress bars once goals are set', (tester) async {
    final goalsRepository = _FakeGoalsRepository()
      ..goals = Goals(
        dailyCalories: 2000,
        dailyProtein: 100,
        dailyCarb: 250,
        dailyFat: 70,
      );
    await _pumpDiaryScreen(
      tester,
      repository: _FakeDiaryRepository(),
      goalsRepository: goalsRepository,
      weightRepository: _FakeWeightRepository(),
    );

    // TodaySummaryCard: 3 macro bars + 1 calories ring.
    // WeeklySummaryCard: 4 macro bars (calories included, no ring).
    expect(find.byType(LinearProgressIndicator), findsNWidgets(7));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'shows the 7-day average card computed from the week-ending fetch',
    (tester) async {
      final repository = _FakeDiaryRepository()
        ..weeklyEntries = [
          MealEntry(
            id: '1',
            eatenAt: DateTime(2024, 1, 1),
            items: [
              FoodItem(
                name: 'Steak',
                quantity: '200g',
                calories: 700,
                protein: 63,
                carb: 21,
                fat: 49,
                source: 'ai',
              ),
            ],
          ),
        ];
      await _pumpDiaryScreen(
        tester,
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      );

      expect(find.text('7-day average'), findsOneWidget);
      // Fixed /7 denominator: 700/7=100 kcal, 63/7=9 g protein, 21/7=3 g carb,
      // 49/7=7 g fat — not divided by the (1) day that actually has an entry.
      expect(find.text('100 kcal'), findsOneWidget);
      expect(find.text('9 g'), findsOneWidget);
      expect(find.text('3 g'), findsOneWidget);
      expect(find.text('7 g'), findsOneWidget);
    },
  );

  testWidgets('shows an empty state when no meals are logged for the day', (
    tester,
  ) async {
    await _pumpDiaryScreen(
      tester,
      repository: _FakeDiaryRepository(),
      goalsRepository: _FakeGoalsRepository(),
      weightRepository: _FakeWeightRepository(),
    );

    expect(find.text('No meals logged yet'), findsOneWidget);
  });

  testWidgets('does not show the empty state when meals are logged', (
    tester,
  ) async {
    final repository = _FakeDiaryRepository()
      ..entries = [
        MealEntry(
          id: '1',
          eatenAt: DateTime(2024, 1, 1),
          items: [
            FoodItem(
              name: 'Toast',
              quantity: '1 slice',
              calories: 100,
              protein: 3,
              carb: 15,
              fat: 2,
              source: 'user_edited',
            ),
          ],
        ),
      ];
    await _pumpDiaryScreen(
      tester,
      repository: repository,
      goalsRepository: _FakeGoalsRepository(),
      weightRepository: _FakeWeightRepository(),
    );

    expect(find.text('No meals logged yet'), findsNothing);
    expect(find.text('Toast'), findsOneWidget);
  });

  testWidgets('meal card without a photo has no leading widget', (
    tester,
  ) async {
    final repository = _FakeDiaryRepository()
      ..entries = [
        MealEntry(
          id: '1',
          eatenAt: DateTime(2024, 1, 1),
          items: [
            FoodItem(
              name: 'Toast',
              quantity: '1 slice',
              calories: 100,
              protein: 3,
              carb: 15,
              fat: 2,
              source: 'user_edited',
            ),
          ],
        ),
      ];
    await _pumpDiaryScreen(
      tester,
      repository: repository,
      goalsRepository: _FakeGoalsRepository(),
      weightRepository: _FakeWeightRepository(),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.leading, isNull);
    expect(repository.signedPhotoUrlCalls, isEmpty);
  });

  testWidgets(
    'meal card with a photo requests a signed URL and renders a thumbnail',
    (tester) async {
      final repository = _FakeDiaryRepository();
      repository.signedUrlResponder = (String path) => null;
      repository.entries = [
        MealEntry(
          id: '1',
          photoUrl: 'user123/12345.jpg',
          eatenAt: DateTime(2024, 1, 1),
          items: [
            FoodItem(
              name: 'Toast',
              quantity: '1 slice',
              calories: 100,
              protein: 3,
              carb: 15,
              fat: 2,
              source: 'user_edited',
            ),
          ],
        ),
      ];
      await _pumpDiaryScreen(
        tester,
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      );

      // The thumbnail widget called signedPhotoUrl with the entry's photoUrl.
      expect(repository.signedPhotoUrlCalls, ['user123/12345.jpg']);

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.leading, isNotNull);

      // A null signed URL falls back to the neutral placeholder icon rather
      // than attempting to load an image.
      expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'meal photo thumbnail refetches when the day changes (regression: was stale)',
    (tester) async {
      final repository = _FakeDiaryRepository();
      repository.signedUrlResponder = (path) => null;
      repository.entries = [
        MealEntry(
          id: '1',
          photoUrl: 'day-a.jpg',
          eatenAt: DateTime.now(),
          items: [
            FoodItem(
              name: 'Toast',
              quantity: '1 slice',
              calories: 100,
              protein: 3,
              carb: 15,
              fat: 2,
              source: 'user_edited',
            ),
          ],
        ),
      ];

      await _pumpDiaryScreen(
        tester,
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      );

      expect(repository.signedPhotoUrlCalls, ['day-a.jpg']);

      // Simulate a different day's meal (same list position) before the
      // screen refetches entries for the newly-selected day.
      repository.entries = [
        MealEntry(
          id: '2',
          photoUrl: 'day-b.jpg',
          eatenAt: DateTime.now(),
          items: [
            FoodItem(
              name: 'Eggs',
              quantity: '2',
              calories: 150,
              protein: 12,
              carb: 1,
              fat: 10,
              source: 'user_edited',
            ),
          ],
        ),
      ];

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final tileKey = Key(
        'day_tile_${yesterday.year}-${yesterday.month}-${yesterday.day}',
      );
      // The scroller starts pinned near "today" (the rightmost tile), and at
      // the default test viewport width yesterday's tile already falls
      // within view — no drag needed. If this ever needs scrolling, prefer
      // `tester.ensureVisible` over a blind drag offset.
      await tester.ensureVisible(find.byKey(tileKey));
      await tester.tap(find.byKey(tileKey));
      await tester.pumpAndSettle();

      // Without a key on the meal Card, the previous _MealPhotoThumbnail
      // State would be reused for the new entry and never refetch — this
      // asserts the new entry's photo path was actually requested.
      expect(repository.signedPhotoUrlCalls, ['day-a.jpg', 'day-b.jpg']);
    },
  );

  testWidgets('tapping a meal card navigates to the meal detail screen', (
    tester,
  ) async {
    final repository = _FakeDiaryRepository()
      ..entries = [
        MealEntry(
          id: '1',
          eatenAt: DateTime(2024, 1, 1),
          items: [
            FoodItem(
              name: 'Toast',
              quantity: '1 slice',
              calories: 100,
              protein: 3,
              carb: 15,
              fat: 2,
              source: 'user_edited',
            ),
          ],
        ),
      ];
    await _pumpDiaryScreen(
      tester,
      repository: repository,
      goalsRepository: _FakeGoalsRepository(),
      weightRepository: _FakeWeightRepository(),
    );

    expect(find.byType(MealDetailScreen), findsNothing);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.byType(MealDetailScreen), findsOneWidget);
    expect(find.text('Meal details'), findsOneWidget);
  });

  testWidgets(
    'deleting a meal from the detail screen refreshes the diary list',
    (tester) async {
      final repository = _FakeDiaryRepository()
        ..entries = [
          MealEntry(
            id: '1',
            eatenAt: DateTime(2024, 1, 1),
            items: [
              FoodItem(
                name: 'Toast',
                quantity: '1 slice',
                calories: 100,
                protein: 3,
                carb: 15,
                fat: 2,
                source: 'user_edited',
              ),
            ],
          ),
        ];
      await _pumpDiaryScreen(
        tester,
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(MealDetailScreen), findsOneWidget);

      // Simulate the backend no longer having this entry once it's deleted —
      // DiaryScreen must actually re-fetch (not just pop back showing stale
      // data) to see this.
      repository.entries = [];

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleteMealEntryCalls, ['1']);
      // Back on the Diary screen, showing the refetched (now empty) list —
      // not the stale "Toast" entry that was on screen before the delete.
      expect(find.byType(MealDetailScreen), findsNothing);
      expect(find.text('Toast'), findsNothing);
      expect(find.text('No meals logged yet'), findsOneWidget);
    },
  );
}
