import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shows a radio-list dialog letting the user pick System default / English
/// / ไทย. `English` and `ไทย` are locale-INVARIANT display names (shown in
/// their own language always, regardless of the app's current locale) so a
/// user who can't read the current locale can still find their way back —
/// they are plain string constants here, not ARB keys.
Future<void> showLanguagePicker({
  required BuildContext context,
  required Locale? currentLocale,
  required ValueChanged<Locale?> onChanged,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.languageDialogTitle),
      children: [
        RadioGroup<Locale?>(
          groupValue: currentLocale,
          onChanged: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<Locale?>(
                key: const Key('language_option_system'),
                title: Text(l10n.languageSystemDefault),
                value: null,
              ),
              const RadioListTile<Locale?>(
                key: Key('language_option_en'),
                title: Text('English'),
                value: Locale('en'),
              ),
              const RadioListTile<Locale?>(
                key: Key('language_option_th'),
                title: Text('ไทย'),
                value: Locale('th'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
