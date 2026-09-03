import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/auth/auth_repository.dart';
import 'package:food_diary/features/auth/signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for a real [AuthRepository]; the underlying client is never used
/// because every method under test is overridden.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.sessionToReturn) : super(SupabaseClient(
          'http://localhost:54321',
          'anon',
          // No background token refresh timer — it would outlive the widget test.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final Session? sessionToReturn;
  int signUpCalls = 0;

  @override
  Future<Session?> signUpWithEmail(String email, String password) async {
    signUpCalls++;
    return sessionToReturn;
  }
}

Session _session() => Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-09-02T00:00:00Z',
      ),
    );

/// Pushes [SignupScreen] onto a route, as `LoginScreen` does.
Future<void> _pushSignup(
  WidgetTester tester, {
  required AuthRepository repository,
  required VoidCallback onSignedUp,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SignupScreen(authRepository: repository, onSignedUp: onSignedUp),
          )),
          child: const Text('open signup'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open signup'));
  await tester.pumpAndSettle();
}

void main() {
  // I3: with email confirmation on (the hosted default) signUp returns no
  // session, and the screen used to look like a silent failure.
  testWidgets('no session after sign-up shows a "check your email" message and stays put',
      (tester) async {
    final repository = _FakeAuthRepository(null);
    var signedUpCalls = 0;
    await _pushSignup(tester, repository: repository, onSignedUp: () => signedUpCalls++);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(repository.signUpCalls, 1);
    expect(find.byKey(const Key('signup_info')), findsOneWidget);
    expect(
      find.text('Check your email to confirm your account, then come back and sign in.'),
      findsOneWidget,
    );
    // No session, so the auth gate must not be told the user is signed in, and
    // the screen must stay visible.
    expect(signedUpCalls, 0);
    expect(find.text('Create account'), findsOneWidget);
    // The button is usable again for a retry.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('a confirmed sign-up notifies the auth gate and pops the signup route',
      (tester) async {
    final repository = _FakeAuthRepository(_session());
    var signedUpCalls = 0;
    await _pushSignup(tester, repository: repository, onSignedUp: () => signedUpCalls++);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(repository.signUpCalls, 1);
    expect(signedUpCalls, 1);
    expect(find.byKey(const Key('signup_info')), findsNothing);
    // Route popped: back on the caller's screen.
    expect(find.text('Create account'), findsNothing);
    expect(find.text('open signup'), findsOneWidget);
  });
}
