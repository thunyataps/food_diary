import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/diary/diary_repository.dart';
import 'package:food_diary/features/diary/diary_screen.dart';
import 'package:food_diary/models/meal_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeDiaryRepository extends DiaryRepository {
  _FakeDiaryRepository() : super(SupabaseClient(
          'http://localhost:54321',
          'anon',
          // No background token refresh timer — it would outlive the widget test.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  @override
  Future<List<MealEntry>> entriesForDay(DateTime day) async => [];
}

void main() {
  // I5: AuthRepository.signOut() used to have no call site at all.
  testWidgets('the diary app bar exposes a sign-out action', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: DiaryScreen(
        repository: _FakeDiaryRepository(),
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
    await tester.pumpWidget(MaterialApp(home: DiaryScreen(repository: _FakeDiaryRepository())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign_out_button')), findsNothing);
  });
}
