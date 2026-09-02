import 'package:flutter/material.dart';
import 'auth_repository.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authRepository, required this.onSignedIn});
  final AuthRepository authRepository;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authRepository.signInWithEmail(_emailController.text, _passwordController.text);
      widget.onSignedIn();
    } catch (_) {
      setState(() => _error = 'Sign in failed. Check your email/password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(onPressed: _loading ? null : _signIn, child: const Text('Sign in')),
            OutlinedButton(
              onPressed: () => widget.authRepository.signInWithGoogle(),
              child: const Text('Continue with Google'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SignupScreen(
                          authRepository: widget.authRepository, onSignedUp: widget.onSignedIn))),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
