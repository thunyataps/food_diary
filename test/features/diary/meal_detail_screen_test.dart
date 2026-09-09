import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/meal_detail_screen.dart';
import 'package:food_diary/models/food_item.dart';
import 'package:food_diary/models/meal_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _fakeClient() => SupabaseClient(
  'http://localhost:54321',
  'anon',
  // No background token refresh timer — it would outlive the widget test.
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeDiaryRepository extends DiaryRepository {
  _FakeDiaryRepository() : super(_fakeClient());

  final List<String> deleteMealEntryCalls = [];
  final List<({String id, DateTime eatenAt})> updateMealEatenAtCalls = [];
  String? Function(String path)? signedUrlResponder;
  bool throwOnDelete = false;
  bool throwOnUpdateEatenAt = false;

  @override
  Future<String?> signedPhotoUrl(String path) async =>
      signedUrlResponder?.call(path);

  @override
  Future<void> deleteMealEntry(String mealEntryId) async {
    deleteMealEntryCalls.add(mealEntryId);
    if (throwOnDelete) {
      throw Exception('delete failed');
    }
  }

  @override
  Future<void> updateMealEatenAt(String mealEntryId, DateTime eatenAt) async {
    updateMealEatenAtCalls.add((id: mealEntryId, eatenAt: eatenAt));
    if (throwOnUpdateEatenAt) {
      throw Exception('update failed');
    }
  }
}

// Chosen so every macro value (per item and in the totals) is distinct once
// rounded to the nearest whole number — this keeps `find.text(...)` lookups
// below unambiguous.
MealEntry _entry({String id = 'entry-1', String? photoUrl, String? note}) =>
    MealEntry(
      id: id,
      photoUrl: photoUrl,
      note: note,
      eatenAt: DateTime(2024, 1, 1, 12),
      items: [
        FoodItem(
          name: 'Rice',
          quantity: '1 cup',
          calories: 200,
          protein: 4,
          carb: 45,
          fat: 2,
          source: 'ai',
        ),
        FoodItem(
          name: 'Chicken',
          quantity: '100 g',
          calories: 165,
          protein: 31,
          carb: 1,
          fat: 6,
          source: 'ai',
        ),
      ],
    );

/// A day-of-month-20 date, always within the picker's `[now - 2y, now]`
/// range and never the 1st of a month, so "one day before" stays on the
/// same calendar page as the initial date shown by `showDatePicker`. Picking
/// day 20 of the current month if we're already past it, otherwise day 20
/// of the previous month, keeps this comfortably in the past no matter when
/// the suite runs.
DateTime _safeTestDate() {
  final now = DateTime.now();
  if (now.day > 20) {
    return DateTime(now.year, now.month, 20, 12, 30);
  }
  return DateTime(now.year, now.month - 1, 20, 12, 30);
}

/// Captures whatever `Navigator.pop` value the pushed [MealDetailScreen]
/// returns, so tests can assert on it — not just that a pop happened.
class _PopResult {
  bool called = false;
  bool? value;
}

