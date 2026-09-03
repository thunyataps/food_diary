import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Signs a new user up and returns the session that was created.
  ///
  /// Returns `null` when the project requires email confirmation (the hosted
  /// Supabase default): the sign-up succeeded, but no session exists until the
  /// user clicks the link in the confirmation email.
  Future<Session?> signUpWithEmail(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return response.session;
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.fooddiary://login-callback/',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
