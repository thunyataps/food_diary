import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/auth/auth_repository.dart';
import 'package:food_diary/features/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_utils.dart';

/// Stands in for a real [AuthRepository]; the underlying client is never used
/// because every method under test is overridden.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(
        SupabaseClient(
          'http://localhost:54321',
          'anon',
          // No background token refresh timer — it would outlive the widget test.
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}
}

void main() {
  testWidgets('shows email and password fields, sign in button', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        LoginScreen(authRepository: _FakeAuthRepository(), onSignedIn: () {}),
      ),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
