import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/diary_screen.dart';
import 'package:food_diary/features/diary/weight_repository.dart';
import 'package:food_diary/features/settings/goals_repository.dart';
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

  @override
  Future<List<MealEntry>> entriesForDay(DateTime day) async => [];
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
}
