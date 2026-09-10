import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:food_diary/l10n/generated/app_localizations.dart';

/// Wraps [home] in a MaterialApp configured with the app's localization
/// delegates, so widgets that call `AppLocalizations.of(context)` work
/// under test. Tests assert against the English strings (the default
/// locale here is `en`, matching `app_en.arb`) unless a test explicitly
/// passes a different `locale`.
Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
