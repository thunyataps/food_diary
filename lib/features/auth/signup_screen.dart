import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.authRepository,
    required this.onSignedUp,
  });
  final AuthRepository authRepository;
  final VoidCallback onSignedUp;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  String? _info;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final session = await widget.authRepository.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (session == null) {
        // Email confirmation is required: there is no session yet, so the auth
        // gate would stay on the login screen with no explanation.
        if (mounted) {
          setState(
            () => _info = AppLocalizations.of(context).signupInfoCheckEmail,
          );
        }
        return;
      }
      widget.onSignedUp();
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)
                  .signupErrorFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).commonCreateAccount),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).commonEmailLabel,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .commonPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _info!,
                      key: const Key('signup_info'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF7A8C6B)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _signUp,
                    child: Text(AppLocalizations.of(context).signupButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
