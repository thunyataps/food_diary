import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/diary_screen.dart';
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
  String? Function(String path)? signedUrlResponder;
  final List<String> signedPhotoUrlCalls = [];

  @override
  Future<List<MealEntry>> entriesForDay(DateTime day) async => entries;

  @override
  Future<String?> signedPhotoUrl(String path) async {
    signedPhotoUrlCalls.add(path);
    return signedUrlResponder?.call(path);
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

void main() {
  testWidgets('shows plain totals when no goals are set yet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('0 kcal'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows progress bars once goals are set', (tester) async {
    final goalsRepository = _FakeGoalsRepository()
      ..goals = Goals(dailyCalories: 2000, dailyProtein: 100, dailyCarb: 250, dailyFat: 70);
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: goalsRepository,
        weightRepository: _FakeWeightRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('shows an empty state when no meals are logged for the day', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No meals logged yet'), findsOneWidget);
  });

  testWidgets('does not show the empty state when meals are logged', (tester) async {
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
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No meals logged yet'), findsNothing);
    expect(find.text('Toast'), findsOneWidget);
  });

  testWidgets('meal card without a photo has no leading widget', (tester) async {
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
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.leading, isNull);
    expect(repository.signedPhotoUrlCalls, isEmpty);
  });

  testWidgets('meal card with a photo requests a signed URL and renders a thumbnail',
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
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: repository,
        goalsRepository: _FakeGoalsRepository(),
        weightRepository: _FakeWeightRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    // The thumbnail widget called signedPhotoUrl with the entry's photoUrl.
    expect(repository.signedPhotoUrlCalls, ['user123/12345.jpg']);

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.leading, isNotNull);

    // A null signed URL falls back to the neutral placeholder icon rather
    // than attempting to load an image.
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
