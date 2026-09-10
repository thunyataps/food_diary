import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../models/weight_log.dart';
import '../settings/language_picker.dart';
import '../update/update_checker.dart';
import 'weight_trend_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.latestWeightKg,
    required this.recentWeights,
    required this.initialProfile,
    required this.onSaveProfile,
    required this.onOpenGoals,
    required this.onSignOut,
    required this.currentVersion,
    required this.onCheckForUpdate,
    required this.onDownloadAndInstall,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  final String email;
  final double? latestWeightKg;

  /// Weight history for the trend chart (e.g. the last 30 days), already
  /// fetched by the caller. Defaults to empty while loading.
  final List<WeightLog> recentWeights;
  final UserProfile? initialProfile;
  final Future<void> Function(UserProfile profile) onSaveProfile;
  final VoidCallback onOpenGoals;
  final Future<void> Function() onSignOut;

  final String currentVersion;
  final Future<ReleaseInfo?> Function(String currentVersion) onCheckForUpdate;
  final Future<void> Function(String apkDownloadUrl) onDownloadAndInstall;

  final Locale? currentLocale;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // What view mode displays. Starts from widget.initialProfile, but the
  // caller typically wraps this screen in a FutureBuilder while it fetches
  // the profile, so initialProfile is often still null on the very first
  // build — adopt it once it arrives (see didUpdateWidget), and update it
  // locally on a successful save so the view reflects the edit immediately
  // rather than waiting on the caller's own refetch.
  UserProfile? _displayProfile;

  bool _editing = false;
  TextEditingController? _nameController;
  TextEditingController? _ageController;
  TextEditingController? _heightController;
  TextEditingController? _bodyFatController;
  TextEditingController? _muscleMassController;

  bool _savingProfile = false;
  bool _signingOut = false;
  bool _checkingForUpdate = false;
  String? _error;
  String? _updateStatus;

  static String _formatOrDash(BuildContext context, double? value) =>
      value == null
      ? AppLocalizations.of(context).profileDashPlaceholder
      : _formatNumber(value);

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void initState() {
    super.initState();
    _displayProfile = widget.initialProfile;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_displayProfile == null && widget.initialProfile != null) {
      setState(() => _displayProfile = widget.initialProfile);
    }
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _ageController?.dispose();
    _heightController?.dispose();
    _bodyFatController?.dispose();
    _muscleMassController?.dispose();
    super.dispose();
  }

  void _startEditing() {
    final profile = _displayProfile;
    setState(() {
      _nameController = TextEditingController(text: profile?.name ?? '');
      _ageController = TextEditingController(
        text: profile?.age?.toString() ?? '',
      );
      _heightController = TextEditingController(
        text: _formatOrEmpty(profile?.heightCm),
      );
      _bodyFatController = TextEditingController(
        text: _formatOrEmpty(profile?.bodyFatPct),
      );
      _muscleMassController = TextEditingController(
        text: _formatOrEmpty(profile?.muscleMassKg),
      );
      _error = null;
      _editing = true;
    });
  }

  static String _formatOrEmpty(double? value) =>
      value == null ? '' : _formatNumber(value);

  void _cancelEditing() {
    setState(() {
      _nameController?.dispose();
      _ageController?.dispose();
      _heightController?.dispose();
      _bodyFatController?.dispose();
      _muscleMassController?.dispose();
      _nameController = null;
      _ageController = null;
      _heightController = null;
      _bodyFatController = null;
      _muscleMassController = null;
      _error = null;
      _editing = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _error = null;
    });
    final edited = UserProfile(
      name: _nameController!.text.trim().isEmpty
          ? null
          : _nameController!.text.trim(),
      age: int.tryParse(_ageController!.text),
      heightCm: double.tryParse(_heightController!.text),
      bodyFatPct: double.tryParse(_bodyFatController!.text),
      muscleMassKg: double.tryParse(_muscleMassController!.text),
    );
    try {
      await widget.onSaveProfile(edited);
      if (mounted) {
        _nameController?.dispose();
        _ageController?.dispose();
        _heightController?.dispose();
        _bodyFatController?.dispose();
        _muscleMassController?.dispose();
        setState(() {
          _displayProfile = edited;
          _nameController = null;
          _ageController = null;
          _heightController = null;
          _bodyFatController = null;
          _muscleMassController = null;
          _editing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).profileSaveError);
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileSignOutError)),
        );
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
      final l10n = AppLocalizations.of(context);
      if (release == null) {
        setState(() => _updateStatus = l10n.profileUpdateLatestVersion);
        return;
      }
      setState(
        () =>
            _updateStatus = l10n.profileUpdateAvailableStatus(release.version),
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final dialogL10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(dialogL10n.profileUpdateDialogTitle),
            content: Text(
              dialogL10n.profileUpdateDialogBody(
                release.version,
                widget.currentVersion,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(dialogL10n.profileUpdateNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(dialogL10n.profileUpdateDownloadInstall),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await widget.onDownloadAndInstall(release.apkDownloadUrl);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _updateStatus = AppLocalizations.of(context)
                  .profileUpdateCheckError,
        );
      }
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }

  Widget _fieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    final profile = _displayProfile;
    final l10n = AppLocalizations.of(context);
    final dash = l10n.profileDashPlaceholder;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.profilePersonalInfoTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  key: const Key('edit_profile_button'),
                  tooltip: l10n.profileEditTooltip,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _startEditing,
                ),
              ],
            ),
            _fieldRow(l10n.profileNameLabel, profile?.name ?? dash),
            _fieldRow(l10n.profileAgeLabel, profile?.age?.toString() ?? dash),
            _fieldRow(
              l10n.profileWeightLabel,
              _formatOrDash(context, widget.latestWeightKg),
            ),
            _fieldRow(
              l10n.profileHeightLabel,
              _formatOrDash(context, profile?.heightCm),
            ),
            _fieldRow(
              l10n.profileBodyFatLabel,
              _formatOrDash(context, profile?.bodyFatPct),
            ),
            _fieldRow(
              l10n.profileMuscleMassLabel,
              _formatOrDash(context, profile?.muscleMassKg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode() {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileEditPersonalInfoTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('name_field'),
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.profileNameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('age_field'),
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.profileAgeLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('height_field'),
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.profileHeightLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('body_fat_field'),
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.profileBodyFatLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('muscle_mass_field'),
              controller: _muscleMassController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.profileMuscleMassLabel,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _savingProfile ? null : _cancelEditing,
                    child: Text(l10n.profileCancelButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _savingProfile ? null : _saveProfile,
                    child: Text(
                      _savingProfile
                          ? l10n.commonSaving
                          : l10n.profileSaveButton,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAppBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.email,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _editing ? _buildEditMode() : _buildViewMode(),
              const SizedBox(height: 16),
              WeightTrendCard(weights: widget.recentWeights),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: widget.onOpenGoals,
                child: Text(l10n.profileGoalsButton),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('language_button'),
                onPressed: () => showLanguagePicker(
                  context: context,
                  currentLocale: widget.currentLocale,
                  onChanged: widget.onLocaleChanged,
                ),
                child: Text(l10n.languageDialogTitle),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('sign_out_button'),
                onPressed: _signingOut ? null : _signOut,
                child: Text(
                  _signingOut
                      ? l10n.profileSigningOutButton
                      : l10n.profileSignOutButton,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _checkingForUpdate ? null : _checkForUpdate,
                child: Text(
                  _checkingForUpdate
                      ? l10n.profileCheckingButton
                      : l10n.profileCheckForUpdatesButton,
                ),
              ),
              if (_updateStatus != null) ...[
                const SizedBox(height: 8),
                Text(_updateStatus!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.profileVersionLabel(widget.currentVersion),
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
