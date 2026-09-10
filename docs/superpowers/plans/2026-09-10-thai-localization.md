# Thai Localization (i18n) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app's UI switchable between English and Thai, with every static string translated, using Flutter's official `flutter_localizations`/`intl`/`gen-l10n` tooling.

**Architecture:** ARB-file-driven codegen (`lib/l10n/app_en.arb` + `lib/l10n/app_th.arb` → generated `AppLocalizations` class), a persisted locale override (`shared_preferences`) read/written from `lib/main.dart`, and a new language-picker UI reachable from the Profile screen. Four tasks: infra+auth+switcher, then diary, analyze, and profile+settings each extract their own screens' strings.

**Tech Stack:** `flutter_localizations` (SDK), `intl`, `shared_preferences`, Flutter's `flutter gen-l10n` codegen (`generate: true` in `pubspec.yaml`).

**Spec:** `docs/superpowers/specs/2026-09-10-thai-localization-design.md`

## Global Constraints

- Every ARB key added in any task MUST have both an `app_en.arb` and an `app_th.arb` entry in the same task/commit — never leave a Thai value for "later."
- ARB key naming: `camelCase`, prefixed `<screen><Description>` for screen-specific strings, `common<Word>` for strings reused across 3+ screens (exact list of `common*` keys is fixed by Task 1 and extended only by later tasks per the tables below — do not invent a new `common*` key without checking this plan's tables first for an existing one with the same English value).
- Unit abbreviations (`kcal`, `g`, `kg`, `cm`, `%`) are NOT translated — their Thai ARB value is identical to the English value (these are metric/scientific notation, not natural-language words; Thai nutrition/fitness apps keep them as-is). Still go through ARB (not hardcoded) for consistency, but `app_th.arb`'s value literally equals `app_en.arb`'s value for these specific keys.
- The language names `English`/`ไทย` shown inside the language-picker dialog are locale-**invariant** display names (a Thai speaker must be able to find "English" even while the UI is stuck in Thai, and vice versa) — these are plain Dart string constants in the widget code, NOT ARB keys. Do not add `languageEnglish`/`languageThai` to the ARB files.
- `flutter gen-l10n` (run automatically by `flutter build`/`test`/`analyze`/`run` because of `generate: true`) must succeed with zero missing-translation errors after every task. Run `flutter analyze` and `flutter test` before every commit in every task.
- Existing test assertions (`find.text('English string')`) keep asserting the exact same English string values — the string's *source* moves from a Dart literal to `app_en.arb`, its *value* does not change. Do not alter an assertion's expected text unless the table below shows a different value for that key than what's currently in the source file (there are none in this plan — every table entry's English value is copied verbatim from the current source).
- Never hand-pick dependency version numbers — add them with `flutter pub add` (Task 1 only; no other task touches `pubspec.yaml`) and let pub resolve current compatible versions.
- `AnalyzeException.userMessage` (in `lib/features/analyze/analyze_repository.dart`) is a getter on a plain Dart exception class with no `BuildContext` — it cannot call `AppLocalizations.of(context)!` itself. Task 3 changes it from a getter to a method `String userMessage(AppLocalizations l10n)`, called as `e.userMessage(AppLocalizations.of(context)!)` from `capture_screen.dart`, where context is available.
- `MaterialApp.title` cannot read `AppLocalizations.of(context)!` directly (the `context` passed to the widget's own `build()` is above the `Localizations` scope `MaterialApp` itself creates). Task 1 uses `onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle` instead of a static `title:` string — `onGenerateTitle` receives a context that IS inside the scope.

---

### Task 1: Infra, ARB scaffolding, auth screens, language switcher

**Files:**
- Modify: `pubspec.yaml` (add deps, `generate: true`)
- Create: `l10n.yaml`
- Modify: `.gitignore` (add `lib/l10n/generated/`)
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/app_th.arb`
- Create: `test/test_utils.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/auth/login_screen.dart`
- Modify: `lib/features/auth/signup_screen.dart`
- Create: `lib/features/settings/language_picker.dart`
- Modify: `lib/features/profile/profile_screen.dart` (constructor params + one new "Language" row ONLY — every other string in this file is Task 4's job)
- Create: `test/features/settings/language_picker_test.dart`
- Create: `test/features/auth/login_screen_test.dart` (none exists today)
- Modify: `test/features/auth/signup_screen_test.dart`
- Modify any other test that constructs a bare `MaterialApp(home: ...)` around a widget touched by this task (check `test/features/profile/profile_screen_test.dart` — it will need the new constructor params supplied even though this task doesn't touch its other strings)

**Interfaces:**
- Produces: `lib/l10n/generated/app_localizations.dart` (generated, gitignored — not created by hand, appears after `flutter pub get`/`test`/`build` once `l10n.yaml` + `generate: true` + the two ARB files exist). Import path for every file in every task: `import 'package:food_diary/l10n/generated/app_localizations.dart';`.
- Produces: `Widget localizedApp(Widget home, {Locale locale = const Locale('en')})` in `test/test_utils.dart` — every later task's test files use this.
- Produces: `lib/features/settings/language_picker.dart` exporting `Future<void> showLanguagePicker({required BuildContext context, required Locale? currentLocale, required ValueChanged<Locale?> onChanged})`.
- Produces: `ProfileScreen` constructor gains two new required params: `currentLocale` (`Locale?`) and `onLocaleChanged` (`ValueChanged<Locale?>`) — Tasks 2-4 don't touch `ProfileScreen`'s constructor again, but Task 4 must know these params exist when it works on the rest of the file.
- Consumes: nothing from other tasks (this task runs first).

#### ARB keys this task owns

Add these to BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_th.arb`. ARB format reminder: each key is a top-level JSON string entry; a placeholder key needs a sibling `@keyName` metadata entry (example given for the one parameterized string below).

| Key | English (`app_en.arb`) | Thai (`app_th.arb`) |
|---|---|---|
| `appTitle` | `Food Diary` | `ไดอารี่อาหาร` |
| `commonEmailLabel` | `Email` | `อีเมล` |
| `commonPasswordLabel` | `Password` | `รหัสผ่าน` |
| `commonCreateAccount` | `Create account` | `สร้างบัญชี` |
| `commonCancel` | `Cancel` | `ยกเลิก` |
| `commonSaving` | `Saving...` | `กำลังบันทึก...` |
| `commonCalories` | `Calories` | `แคลอรี่` |
| `commonProtein` | `Protein` | `โปรตีน` |
| `commonCarb` | `Carb` | `คาร์บ` |
| `commonFat` | `Fat` | `ไขมัน` |
| `commonKcalUnit` | `kcal` | `kcal` |
| `commonGramUnit` | `g` | `g` |
| `loginSignInButton` | `Sign in` | `เข้าสู่ระบบ` |
| `loginGoogleButton` | `Continue with Google` | `เข้าสู่ระบบด้วย Google` |
| `loginErrorFailed` | `Sign in failed. Check your email/password.` | `เข้าสู่ระบบไม่สำเร็จ ตรวจสอบอีเมล/รหัสผ่านอีกครั้ง` |
| `signupButton` | `Sign up` | `สมัครสมาชิก` |
| `signupErrorFailed` | `Sign up failed: {error}` | `สมัครสมาชิกไม่สำเร็จ: {error}` |
| `signupInfoCheckEmail` | `Check your email to confirm your account, then come back and sign in.` | `ตรวจสอบอีเมลเพื่อยืนยันบัญชี แล้วกลับมาเข้าสู่ระบบอีกครั้ง` |
| `languageDialogTitle` | `Language` | `ภาษา` |
| `languageSystemDefault` | `System default` | `ตามภาษาเครื่อง` |

`signupErrorFailed` needs a placeholder. In `app_en.arb`:
```json
"signupErrorFailed": "Sign up failed: {error}",
"@signupErrorFailed": {
  "placeholders": { "error": { "type": "String" } }
}
```
(mirror the same `"signupErrorFailed": "สมัครสมาชิกไม่สำเร็จ: {error}"` value in `app_th.arb`, no `@` metadata needed in the translation file — `@` metadata lives only in the template file, `app_en.arb`).

Every other key above is a plain string, no placeholder.

`app_en.arb` also needs the standard top-level locale key:
```json
"@@locale": "en"
```
and `app_th.arb`:
```json
"@@locale": "th"
```

- [ ] **Step 1: Add dependencies**

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl
flutter pub add shared_preferences
```

- [ ] **Step 2: Add `generate: true` to `pubspec.yaml`**

Under the existing `flutter:` top-level key (alongside `uses-material-design: true`), add:

```yaml
  generate: true
```

- [ ] **Step 3: Create `l10n.yaml`** at the repo root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n/generated
synthetic-package: false
nullable-getter: false
```

- [ ] **Step 4: Gitignore the generated output**

Add a line to `.gitignore`:
```
lib/l10n/generated/
```

- [ ] **Step 5: Create `lib/l10n/app_en.arb` and `lib/l10n/app_th.arb`**

Populate both with exactly the keys/values from the table above (plus the `@@locale` and `@signupErrorFailed` entries shown above). Standard ARB is a flat JSON object.

- [ ] **Step 6: Run `flutter pub get` and confirm codegen succeeds**

```bash
flutter pub get
```
Confirm `lib/l10n/generated/app_localizations.dart` now exists (it's gitignored, this just verifies codegen ran with no missing-translation errors).

- [ ] **Step 7: Wire `MaterialApp` in `lib/main.dart`**

Add imports:
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/generated/app_localizations.dart';
```

In `_FoodDiaryAppState`, add locale state, loaded in `initState`:

```dart
Locale? _localeOverride;

@override
void initState() {
  super.initState();
  _loadLocale();
}

Future<void> _loadLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('locale_code');
  if (code != null && mounted) {
    setState(() => _localeOverride = Locale(code));
  }
}

Future<void> _setLocale(Locale? locale) async {
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove('locale_code');
  } else {
    await prefs.setString('locale_code', locale.languageCode);
  }
  setState(() => _localeOverride = locale);
}
```

Update the `MaterialApp` returned from `build`: replace `title: 'Food Diary',` with:

```dart
onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
locale: _localeOverride,
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,
```

(keep `theme: appTheme,` and everything else as-is.)

Thread `currentLocale: _localeOverride` and `onLocaleChanged: _setLocale` down through `_HomeShell`'s constructor to `ProfileScreen`'s constructor call site (the same way `authRepository`, `diaryRepository`, etc. are already threaded — add the two new named parameters to `_HomeShell`'s constructor and pass them through to the `ProfileScreen(...)` call inside `_HomeShell`'s `build`).

- [ ] **Step 8: Create `lib/features/settings/language_picker.dart`**

```dart
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
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.languageDialogTitle),
      children: [
        RadioListTile<Locale?>(
          key: const Key('language_option_system'),
          title: Text(l10n.languageSystemDefault),
          value: null,
          groupValue: currentLocale,
          onChanged: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
        ),
        RadioListTile<Locale?>(
          key: const Key('language_option_en'),
          title: const Text('English'),
          value: const Locale('en'),
          groupValue: currentLocale,
          onChanged: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
        ),
        RadioListTile<Locale?>(
          key: const Key('language_option_th'),
          title: const Text('ไทย'),
          value: const Locale('th'),
          groupValue: currentLocale,
          onChanged: (value) {
            onChanged(value);
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
```

- [ ] **Step 9: Add the "Language" row to `ProfileScreen`**

In `lib/features/profile/profile_screen.dart`: add `currentLocale` (`Locale?`) and `onLocaleChanged` (`ValueChanged<Locale?>`) as new required named constructor parameters (alongside `email`, `onSignOut`, etc.). Import `language_picker.dart` and `app_localizations.dart`. In `build()`, add a new `OutlinedButton` row — same visual pattern as the existing `Daily goals` button — right after it:

```dart
const SizedBox(height: 12),
OutlinedButton(
  key: const Key('language_button'),
  onPressed: () => showLanguagePicker(
    context: context,
    currentLocale: widget.currentLocale,
    onChanged: widget.onLocaleChanged,
  ),
  child: Text(AppLocalizations.of(context)!.languageDialogTitle),
),
```

Do NOT touch any other string in this file — every other `Text(...)`/`labelText`/etc. in `profile_screen.dart` is Task 4's responsibility.

- [ ] **Step 10: Extract every string in `lib/features/auth/login_screen.dart`**

Import `../../l10n/generated/app_localizations.dart`. Replace each literal with the matching key from the table above via `AppLocalizations.of(context)!.<key>`:
- `'Food Diary'` → `appTitle`
- `labelText: 'Email'` → `labelText: AppLocalizations.of(context)!.commonEmailLabel`
- `labelText: 'Password'` → `commonPasswordLabel`
- `'Sign in failed. Check your email/password.'` → `loginErrorFailed`
- `'Sign in'` → `loginSignInButton`
- `'Continue with Google'` → `loginGoogleButton`
- `'Create account'` → `commonCreateAccount`

- [ ] **Step 11: Extract every string in `lib/features/auth/signup_screen.dart`**

- AppBar `'Create account'` → `commonCreateAccount`
- `labelText: 'Email'` → `commonEmailLabel`
- `labelText: 'Password'` → `commonPasswordLabel`
- `'Check your email to confirm your account, then come back and sign in.'` → `signupInfoCheckEmail`
- `'Sign up failed: $e'` → `AppLocalizations.of(context)!.signupErrorFailed(e.toString())`
- `'Sign up'` → `signupButton`

- [ ] **Step 12: Create `test/test_utils.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:food_diary/l10n/generated/app_localizations.dart';

/// Wraps [home] in a MaterialApp configured with the app's localization
/// delegates, so widgets that call `AppLocalizations.of(context)!` work
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
```

- [ ] **Step 13: Write `test/features/settings/language_picker_test.dart`** (TDD — write this test first, confirm it fails against a stub, then Step 8/9 above make it pass; since this plan lists Step 8 before this step for readability, when actually executing: write this test FIRST, run it, watch it fail with "no such file", THEN do Steps 8-9, then rerun to green)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/settings/language_picker.dart';

import '../../test_utils.dart';

void main() {
  testWidgets('shows System default, English, and ไทย options', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showLanguagePicker(
              context: context,
              currentLocale: null,
              onChanged: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('ไทย'), findsOneWidget);
  });

  testWidgets('picking English calls onChanged with Locale("en") and closes the dialog', (tester) async {
    Locale? picked;
    var pickedFlag = false;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showLanguagePicker(
              context: context,
              currentLocale: null,
              onChanged: (value) {
                picked = value;
                pickedFlag = true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language_option_en')));
    await tester.pumpAndSettle();

    expect(pickedFlag, true);
    expect(picked, const Locale('en'));
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('picking System default calls onChanged with null', (tester) async {
    Locale? picked = const Locale('en');
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showLanguagePicker(
              context: context,
              currentLocale: const Locale('en'),
              onChanged: (value) => picked = value,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language_option_system')));
    await tester.pumpAndSettle();

    expect(picked, null);
  });
}
```

Run: `flutter test test/features/settings/language_picker_test.dart` — expect PASS after Steps 8-9 are done.

- [ ] **Step 14: Create `test/features/auth/login_screen_test.dart`**

No test file exists for `login_screen.dart` today. Add basic coverage (mirror `test/features/auth/signup_screen_test.dart`'s existing style/fakes for `AuthRepository` — read that file first to copy its fake pattern):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/auth/login_screen.dart';

import '../../test_utils.dart';
// import whatever fake AuthRepository pattern signup_screen_test.dart uses

void main() {
  testWidgets('shows email and password fields, sign in button', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        LoginScreen(
          authRepository: /* fake, matching signup_screen_test.dart's pattern */,
          onSignedIn: () {},
        ),
      ),
    );
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
```

- [ ] **Step 15: Update `test/features/auth/signup_screen_test.dart`**

Replace every bare `MaterialApp(home: SignupScreen(...))` (or however it currently wraps the widget — read the file first) with `localizedApp(SignupScreen(...))`. Keep every existing assertion's text unchanged (all values above are copied verbatim from the current source).

- [ ] **Step 16: Update `test/features/profile/profile_screen_test.dart`**

This task added two new REQUIRED constructor params (`currentLocale`, `onLocaleChanged`) to `ProfileScreen`. Every existing `ProfileScreen(...)` construction in this test file needs those two params added (e.g. `currentLocale: null, onLocaleChanged: (_) {},`) or the file won't compile. Do NOT touch any other assertion in this file — Task 4 handles the rest of `profile_screen.dart`'s strings later. Also wrap with `localizedApp(...)` instead of a bare `MaterialApp` if it isn't already (needed because the new Language button's label now goes through `AppLocalizations`).

- [ ] **Step 17: Run full verification**

```bash
flutter analyze
flutter test
```
Fix anything red. `flutter analyze` must be clean (only the pre-existing `anonKey` deprecation info is acceptable). `flutter test` must be 100% green.

- [ ] **Step 18: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml .gitignore lib/l10n/app_en.arb lib/l10n/app_th.arb lib/main.dart lib/features/auth/login_screen.dart lib/features/auth/signup_screen.dart lib/features/settings/language_picker.dart lib/features/profile/profile_screen.dart test/test_utils.dart test/features/settings/language_picker_test.dart test/features/auth/login_screen_test.dart test/features/auth/signup_screen_test.dart test/features/profile/profile_screen_test.dart
git commit -m "Add Thai/English localization infra, auth screens, language switcher

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019w7Pizw15HziWNCZBprajr"
```

---

### Task 2: Diary feature

**Files:**
- Modify: `lib/features/diary/diary_screen.dart`
- Modify: `lib/features/diary/meal_detail_screen.dart`
- Modify: `lib/features/diary/today_summary_card.dart`
- Modify: `lib/features/diary/weekly_summary_card.dart`
- Modify: `lib/features/diary/weight_card.dart`
- Modify: `lib/features/diary/date_scroller.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_th.arb`
- Modify: `test/features/diary/diary_screen_test.dart`, `meal_detail_screen_test.dart`, `today_summary_card_test.dart`, `weekly_summary_card_test.dart`, `weight_card_test.dart`, `date_scroller_test.dart`

**Interfaces:**
- Consumes: `appTitle`, `commonCalories`, `commonProtein`, `commonCarb`, `commonFat`, `commonKcalUnit`, `commonGramUnit`, `commonCancel`, `commonSaving` (all defined by Task 1 — do not redefine). `localizedApp` from `test/test_utils.dart`.
- Produces: `diary*`, `mealDetail*`, `todaySummary*`, `weeklySummary*`, `weightCard*` ARB keys (table below) — no later task consumes these.

#### ARB keys this task owns

| Key | English | Thai |
|---|---|---|
| `diaryEmptyStateTitle` | `No meals logged yet` | `ยังไม่มีมื้ออาหารที่บันทึก` |
| `diaryEmptyStateSubtitle` | `Tap Add meal to log what you ate` | `แตะ "เพิ่มมื้ออาหาร" เพื่อบันทึกสิ่งที่คุณกิน` |
| `mealDetailAppBarTitle` | `Meal details` | `รายละเอียดมื้ออาหาร` |
| `mealDetailLoggedOn` | `Logged on {date}` | `บันทึกเมื่อ {date}` |
| `mealDetailChangeDate` | `Change date` | `เปลี่ยนวันที่` |
| `mealDetailUpdateDateError` | `Could not update the date. Please try again.` | `ไม่สามารถอัปเดตวันที่ได้ กรุณาลองอีกครั้ง` |
| `mealDetailDeleteConfirmTitle` | `Delete this meal?` | `ลบมื้ออาหารนี้?` |
| `mealDetailDeleteConfirmBody` | `This can't be undone.` | `การกระทำนี้ไม่สามารถย้อนกลับได้` |
| `mealDetailDeleteButton` | `Delete` | `ลบ` |
| `mealDetailDeleteError` | `Could not delete this meal. Please try again.` | `ไม่สามารถลบมื้ออาหารนี้ได้ กรุณาลองอีกครั้ง` |
| `mealDetailTotalsTitle` | `Totals` | `รวมทั้งหมด` |
| `todaySummaryTitle` | `Today's summary` | `สรุปวันนี้` |
| `weeklySummaryTitle` | `7-day average` | `ค่าเฉลี่ย 7 วัน` |
| `weightCardLabel` | `Weight (kg)` | `น้ำหนัก (kg)` |
| `weightCardSaveButton` | `Save` | `บันทึก` |
| `weightCardInvalidError` | `Enter a valid weight.` | `กรอกน้ำหนักให้ถูกต้อง` |
| `weightCardSaveError` | `Could not save weight. Try again.` | `ไม่สามารถบันทึกน้ำหนักได้ ลองอีกครั้ง` |

`mealDetailLoggedOn` needs a placeholder:
```json
"mealDetailLoggedOn": "Logged on {date}",
"@mealDetailLoggedOn": {
  "placeholders": { "date": { "type": "String" } }
}
```

Note: `date_scroller.dart`'s weekday labels (`Mon`/`Tue`/.../`Sun`) and `meal_detail_screen.dart`'s hand-rolled `_monthNames`/`_formatDate` are NOT translated via ARB — replace them with `intl`'s locale-aware `DateFormat` instead (see Step 4 and Step 2 below). This is strictly better than manually maintaining Thai day/month name arrays and resolves a duplicated-helper cleanup that was already flagged as tech debt in an earlier code review.

- [ ] **Step 1: Add this task's keys to `lib/l10n/app_en.arb` and `lib/l10n/app_th.arb`**

Add every row from the table above (plus the `mealDetailLoggedOn` placeholder metadata) to both files. Run `flutter pub get` and confirm no missing-translation errors.

- [ ] **Step 2: Extract strings in `lib/features/diary/meal_detail_screen.dart`**

Import `../../l10n/generated/app_localizations.dart` and (for date formatting) `package:intl/intl.dart`.

Replace the hand-rolled `_monthNames`/`_formatDate` with `intl`:
```dart
static String _formatDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(date);
}
```
(delete the `_monthNames` list and the old `_formatDate` — this one takes `context` now, update its one call site: `_formatDate(context, entry.eatenAt.toLocal())`.)

String replacements:
- AppBar `'Meal details'` → `mealDetailAppBarTitle`
- `'Logged on ${_formatDate(...)}'` → `AppLocalizations.of(context)!.mealDetailLoggedOn(_formatDate(context, entry.eatenAt.toLocal()))`
- `'Change date'` → `mealDetailChangeDate`
- `'Could not update the date. Please try again.'` → `mealDetailUpdateDateError`
- `'Delete this meal?'` → `mealDetailDeleteConfirmTitle`
- `"This can't be undone."` → `mealDetailDeleteConfirmBody`
- `'Cancel'` → `commonCancel`
- `'Delete'` (dialog action) → `mealDetailDeleteButton`
- `'Could not delete this meal. Please try again.'` → `mealDetailDeleteError`
- `'Totals'` → `mealDetailTotalsTitle`
- Both `_MacroLine(label: 'Calories', ..., unit: 'kcal', ...)` call sites → `label: AppLocalizations.of(context)!.commonCalories, ..., unit: AppLocalizations.of(context)!.commonKcalUnit`
- Both `_MacroLine(label: 'Protein', ..., unit: 'g', ...)` → `commonProtein` / `commonGramUnit`
- Both `_MacroLine(label: 'Carb', ..., unit: 'g', ...)` → `commonCarb` / `commonGramUnit`
- Both `_MacroLine(label: 'Fat', ..., unit: 'g', ...)` → `commonFat` / `commonGramUnit`

(`_FoodItemDetailCard` also has its own 4 `_MacroLine` calls with the same 4 labels/units — same replacements.)

- [ ] **Step 3: Extract strings in `lib/features/diary/today_summary_card.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- `"Today's summary"` → `todaySummaryTitle`
- In `_CaloriesRing`'s no-goal branch: `'Calories'` → `commonCalories`; `'${calories...} kcal'` → interpolate `AppLocalizations.of(context)!.commonKcalUnit` in place of the literal `'kcal'`
- In `_CaloriesRing`'s with-goal branch: `'/ ${goal...} kcal'` and the bottom `'Calories'` label → same `commonKcalUnit` / `commonCalories` substitutions
- The three `_MacroRow(label: 'Protein', ..., unit: 'g')` / `'Carb'` / `'Fat'` call sites in `TodaySummaryCard.build` → `commonProtein`/`commonCarb`/`commonFat` and `commonGramUnit` (same pattern as Step 2)

- [ ] **Step 4: Extract strings in `lib/features/diary/weekly_summary_card.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- `'7-day average'` → `weeklySummaryTitle`
- The four `_WeeklyMacroRow(label: 'Calories'/'Protein'/'Carb'/'Fat', ..., unit: 'kcal'/'g')` call sites → `commonCalories`/`commonProtein`/`commonCarb`/`commonFat` and `commonKcalUnit`/`commonGramUnit` (same pattern as Steps 2-3)

- [ ] **Step 5: Extract strings in `lib/features/diary/weight_card.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- `labelText: 'Weight (kg)'` → `weightCardLabel`
- `'Enter a valid weight.'` → `weightCardInvalidError`
- `'Could not save weight. Try again.'` → `weightCardSaveError`
- `_saving ? 'Saving...' : 'Save'` → `_saving ? AppLocalizations.of(context)!.commonSaving : AppLocalizations.of(context)!.weightCardSaveButton`

- [ ] **Step 6: Extract strings in `lib/features/diary/date_scroller.dart`**

Replace the hand-rolled `_weekdayLabels` constant and its use with `intl`'s locale-aware weekday abbreviation:

```dart
import 'package:intl/intl.dart';
```
Delete `const _weekdayLabels = [...]`. In `_DayTile.build`, replace `_weekdayLabels[day.weekday - 1]` with:
```dart
DateFormat.E(Localizations.localeOf(context).toString()).format(day)
```

No ARB key needed for this file — `intl`'s `DateFormat` handles the Thai weekday abbreviations automatically once the `th` locale's data is available (it is, as soon as `flutter_localizations`/`intl` are dependencies, which Task 1 already added).

- [ ] **Step 7: Extract strings in `lib/features/diary/diary_screen.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- AppBar `'Food Diary'` → `AppLocalizations.of(context)!.appTitle` (reuses the key Task 1 already defined — do not redefine it)
- `'${e.totalCalories.toStringAsFixed(0)} kcal'` (the meal list tile subtitle) → interpolate `AppLocalizations.of(context)!.commonKcalUnit` in place of the literal `'kcal'`
- `_EmptyMealsState`'s two `Text(...)`: `'No meals logged yet'` → `diaryEmptyStateTitle`, `'Tap Add meal to log what you ate'` → `diaryEmptyStateSubtitle`

- [ ] **Step 8: Update tests**

For each of `test/features/diary/diary_screen_test.dart`, `meal_detail_screen_test.dart`, `today_summary_card_test.dart`, `weekly_summary_card_test.dart`, `weight_card_test.dart`, `date_scroller_test.dart`: replace bare `MaterialApp(home: ...)` (or whatever wraps the widget under test, including any route-push helper like `meal_detail_screen_test.dart`'s `_pushScreen`) with `localizedApp(...)` / the same delegates added to that specific `MaterialApp` construction. Keep every existing assertion's expected text unchanged — every English value above is copied verbatim from the current source.

- [ ] **Step 9: Run full verification**

```bash
flutter analyze
flutter test
```

- [ ] **Step 10: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_th.arb lib/features/diary/ test/features/diary/
git commit -m "Localize the Diary feature (EN/TH)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019w7Pizw15HziWNCZBprajr"
```

---

### Task 3: Analyze feature

**Files:**
- Modify: `lib/features/analyze/capture_screen.dart`
- Modify: `lib/features/analyze/analysis_result_screen.dart`
- Modify: `lib/features/analyze/analyze_repository.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_th.arb`
- Modify: `test/features/analyze/capture_screen_test.dart`, `analysis_result_screen_test.dart`, `analyze_repository_test.dart`

**Interfaces:**
- Consumes: `commonCalories`, `commonKcalUnit`, `commonCancel`, `commonSaving` (Task 1). `localizedApp` (Task 1).
- Produces: `capture*`, `analysisResult*` ARB keys (table below); `AnalyzeException.userMessage` changes signature from a getter to a method taking `AppLocalizations l10n` — this is a breaking change to that class's public API, confirm no other file besides `capture_screen.dart` calls `.userMessage` (grep for it) before changing the signature.

#### ARB keys this task owns

| Key | English | Thai |
|---|---|---|
| `captureAppBarTitle` | `Add meal` | `เพิ่มมื้ออาหาร` |
| `captureCameraButton` | `Camera` | `กล้อง` |
| `captureGalleryButton` | `Gallery` | `แกลเลอรี` |
| `captureNoteLabel` | `Note` | `บันทึกเพิ่มเติม` |
| `captureNoteHelper` | `Required if you skip the photo` | `จำเป็นต้องกรอกถ้าไม่ถ่ายรูป` |
| `captureNoteHint` | `e.g. "Thai green curry"` | `เช่น "แกงเขียวหวาน"` |
| `captureNetworkError` | `Network error. Check your connection and try again.` | `เครือข่ายมีปัญหา ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง` |
| `captureAnalyzeButton` | `Analyze` | `วิเคราะห์` |
| `captureAnalyzingButton` | `Analyzing...` | `กำลังวิเคราะห์...` |
| `analysisResultAppBarTitle` | `Review Analysis` | `ตรวจสอบผลวิเคราะห์` |
| `analysisResultSaveError` | `Could not save this meal. Please try again.` | `ไม่สามารถบันทึกมื้ออาหารนี้ได้ กรุณาลองอีกครั้ง` |
| `analysisResultAddItem` | `Add item` | `เพิ่มรายการ` |
| `analysisResultTotal` | `Total: {value} kcal` | `รวม: {value} kcal` |
| `analysisResultSaveButton` | `Save to diary` | `บันทึกลงไดอารี่` |
| `analysisResultLowConfidence` | `Low confidence - please check` | `ความมั่นใจต่ำ - กรุณาตรวจสอบ` |
| `analysisResultNameLabel` | `Name` | `ชื่อ` |
| `analysisResultQuantityLabel` | `Quantity` | `ปริมาณ` |
| `analysisResultCaloriesLabel` | `Calories` | `แคลอรี่` |
| `analysisResultProteinLabel` | `Protein (g)` | `โปรตีน (g)` |
| `analysisResultCarbsLabel` | `Carbs (g)` | `คาร์บ (g)` |
| `analysisResultFatLabel` | `Fat (g)` | `ไขมัน (g)` |
| `analyzeErrorRateLimited` | `High demand right now, try again shortly.` | `มีผู้ใช้งานเยอะตอนนี้ ลองอีกครั้งในอีกสักครู่` |
| `analyzeErrorUnauthorized` | `Please sign in again.` | `กรุณาเข้าสู่ระบบอีกครั้ง` |
| `analyzeErrorUnknown` | `Analysis failed, try again.` | `วิเคราะห์ไม่สำเร็จ ลองอีกครั้ง` |

`analysisResultTotal` needs a placeholder:
```json
"analysisResultTotal": "Total: {value} kcal",
"@analysisResultTotal": {
  "placeholders": { "value": { "type": "String" } }
}
```

Note `analysisResultCaloriesLabel` is a distinct key from `commonCalories` even though both translate to the same word — it's a `TextFormField` label (`'Calories'`) not the `_MacroLine`/`_MacroRow` label pattern `commonCalories` was built for; keep them separate per this table (do not try to reuse `commonCalories` here, simpler to keep this screen self-contained).

- [ ] **Step 1: Add this task's keys to both ARB files, `flutter pub get`, confirm codegen**

- [ ] **Step 2: Change `AnalyzeException.userMessage` in `lib/features/analyze/analyze_repository.dart`**

Import `../../l10n/generated/app_localizations.dart`. Change:
```dart
String get userMessage {
  switch (code) {
    case 'rate_limited':
      return 'High demand right now, try again shortly.';
    case 'unauthorized':
      return 'Please sign in again.';
    default:
      return 'Analysis failed, try again.';
  }
}
```
to:
```dart
String userMessage(AppLocalizations l10n) {
  switch (code) {
    case 'rate_limited':
      return l10n.analyzeErrorRateLimited;
    case 'unauthorized':
      return l10n.analyzeErrorUnauthorized;
    default:
      return l10n.analyzeErrorUnknown;
  }
}
```

- [ ] **Step 3: Extract strings in `lib/features/analyze/capture_screen.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- Update the one call site: `e.userMessage` → `e.userMessage(AppLocalizations.of(context)!)` (inside the `on AnalyzeException catch (e)` block; `context` is available there since `_analyze` is called from a widget's event handler — confirm `mounted`/`context` access matches the existing surrounding code style)
- `'Network error. Check your connection and try again.'` → `captureNetworkError`
- AppBar `'Add meal'` → `captureAppBarTitle`
- `'Camera'` → `captureCameraButton`
- `'Gallery'` → `captureGalleryButton`
- `labelText: 'Note'` → `captureNoteLabel`
- `helperText: 'Required if you skip the photo'` → `captureNoteHelper`
- `hintText: 'e.g. "Thai green curry"'` → `captureNoteHint`
- `_analyzing ? 'Analyzing...' : 'Analyze'` → `_analyzing ? AppLocalizations.of(context)!.captureAnalyzingButton : AppLocalizations.of(context)!.captureAnalyzeButton`

- [ ] **Step 4: Extract strings in `lib/features/analyze/analysis_result_screen.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- `'Could not save this meal. Please try again.'` → `analysisResultSaveError`
- AppBar `'Review Analysis'` → `analysisResultAppBarTitle`
- `'Add item'` → `analysisResultAddItem`
- `'Total: ${_totalCalories.toStringAsFixed(0)} kcal'` → `AppLocalizations.of(context)!.analysisResultTotal(_totalCalories.toStringAsFixed(0))`
- `_saving ? 'Saving...' : 'Save to diary'` → `_saving ? AppLocalizations.of(context)!.commonSaving : AppLocalizations.of(context)!.analysisResultSaveButton`
- `'Low confidence - please check'` → `analysisResultLowConfidence`
- `labelText: 'Name'` → `analysisResultNameLabel`
- `labelText: 'Quantity'` → `analysisResultQuantityLabel`
- `labelText: 'Calories'` → `analysisResultCaloriesLabel`
- `labelText: 'Protein (g)'` → `analysisResultProteinLabel`
- `labelText: 'Carbs (g)'` → `analysisResultCarbsLabel`
- `labelText: 'Fat (g)'` → `analysisResultFatLabel`

- [ ] **Step 5: Update tests**

`test/features/analyze/capture_screen_test.dart`, `analysis_result_screen_test.dart`: wrap with `localizedApp(...)` instead of a bare `MaterialApp`. `analyze_repository_test.dart`: if it tests `AnalyzeException.userMessage` directly, update those call sites to pass an `AppLocalizations` instance (construct one via `await AppLocalizations.delegate.load(const Locale('en'))` in the test, or via a `localizedApp`-wrapped widget test if that's simpler given the existing test's structure — read the file first and match its style). Keep every assertion's expected text unchanged.

- [ ] **Step 6: Run full verification**

```bash
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_th.arb lib/features/analyze/ test/features/analyze/
git commit -m "Localize the Analyze feature (EN/TH)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019w7Pizw15HziWNCZBprajr"
```

---

### Task 4: Profile + Settings

**Files:**
- Modify: `lib/features/profile/profile_screen.dart` (every string EXCEPT the Language row/`currentLocale`/`onLocaleChanged`, already done in Task 1)
- Modify: `lib/features/profile/weight_trend_card.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_th.arb`
- Modify: `test/features/profile/profile_screen_test.dart`, `weight_trend_card_test.dart`, `test/features/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `commonCancel`, `commonSaving`, `commonKcalUnit`, `commonGramUnit` (Task 1). `localizedApp` (Task 1). `ProfileScreen`'s `currentLocale`/`onLocaleChanged` params and the Language row (Task 1) — do not touch that part of the file.
- Produces: `profile*`, `weightTrend*`, `settings*` ARB keys (table below). Nothing later consumes these (last task).

#### ARB keys this task owns

| Key | English | Thai |
|---|---|---|
| `profileAppBarTitle` | `Profile` | `โปรไฟล์` |
| `profileEditTooltip` | `Edit` | `แก้ไข` |
| `profilePersonalInfoTitle` | `Personal info` | `ข้อมูลส่วนตัว` |
| `profileEditPersonalInfoTitle` | `Edit personal info` | `แก้ไขข้อมูลส่วนตัว` |
| `profileNameLabel` | `Name` | `ชื่อ` |
| `profileAgeLabel` | `Age` | `อายุ` |
| `profileWeightLabel` | `Weight (kg)` | `น้ำหนัก (kg)` |
| `profileHeightLabel` | `Height (cm)` | `ส่วนสูง (cm)` |
| `profileBodyFatLabel` | `Body fat (%)` | `เปอร์เซ็นต์ไขมัน (%)` |
| `profileMuscleMassLabel` | `Muscle mass (kg)` | `มวลกล้ามเนื้อ (kg)` |
| `profileDashPlaceholder` | `-` | `-` |
| `profileSaveError` | `Could not save profile. Try again.` | `ไม่สามารถบันทึกโปรไฟล์ได้ ลองอีกครั้ง` |
| `profileCancelButton` | `Cancel` | `ยกเลิก` |
| `profileSaveButton` | `Save profile` | `บันทึกโปรไฟล์` |
| `profileSignOutError` | `Could not sign out. Please try again.` | `ไม่สามารถออกจากระบบได้ กรุณาลองอีกครั้ง` |
| `profileUpdateLatestVersion` | `You're on the latest version.` | `คุณใช้เวอร์ชันล่าสุดอยู่แล้ว` |
| `profileUpdateAvailableStatus` | `Version {version} is available.` | `มีเวอร์ชัน {version} ให้อัปเดต` |
| `profileUpdateDialogTitle` | `Update available` | `มีอัปเดตใหม่` |
| `profileUpdateDialogBody` | `Version {version} is available (you have {current}). Download and install it now?` | `มีเวอร์ชัน {version} ให้อัปเดต (คุณใช้ {current} อยู่) ต้องการดาวน์โหลดและติดตั้งตอนนี้ไหม?` |
| `profileUpdateNotNow` | `Not now` | `ไว้ทีหลัง` |
| `profileUpdateDownloadInstall` | `Download & install` | `ดาวน์โหลดและติดตั้ง` |
| `profileUpdateCheckError` | `Could not check for updates. Try again.` | `ไม่สามารถตรวจสอบอัปเดตได้ ลองอีกครั้ง` |
| `profileGoalsButton` | `Daily goals` | `เป้าหมายรายวัน` |
| `profileSignOutButton` | `Sign out` | `ออกจากระบบ` |
| `profileSigningOutButton` | `Signing out...` | `กำลังออกจากระบบ...` |
| `profileCheckForUpdatesButton` | `Check for updates` | `ตรวจสอบอัปเดต` |
| `profileCheckingButton` | `Checking...` | `กำลังตรวจสอบ...` |
| `profileVersionLabel` | `v{version}` | `v{version}` |
| `weightTrendTitle` | `Weight trend` | `แนวโน้มน้ำหนัก` |
| `weightTrendLastNDays` | `Last {days} days` | `{days} วันล่าสุด` |
| `weightTrendEmptyState` | `Log your weight on a few different days to see your trend here.` | `บันทึกน้ำหนักในหลายๆ วันเพื่อดูแนวโน้มของคุณที่นี่` |
| `weightTrendLatestPrefix` | `Latest: ` | `ล่าสุด: ` |
| `weightTrendOnDate` | ` on {date}` | ` เมื่อ {date}` |
| `weightTrendSemanticsLabel` | `Weight trend chart. Latest reading {latest} kilograms on {date}. Range over the period: {min} to {max} kilograms.` | `กราฟแนวโน้มน้ำหนัก ค่าล่าสุด {latest} กิโลกรัม เมื่อ {date} ช่วงน้ำหนักตลอดช่วงเวลานี้: {min} ถึง {max} กิโลกรัม` |
| `weightTrendKgUnit` | `kg` | `kg` |
| `settingsAppBarTitle` | `Daily goals` | `เป้าหมายรายวัน` |
| `settingsCaloriesLabel` | `Calories (kcal)` | `แคลอรี่ (kcal)` |
| `settingsProteinLabel` | `Protein (g)` | `โปรตีน (g)` |
| `settingsCarbLabel` | `Carb (g)` | `คาร์บ (g)` |
| `settingsFatLabel` | `Fat (g)` | `ไขมัน (g)` |
| `settingsValidationError` | `Enter a number for every field.` | `กรอกตัวเลขให้ครบทุกช่อง` |
| `settingsSaveError` | `Could not save goals. Try again.` | `ไม่สามารถบันทึกเป้าหมายได้ ลองอีกครั้ง` |
| `settingsSaveButton` | `Save goals` | `บันทึกเป้าหมาย` |

Placeholders needed — add `@key` metadata (in `app_en.arb` only) for each:
```json
"profileUpdateAvailableStatus": "Version {version} is available.",
"@profileUpdateAvailableStatus": { "placeholders": { "version": { "type": "String" } } },

"profileUpdateDialogBody": "Version {version} is available (you have {current}). Download and install it now?",
"@profileUpdateDialogBody": { "placeholders": { "version": { "type": "String" }, "current": { "type": "String" } } },

"profileVersionLabel": "v{version}",
"@profileVersionLabel": { "placeholders": { "version": { "type": "String" } } },

"weightTrendLastNDays": "Last {days} days",
"@weightTrendLastNDays": { "placeholders": { "days": { "type": "int" } } },

"weightTrendOnDate": " on {date}",
"@weightTrendOnDate": { "placeholders": { "date": { "type": "String" } } },

"weightTrendSemanticsLabel": "Weight trend chart. Latest reading {latest} kilograms on {date}. Range over the period: {min} to {max} kilograms.",
"@weightTrendSemanticsLabel": {
  "placeholders": {
    "latest": { "type": "String" },
    "date": { "type": "String" },
    "min": { "type": "String" },
    "max": { "type": "String" }
  }
}
```

- [ ] **Step 1: Add this task's keys to both ARB files, `flutter pub get`, confirm codegen**

- [ ] **Step 2: Extract strings in `lib/features/profile/profile_screen.dart`**

Import `../../l10n/generated/app_localizations.dart` (it's likely already imported from Task 1's Step 9 — check first, don't double-import).

- AppBar `'Profile'` → `profileAppBarTitle`
- `tooltip: 'Edit'` → `profileEditTooltip`
- `'Personal info'` → `profilePersonalInfoTitle`
- `_fieldRow('Name', ...)` label → `AppLocalizations.of(context)!.profileNameLabel`
- `_fieldRow('Age', ...)` → `profileAgeLabel`
- `_fieldRow('Weight (kg)', ...)` → `profileWeightLabel`
- `_fieldRow('Height (cm)', ...)` → `profileHeightLabel`
- `_fieldRow('Body fat (%)', ...)` → `profileBodyFatLabel`
- `_fieldRow('Muscle mass (kg)', ...)` → `profileMuscleMassLabel`
- `_formatOrDash`'s `'-'` fallback → `profileDashPlaceholder` (this one needs `BuildContext` threaded into `_formatOrDash`, which is currently a `static` method taking only `double? value` — add a `BuildContext context` parameter to it, update its 4 call sites in `_buildViewMode` accordingly)
- `'Edit personal info'` → `profileEditPersonalInfoTitle`
- Edit-mode `TextField` labels: `'Name'`/`'Age'`/`'Height (cm)'`/`'Body fat (%)'`/`'Muscle mass (kg)'` → same 5 keys as the view-mode row labels above (`profileNameLabel` etc. — reuse, don't create new keys)
- `'Could not save profile. Try again.'` → `profileSaveError`
- `'Cancel'` (edit-mode cancel button) → `profileCancelButton`
- `_savingProfile ? 'Saving...' : 'Save profile'` → `_savingProfile ? AppLocalizations.of(context)!.commonSaving : AppLocalizations.of(context)!.profileSaveButton`
- `'Could not sign out. Please try again.'` → `profileSignOutError`
- `"You're on the latest version."` → `profileUpdateLatestVersion`
- `'Version ${release.version} is available.'` → `AppLocalizations.of(context)!.profileUpdateAvailableStatus(release.version)`
- `'Update available'` (dialog title) → `profileUpdateDialogTitle`
- `'Version ${release.version} is available (you have ${widget.currentVersion}). Download and install it now?'` → `AppLocalizations.of(context)!.profileUpdateDialogBody(release.version, widget.currentVersion)`
- `'Not now'` → `profileUpdateNotNow`
- `'Download & install'` → `profileUpdateDownloadInstall`
- `'Could not check for updates. Try again.'` → `profileUpdateCheckError`
- `'Daily goals'` (button) → `profileGoalsButton`
- `_signingOut ? 'Signing out...' : 'Sign out'` → `_signingOut ? AppLocalizations.of(context)!.profileSigningOutButton : AppLocalizations.of(context)!.profileSignOutButton`
- `_checkingForUpdate ? 'Checking...' : 'Check for updates'` → `_checkingForUpdate ? AppLocalizations.of(context)!.profileCheckingButton : AppLocalizations.of(context)!.profileCheckForUpdatesButton`
- `'v${widget.currentVersion}'` → `AppLocalizations.of(context)!.profileVersionLabel(widget.currentVersion)`

Do not touch the Language row, `currentLocale`, or `onLocaleChanged` — Task 1 already localized those.

- [ ] **Step 3: Extract strings in `lib/features/profile/weight_trend_card.dart`**

Import `../../l10n/generated/app_localizations.dart` and `package:intl/intl.dart`. Replace the hand-rolled `_monthAbbr`/`_shortDate` with `intl`:
```dart
static String _shortDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).format(date);
}
```
(delete `_monthAbbr` and the old `_shortDate` — this one takes `context`; update all of its call sites, which are all inside `_buildChart(BuildContext context)` already, so `context` is in scope at each one.)

String replacements (all inside methods that already receive `context`):
- `'Weight trend'` → `weightTrendTitle`
- `'Last $days days'` → `AppLocalizations.of(context)!.weightTrendLastNDays(days)`
- `'Log your weight on a few different days to see your trend here.'` → `weightTrendEmptyState`
- The `Semantics label:` string (the long one starting `'Weight trend chart. Latest reading ...'`) → build it from `weightTrendSemanticsLabel(latest, date, min, max)`:
  ```dart
  label: AppLocalizations.of(context)!.weightTrendSemanticsLabel(
    _formatWeight(latest.weightKg),
    _shortDate(context, latest.loggedDate),
    _formatWeight(rawMin),
    _formatWeight(rawMax),
  ),
  ```
- The `RichText`'s `TextSpan(text: 'Latest: ')` → `TextSpan(text: AppLocalizations.of(context)!.weightTrendLatestPrefix)`
- `'${_formatWeight(latest.weightKg)} kg'` → interpolate `AppLocalizations.of(context)!.commonKcalUnit`... **no** — this is `kg` not `kcal`. There is no `commonKgUnit` key defined anywhere in this plan. Add one: append to this task's ARB table `weightTrendKgUnit` = `kg` / `kg` (same "units aren't translated" rule as `commonKcalUnit`/`commonGramUnit`), and use it here: `'${_formatWeight(latest.weightKg)} ${AppLocalizations.of(context)!.weightTrendKgUnit}'`.
- `TextSpan(text: ' on ${_shortDate(latest.loggedDate)}')` → `TextSpan(text: AppLocalizations.of(context)!.weightTrendOnDate(_shortDate(context, latest.loggedDate)))`
- Bottom-axis `getTitlesWidget`'s `_shortDate(date)` → `_shortDate(context, date)` (context is available in that closure — it's inside `_buildChart(BuildContext context)`)
- Tooltip's `'${_formatWeight(spot.y)} kg\n'` → `'${_formatWeight(spot.y)} ${AppLocalizations.of(context)!.weightTrendKgUnit}\n'`
- Tooltip's `TextSpan(text: _shortDate(date))` → `TextSpan(text: _shortDate(context, date))`

- [ ] **Step 4: Extract strings in `lib/features/settings/settings_screen.dart`**

Import `../../l10n/generated/app_localizations.dart`.

- AppBar `'Daily goals'` → `settingsAppBarTitle`
- `labelText: 'Calories (kcal)'` → `settingsCaloriesLabel`
- `labelText: 'Protein (g)'` → `settingsProteinLabel`
- `labelText: 'Carb (g)'` → `settingsCarbLabel`
- `labelText: 'Fat (g)'` → `settingsFatLabel`
- `'Enter a number for every field.'` → `settingsValidationError`
- `'Could not save goals. Try again.'` → `settingsSaveError`
- `_saving ? 'Saving...' : 'Save goals'` → `_saving ? AppLocalizations.of(context)!.commonSaving : AppLocalizations.of(context)!.settingsSaveButton`

- [ ] **Step 5: Update tests**

`test/features/profile/profile_screen_test.dart`, `weight_trend_card_test.dart`, `test/features/settings/settings_screen_test.dart`: wrap with `localizedApp(...)`. Keep every assertion's expected text unchanged. For `weight_trend_card_test.dart`'s `Semantics` label assertion (if one exists — check the file), the composed string's *shape* is unchanged (same words, same order) so the expected value stays the same.

- [ ] **Step 6: Run full verification**

```bash
flutter analyze
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_th.arb lib/features/profile/ lib/features/settings/settings_screen.dart test/features/profile/ test/features/settings/
git commit -m "Localize the Profile and Settings screens (EN/TH)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019w7Pizw15HziWNCZBprajr"
```

---

## After all 4 tasks

Follow this project's established release pipeline (same as every prior feature this session): bump `pubspec.yaml` version (minor bump — this is a real feature), build the release APK with `--dart-define=SUPABASE_URL=...` / `--dart-define=SUPABASE_ANON_KEY=...`, `gh release create`. Manually verify on the emulator/device: switch to ไทย via the new Profile → Language row, confirm the whole app re-renders in Thai with no missing-translation crashes, confirm switching back to English works, confirm "System default" follows the device locale.
