import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/diary_screen.dart';
import 'package:food_diary/features/settings/goals_repository.dart';
import 'package:food_diary/models/goals.dart';
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

  @override
  Future<List<MealEntry>> entriesForDay(DateTime day) async => [];
}

class _FakeGoalsRepository extends GoalsRepository {
  _FakeGoalsRepository() : super(_fakeClient());
  Goals? goals;
  int saveCalls = 0;

  @override
  Future<Goals?> fetchGoals() async => goals;

  @override
  Future<void> saveGoals(Goals goals) async {
    saveCalls++;
    this.goals = goals;
  }
}

void main() {
  // I5: AuthRepository.signOut() used to have no call site at all.
  testWidgets('the diary app bar exposes a sign-out action', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: _FakeGoalsRepository(),
        onSignOut: () async => signOutCalls++,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign_out_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign_out_button')));
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
  });

  testWidgets('a failing sign-out surfaces an error instead of failing silently', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: _FakeGoalsRepository(),
        onSignOut: () async => throw Exception('offline'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sign_out_button')));
    await tester.pumpAndSettle();

    expect(find.text('Could not sign out. Please try again.'), findsOneWidget);

    // Let the SnackBar's auto-dismiss timer fire before the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the sign-out action is hidden when no handler is wired', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: _FakeGoalsRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign_out_button')), findsNothing);
  });

  testWidgets('shows plain totals when no goals are set yet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: _FakeGoalsRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('0 kcal'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('opening settings and saving goals refreshes the summary card', (tester) async {
    final goalsRepository = _FakeGoalsRepository();
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
        goalsRepository: goalsRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    expect(find.text('Daily goals'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('calories_goal_field')), '2000');
    await tester.enterText(find.byKey(const Key('protein_goal_field')), '100');
    await tester.enterText(find.byKey(const Key('carb_goal_field')), '250');
    await tester.enterText(find.byKey(const Key('fat_goal_field')), '70');
    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(goalsRepository.saveCalls, 1);
    expect(find.text('Daily goals'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });
}