/// Pushes [MealDetailScreen] onto a route so `Navigator.pop` behaves as it
/// does in the app (the screen is always pushed from `DiaryScreen`), and
/// records the popped value into [popResult] when the route returns.
Future<void> _pushScreen(
  WidgetTester tester, {
  required MealEntry entry,
  required DiaryRepository repository,
  _PopResult? popResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      MealDetailScreen(entry: entry, repository: repository),
                ),
              );
              if (popResult != null) {
                popResult.called = true;
                popResult.value = result;
              }
            },
            child: const Text('open detail'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open detail'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all food items with name, quantity and macros', (
    tester,
  ) async {
    await _pushScreen(
      tester,
      entry: _entry(),
      repository: _FakeDiaryRepository(),
    );

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('1 cup'), findsOneWidget);
    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('100 g'), findsOneWidget);

    // Rice's macros.
    expect(find.text('200 kcal'), findsOneWidget);
    expect(find.text('4 g'), findsOneWidget); // Rice protein
    expect(find.text('45 g'), findsOneWidget); // Rice carb
    expect(find.text('2 g'), findsOneWidget); // Rice fat

    // Chicken's macros.
    expect(find.text('165 kcal'), findsOneWidget);
    expect(find.text('31 g'), findsOneWidget); // Chicken protein
    expect(find.text('1 g'), findsOneWidget); // Chicken carb
    expect(find.text('6 g'), findsOneWidget); // Chicken fat
  });

  testWidgets('shows the totals for a multi-item entry', (tester) async {
    final entry = _entry();
    await _pushScreen(tester, entry: entry, repository: _FakeDiaryRepository());

    expect(entry.totalCalories, 365);
    expect(entry.totalProtein, 35);
    expect(entry.totalCarb, 46);
    expect(entry.totalFat, 8);

    expect(find.text('Totals'), findsOneWidget);
    expect(find.text('365 kcal'), findsOneWidget);
    expect(find.text('35 g'), findsOneWidget);
    expect(find.text('46 g'), findsOneWidget);
    expect(find.text('8 g'), findsOneWidget);
  });

  testWidgets('shows a note when present', (tester) async {
    await _pushScreen(
      tester,
      entry: _entry(note: 'Ate on the go'),
      repository: _FakeDiaryRepository(),
    );

    expect(find.text('Ate on the go'), findsOneWidget);
  });

  testWidgets(
    'tapping delete shows a confirmation dialog without deleting immediately',
    (tester) async {
      final repository = _FakeDiaryRepository();
      await _pushScreen(tester, entry: _entry(), repository: repository);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete this meal?'), findsOneWidget);
      expect(repository.deleteMealEntryCalls, isEmpty);
    },
  );

  testWidgets(
    'confirming delete calls the repository and pops true (not a bare pop)',
    (tester) async {
      final repository = _FakeDiaryRepository();
      final entry = _entry(id: 'entry-42');
      final popResult = _PopResult();

      await _pushScreen(
        tester,
        entry: entry,
        repository: repository,
        popResult: popResult,
      );
      expect(find.text('Meal details'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleteMealEntryCalls, ['entry-42']);
      // The detail screen is gone; we're back on the launcher page.
      expect(find.text('open detail'), findsOneWidget);
      expect(find.text('Meal details'), findsNothing);
      // The exact popped value matters: DiaryScreen only refetches its list
      // when the pop value is `true` — a regression to a bare `pop()` (value
      // `null`) would leave a deleted meal showing without this assertion.
      expect(popResult.called, isTrue);
      expect(popResult.value, isTrue);
    },
  );

  testWidgets('cancelling the delete dialog does not delete or pop', (
    tester,
  ) async {
    final repository = _FakeDiaryRepository();
    final popResult = _PopResult();
    await _pushScreen(
      tester,
      entry: _entry(),
      repository: repository,
      popResult: popResult,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deleteMealEntryCalls, isEmpty);
    // Still on the detail screen.
    expect(find.text('Meal details'), findsOneWidget);
    expect(popResult.called, isFalse);
  });

  testWidgets('a failed delete shows an error and stays on the screen', (
    tester,
  ) async {
    final repository = _FakeDiaryRepository()..throwOnDelete = true;
    await _pushScreen(tester, entry: _entry(), repository: repository);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deleteMealEntryCalls, hasLength(1));
    expect(
      find.text('Could not delete this meal. Please try again.'),
      findsOneWidget,
    );
    // Still on the detail screen so the user can retry.
    expect(find.text('Meal details'), findsOneWidget);

    // Let the SnackBar's auto-dismiss timer fire so it doesn't outlive the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('shows a "Change date" button when the entry has an id', (
    tester,
  ) async {
    await _pushScreen(
      tester,
      entry: _entry(id: 'entry-1'),
      repository: _FakeDiaryRepository(),
    );

    expect(find.text('Change date'), findsOneWidget);
  });

  testWidgets('hides the "Change date" button when the entry has no id', (
    tester,
  ) async {
    final entry = MealEntry(
      id: null,
      eatenAt: DateTime(2024, 1, 15, 12),
      items: const [],
    );
    await _pushScreen(tester, entry: entry, repository: _FakeDiaryRepository());

    expect(find.text('Change date'), findsNothing);
  });

  testWidgets(
    'picking a new date updates the eaten-at day, keeps the time-of-day, '
    'and pops true',
    (tester) async {
      final repository = _FakeDiaryRepository();
      final entry = _entry(id: 'entry-42');
      final entryDate = _safeTestDate();
      entry.eatenAt = entryDate;
      final popResult = _PopResult();

      await _pushScreen(
        tester,
        entry: entry,
        repository: repository,
        popResult: popResult,
      );

      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();

      // The initial date's month page is already open, so day 19 (one day
      // before the entry's day 20) is reachable without scrolling.
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.updateMealEatenAtCalls, hasLength(1));
      final call = repository.updateMealEatenAtCalls.single;
      expect(call.id, 'entry-42');
      expect(
        call.eatenAt,
        DateTime(entryDate.year, entryDate.month, 19, 12, 30),
      );

      // The detail screen is gone; we're back on the launcher page.
      expect(find.text('open detail'), findsOneWidget);
      expect(find.text('Meal details'), findsNothing);
      expect(popResult.called, isTrue);
      expect(popResult.value, isTrue);
    },
  );

  testWidgets(
    'a failed date update shows an error and does not pop the route',
    (tester) async {
      final repository = _FakeDiaryRepository()..throwOnUpdateEatenAt = true;
      final entry = _entry(id: 'entry-42');
      entry.eatenAt = _safeTestDate();
      final popResult = _PopResult();

      await _pushScreen(
        tester,
        entry: entry,
        repository: repository,
        popResult: popResult,
      );

      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.updateMealEatenAtCalls, hasLength(1));
      expect(
        find.text('Could not update the date. Please try again.'),
        findsOneWidget,
      );
      // Still on the detail screen so the user can retry.
      expect(find.text('Meal details'), findsOneWidget);
      expect(popResult.called, isFalse);

      // Let the SnackBar's auto-dismiss timer fire so it doesn't outlive the test.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );
}
