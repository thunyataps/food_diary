import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../update/update_checker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.latestWeightKg,
    required this.initialProfile,
    required this.onSaveProfile,
    required this.onOpenGoals,
    required this.onSignOut,
    required this.currentVersion,
    required this.onCheckForUpdate,
    required this.onDownloadAndInstall,
  });

  final String email;
  final double? latestWeightKg;
  final UserProfile? initialProfile;
  final Future<void> Function(UserProfile profile) onSaveProfile;
  final VoidCallback onOpenGoals;
  final Future<void> Function() onSignOut;

  final String currentVersion;
  final Future<ReleaseInfo?> Function(String currentVersion) onCheckForUpdate;
  final Future<void> Function(String apkDownloadUrl) onDownloadAndInstall;

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

  // The caller typically wraps this screen in a FutureBuilder while it
  // fetches the profile, so `initialProfile` is often still null on the
  // very first build. Sync the fields once real data arrives, but only
  // the first time — after that, further rebuilds must not clobber
  // whatever the user is actively typing.
  //
  // Set in initState (not a `late` initializer): `late` fields evaluate
  // lazily on first read, and the first read here would happen inside
  // didUpdateWidget — by which point `widget` already points at the new,
  // non-null-profile widget, making the guard always true.
  bool _syncedFromProfile = false;

  @override
  void initState() {
    super.initState();
    _syncedFromProfile = widget.initialProfile != null;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final profile = widget.initialProfile;
    if (!_syncedFromProfile && profile != null) {
      _nameController.text = profile.name ?? '';
      _ageController.text = profile.age?.toString() ?? '';
      _heightController.text = _formatOrEmpty(profile.heightCm);
      _bodyFatController.text = _formatOrEmpty(profile.bodyFatPct);
      _muscleMassController.text = _formatOrEmpty(profile.muscleMassKg);
      _syncedFromProfile = true;
    }
  }

  bool _savingProfile = false;
  bool _signingOut = false;
  bool _checkingForUpdate = false;
  String? _error;
  String? _updateStatus;

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

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingForUpdate = true;
      _updateStatus = null;
    });
    try {
      final release = await widget.onCheckForUpdate(widget.currentVersion);
      if (!mounted) return;
      if (release == null) {
        setState(() => _updateStatus = "You're on the latest version.");
        return;
      }
      setState(() => _updateStatus = 'Version ${release.version} is available.');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
              'Version ${release.version} is available (you have ${widget.currentVersion}). Download and install it now?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true), child: const Text('Download & install')),
          ],
        ),
      );
      if (confirmed == true) {
        await widget.onDownloadAndInstall(release.apkDownloadUrl);
      }
    } catch (_) {
      if (mounted) setState(() => _updateStatus = 'Could not check for updates. Try again.');
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
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
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _checkingForUpdate ? null : _checkForUpdate,
                child: Text(_checkingForUpdate ? 'Checking...' : 'Check for updates'),
              ),
              if (_updateStatus != null) ...[
                const SizedBox(height: 8),
                Text(_updateStatus!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              Text(
                'v${widget.currentVersion}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
