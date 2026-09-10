# Thai Localization (i18n) — Design

**Status:** Approved by user, ready for planning.

## Goal

The app's UI is English-only today. Add switchable English/Thai
localization for every static UI string, with Thai as a first-class,
fully-translated language — not just scaffolding for future languages.

## Non-goals

- Translating AI-generated content. Gemini's food-item names, quantities,
  and any other analysis output stay in whatever language Gemini returns
  (English, since the Edge Function's prompt is English). Not in scope.
- A third language. The ARB structure will support adding more later, but
  only `en` and `th` ship now.
- Any change to `supabase/functions/analyze-food` or other server-side
  code. Localization is 100% client-side.
- Translating internal, non-user-facing exception messages (e.g.
  `lib/features/update/update_checker.dart`'s
  `Exception('Could not check for updates (...)')`) — confirmed these are
  always caught with a bare `catch (_)` in `profile_screen.dart` and never
  surfaced via `e.toString()`; the UI already shows its own separately
  authored message in those cases, and that separately authored message IS
  in scope (it's a real UI string).

## Architecture

### Library choice

Use Flutter's own official localization tooling — `flutter_localizations`
(SDK package) + `intl` + the `flutter gen-l10n` code generator — rather
than a JSON/magic-string package like `easy_localization`. Rationale:
zero extra abstraction, compile-time-checked accessors
(`AppLocalizations.of(context)!.someKey`, a typo is a build error not a
runtime miss), and it's the path every other Flutter-official doc and this
project's existing style (typed models, no stringly-typed lookups)
already favors.

Add dependencies via `flutter pub add`, letting pub resolve current
compatible versions (do not hand-pick version numbers in the plan — by
the time it executes, `flutter pub add` will pick whatever the SDK's
`flutter_localizations` constraint requires for `intl`, which floats):

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl
flutter pub add shared_preferences
```

### Codegen configuration

`l10n.yaml` at the repo root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n/generated
synthetic-package: false
nullable-getter: false
```

`synthetic-package: false` + explicit `output-dir` means the generated
class is imported as a normal package file —
`import 'package:food_diary/l10n/generated/app_localizations.dart';` —
not through the synthetic `package:flutter_gen/...` path (which has
caused stale-cache issues in some Flutter versions). `lib/l10n/generated/`
is generated on every `flutter pub get`/`build`/`test`/`run` (because
`generate: true` is added under `flutter:` in `pubspec.yaml`) and must be
added to `.gitignore` — it is never hand-edited or committed, matching how
this repo doesn't commit other tool-generated build output.

Source files (hand-written, committed):
- `lib/l10n/app_en.arb` — the template; every key is defined here first.
- `lib/l10n/app_th.arb` — every key from `app_en.arb` mirrored with a Thai
  value. `flutter gen-l10n` errors on a missing translation by default,
  which is the desired behavior — it makes a forgotten Thai string a build
  failure, not a silent English fallback.

### ARB key naming convention

Flat namespace (ARB/gen-l10n has no nesting), so keys are
`camelCase` and prefixed to avoid collisions:

- Screen/feature-specific: `<screenPrefix><Description>`, e.g.
  `loginEmailLabel`, `mealDetailChangeDateButton`,
  `diaryEmptyStateTitle`, `captureAnalyzeButton`.
- Truly generic, reused-in-3+-places words (Cancel, OK, Save, Delete):
  `common<Word>`, e.g. `commonCancel`, `commonSave`, `commonDelete`,
  `commonOk`. Before adding a new screen-specific key for one of these
  generic actions, check whether a `common*` key already covers it and
  reuse it — do not create a second key with the same English value.
- Parameterized strings use ARB placeholders, e.g.:
  ```json
  "profileUpdateAvailable": "Version {version} is available.",
  "@profileUpdateAvailable": {
    "placeholders": { "version": { "type": "String" } }
  }
  ```
  which generates `appLocalizations.profileUpdateAvailable(version)`.

Screen prefixes (fixed vocabulary, use exactly these):
`app` (MaterialApp-level/shared chrome), `login`, `signup`, `diary`,
`mealDetail`, `todaySummary`, `weeklySummary`, `weightCard`, `dateScroller`,
`capture`, `analysisResult`, `profile`, `weightTrend`, `settings`,
`language` (the new language-picker dialog).

### Locale switching

- `_FoodDiaryAppState` (`lib/main.dart`) owns a `Locale? _localeOverride`
  (`null` = follow system) loaded from `SharedPreferences` key
  `locale_code` (`'en'` / `'th'` / absent) in `initState`, applied via
  `setState` once loaded (a one-frame flash of system-locale content before
  the stored override applies is acceptable — this mirrors how
  `AuthState` already resolves asynchronously in this same widget).
- `MaterialApp`: `locale: _localeOverride`,
  `localizationsDelegates: AppLocalizations.localizationsDelegates`,
  `supportedLocales: AppLocalizations.supportedLocales` (generated to be
  exactly `[Locale('en'), Locale('th')]` from the two ARB files present).
  Flutter's default `localeListResolutionCallback` already does the right
  thing when `locale` is `null`: match the device's locale against
  `supportedLocales` by language code, else fall back to the first
  supported locale (`en`, since `app_en.arb` is the template and therefore
  first). No custom resolution callback is needed.
- New reusable widget: a language-picker (e.g.
  `lib/features/settings/language_picker.dart`) — a `showDialog` with 3
  radio options: System default / English / ไทย (each option's own label
  is hardcoded in both languages directly — "ไทย" and "English" are proper
  nouns for the language itself and are NOT translated per the selected
  locale, they always show in their own language so a user who can't read
  the current locale can still find their way back). Selecting persists to
  `SharedPreferences` and calls a passed-in `ValueChanged<Locale?>`
  callback.
- `ProfileScreen` gets a new "Language" row (next to the existing "Daily
  goals" and "Sign out" rows) that opens this dialog. `ProfileScreen`'s
  constructor gains `currentLocale` (`Locale?`) and `onLocaleChanged`
  (`ValueChanged<Locale?>`) parameters, threaded from `_FoodDiaryAppState`
  through `_HomeShell` the same way other cross-cutting callbacks
  (`onSaveProfile`, etc.) already are.
- Changing the language calls `setState` in `_FoodDiaryAppState` — the
  whole widget tree rebuilds under the new `Locale` immediately, no app
  restart, matching how theme/auth-state changes already propagate in this
  file.

### Testing strategy

Widget tests currently wrap screens directly in a bare `MaterialApp(home:
...)` (or push routes onto one) with no localization delegates configured
— once real code calls `AppLocalizations.of(context)!`, that throws
`Null check operator used on a null value` under the current test setup.

Add `test/test_utils.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:food_diary/l10n/generated/app_localizations.dart';

/// Wraps [home] in a MaterialApp configured with the app's localization
/// delegates, so widgets that call `AppLocalizations.of(context)!` work
/// under test. Tests assert against the English strings (the test default
/// locale is `en`, matching `app_en.arb`) unless a test explicitly passes
/// a different `locale`.
Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
```

Every existing test file that pumps a screen wrapped in a bare
`MaterialApp(home: ...)` must switch to `localizedApp(...)`. Tests keep
asserting against literal English strings exactly as today (e.g.
`find.text('Delete this meal?')`) — the string's *source* moves from a Dart
literal to `app_en.arb`, but its *value* is unchanged, so no test
assertion text needs editing, only the wrapping widget. A test that
constructs its own `MaterialApp` for a specific reason (e.g. testing
routing via `Navigator.push` inside a pushed route, as
`meal_detail_screen_test.dart`'s `_pushScreen` helper already does) needs
the same delegates added to that specific `MaterialApp` construction, not
necessarily switched to call `localizedApp` if the helper's shape doesn't
fit — use judgment per file, the goal is delegates present everywhere a
`MaterialApp` is constructed in a test, however that's wired.

## Task breakdown (for the implementation plan)

Four tasks, executed in order (each depends on Task 1's scaffolding；
Tasks 2-4 are independent of each other and touch disjoint files):

1. **Infra + Auth + language switcher.** Add the three dependencies,
   `l10n.yaml`, `.gitignore` entry for `lib/l10n/generated/`, `generate:
   true` in `pubspec.yaml`, the initial `app_en.arb`/`app_th.arb` (only
   the keys this task needs — `app*`, `login*`, `signup*`, `language*`,
   and any `common*` keys these two screens introduce). Wire
   `MaterialApp` in `lib/main.dart` (delegates, supportedLocales, locale
   state + persistence). Build the language-picker dialog and wire it
   into a new row in `ProfileScreen` (constructor params only — the rest
   of `ProfileScreen`'s strings are Task 4's job, touch nothing else in
   that file). Extract every string in `login_screen.dart` and
   `signup_screen.dart`. Add `test/test_utils.dart`. Update
   `test/features/auth/*_test.dart` (and any `main.dart`-level test, if
   one exists) to use it. This task proves the whole pipeline end-to-end
   before Tasks 2-4 repeat the pattern at scale.
2. **Diary.** Extract every string in `diary_screen.dart`,
   `meal_detail_screen.dart`, `today_summary_card.dart`,
   `weekly_summary_card.dart`, `weight_card.dart`, `date_scroller.dart`.
   Add their ARB keys (`diary*`, `mealDetail*`, `todaySummary*`,
   `weeklySummary*`, `weightCard*`, `dateScroller*`, reusing `common*`
   where applicable) to both ARB files. Update
   `test/features/diary/*_test.dart` to use `localizedApp`.
3. **Analyze.** Extract every string in `capture_screen.dart`,
   `analysis_result_screen.dart`, and `AnalyzeException.userMessage` in
   `analyze_repository.dart`. Add `capture*`, `analysisResult*` ARB keys.
   Update `test/features/analyze/*_test.dart`.
4. **Profile + Settings.** Extract every remaining string in
   `profile_screen.dart` (everything except the Language row, already
   done in Task 1), `weight_trend_card.dart`, `settings_screen.dart`. Add
   `profile*`, `weightTrend*`, `settings*` ARB keys. Update
   `test/features/profile/*_test.dart` and
   `test/features/settings/*_test.dart`.

Each task's ARB additions include BOTH `app_en.arb` and `app_th.arb`
entries — no task hands off "translate this later." A task is not done
until `flutter gen-l10n` succeeds with zero missing-translation errors for
the keys it touches.

## Rollout

No database migration, no Edge Function change, no new Supabase
credential. Ships in the existing release pipeline (version bump → APK
build → GitHub Release) exactly like every other feature this session.
Existing users get the new "Language" row on their next update; their
locale defaults to their device's system locale on first run after
updating (no stored preference yet → `_localeOverride` stays `null`).
