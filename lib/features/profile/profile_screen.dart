import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.latestWeightKg,
    required this.initialProfile,
    required this.onSaveProfile,
    required this.onOpenGoals,
    required this.onSignOut,
  });

  final String email;
  final double? latestWeightKg;
  final UserProfile? initialProfile;
  final Future<void> Function(UserProfile profile) onSaveProfile;
  final VoidCallback onOpenGoals;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _nameController = TextEditingController(text: widget.initialProfile?.name ?? '');
  late final _ageController =
      TextEditingController(text: widget.initialProfile?.age?.toString() ?? '');
  late final _heightController =
      TextEditingController(text: _formatOrEmpty(widget.initialProfile?.heightCm));
  late final _bodyFatController =
      TextEditingController(text: _formatOrEmpty(widget.initialProfile?.bodyFatPct));
  late final _muscleMassController =
      TextEditingController(text: _formatOrEmpty(widget.initialProfile?.muscleMassKg));

  bool _savingProfile = false;
  bool _signingOut = false;
  String? _error;

  static String _formatOrEmpty(double? value) => value == null ? '' : _formatNumber(value);

  static String _formatNumber(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    _muscleMassController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _error = null;
    });
    try {
      await widget.onSaveProfile(UserProfile(
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        age: int.tryParse(_ageController.text),
        heightCm: double.tryParse(_heightController.text),
        bodyFatPct: double.tryParse(_bodyFatController.text),
        muscleMassKg: double.tryParse(_muscleMassController.text),
      ));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save profile. Try again.');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not sign out. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.email, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        widget.latestWeightKg != null
                            ? '${_formatNumber(widget.latestWeightKg!)} kg'
                            : 'No weight logged yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('name_field'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('age_field'),
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('height_field'),
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('body_fat_field'),
                controller: _bodyFatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Body fat (%)'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('muscle_mass_field'),
                controller: _muscleMassController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Muscle mass (kg)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _savingProfile ? null : _saveProfile,
                child: Text(_savingProfile ? 'Saving...' : 'Save profile'),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: widget.onOpenGoals,
                child: const Text('Daily goals'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('sign_out_button'),
                onPressed: _signingOut ? null : _signOut,
                child: Text(_signingOut ? 'Signing out...' : 'Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
