import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/profile/profile_screen.dart';
import 'package:food_diary/features/update/update_checker.dart';
import 'package:food_diary/models/user_profile.dart';
import 'package:food_diary/models/weight_log.dart';

import '../../test_utils.dart';

void main() {
  Widget buildScreen({
    String email = 'alex@example.com',
    double? latestWeightKg,
    List<WeightLog> recentWeights = const [],
    UserProfile? initialProfile,
    Future<void> Function(UserProfile)? onSaveProfile,
    VoidCallback? onOpenGoals,
    Future<void> Function()? onSignOut,
    String currentVersion = '1.0.0',
    Future<ReleaseInfo?> Function(String)? onCheckForUpdate,
    Future<void> Function(String)? onDownloadAndInstall,
  }) {
    return localizedApp(
      ProfileScreen(
        email: email,
        latestWeightKg: latestWeightKg,
        recentWeights: recentWeights,
        initialProfile: initialProfile,
        onSaveProfile: onSaveProfile ?? (p) async {},
        onOpenGoals: onOpenGoals ?? () {},
        onSignOut: onSignOut ?? () async {},
        currentVersion: currentVersion,
        onCheckForUpdate: onCheckForUpdate ?? (v) async => null,
        onDownloadAndInstall: onDownloadAndInstall ?? (url) async {},
        currentLocale: null,
        onLocaleChanged: (_) {},
      ),
    );
  }

  testWidgets(
    'view mode shows profile fields as read-only, with "-" for unset ones',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(
          initialProfile: UserProfile(
            name: 'Alex',
            age: 30,
            heightCm: 170,
            bodyFatPct: null,
            muscleMassKg: null,
          ),
        ),
      );

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('170'), findsOneWidget);
      // Three unset fields (weight, body fat, muscle mass) all render as "-".
      expect(find.text('-'), findsNWidgets(3));

      // No editable fields or Save/Cancel buttons in view mode.
      expect(find.byKey(const Key('name_field')), findsNothing);
      expect(find.text('Save profile'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    },
  );

  testWidgets(
    'view mode shows all dashes when there is no profile or weight yet',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(initialProfile: null, latestWeightKg: null),
      );

      // Name, Age, Weight, Height, Body fat, Muscle mass.
      expect(find.text('-'), findsNWidgets(6));
    },
  );

  testWidgets(
    'view mode shows the latest logged weight alongside personal info',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(
          initialProfile: UserProfile(
            name: 'Alex',
            age: 30,
            heightCm: 170,
            bodyFatPct: 20,
            muscleMassKg: 55,
          ),
          latestWeightKg: 68.5,
        ),
      );

      expect(find.text('68.5'), findsOneWidget);
    },
  );

  testWidgets(
    'shows fields once initialProfile arrives after the first build (async fetch via FutureBuilder)',
    (tester) async {
      Widget build(UserProfile? profile) =>
          buildScreen(initialProfile: profile);

      // First build: the caller's fetch hasn't resolved yet (FutureBuilder's
      // "waiting" state), so initialProfile is null — matches production.
      await tester.pumpWidget(build(null));
      expect(find.text('Alex'), findsNothing);

      // The fetch resolves: caller rebuilds the same ProfileScreen with the
      // real profile now available.
      await tester.pumpWidget(
        build(
          UserProfile(
            name: 'Alex',
            age: 30,
            heightCm: 170,
            bodyFatPct: 20,
            muscleMassKg: 55,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    },
  );

  testWidgets('tapping Edit opens the form prefilled with the current values', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        initialProfile: UserProfile(
          name: 'Alex',
          age: 30,
          heightCm: 170,
          bodyFatPct: 20,
          muscleMassKg: 55,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('edit_profile_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('name_field')), findsOneWidget);
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('name_field')),
    );
    expect(nameField.controller!.text, 'Alex');
    final ageField = tester.widget<TextField>(
      find.byKey(const Key('age_field')),
    );
    expect(ageField.controller!.text, '30');
  });

  testWidgets(
    'Cancel discards edits and returns to view mode with the original values',
    (tester) async {
      UserProfile? saved;
      await tester.pumpWidget(
        buildScreen(
          initialProfile: UserProfile(
            name: 'Alex',
            age: 30,
            heightCm: 170,
            bodyFatPct: 20,
            muscleMassKg: 55,
          ),
          onSaveProfile: (p) async => saved = p,
        ),
      );

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('name_field')),
        'Someone Else',
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(saved, isNull);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Someone Else'), findsNothing);
      expect(find.byKey(const Key('name_field')), findsNothing);
    },
  );

  testWidgets(
    'Save profile persists edits and returns to view mode showing the new values',
    (tester) async {
      UserProfile? saved;
      await tester.pumpWidget(
        buildScreen(
          initialProfile: UserProfile(
            name: 'Alex',
            age: 30,
            heightCm: 170,
            bodyFatPct: 20,
            muscleMassKg: 55,
          ),
          onSaveProfile: (p) async => saved = p,
        ),
      );

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('name_field')), 'Alexis');
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.name, 'Alexis');
      expect(saved!.age, 30);

      // Back in view mode, showing the just-saved value.
      expect(find.byKey(const Key('name_field')), findsNothing);
      expect(find.text('Alexis'), findsOneWidget);
    },
  );

  testWidgets('all profile fields are optional and can be left blank', (
    tester,
  ) async {
    UserProfile? saved;
    await tester.pumpWidget(buildScreen(onSaveProfile: (p) async => saved = p));

    await tester.tap(find.byKey(const Key('edit_profile_button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, isNull);
    expect(saved!.age, isNull);
  });

  testWidgets(
    'a failed save shows an error and stays in edit mode for a retry',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(
          initialProfile: UserProfile(
            name: 'Alex',
            age: 30,
            heightCm: 170,
            bodyFatPct: 20,
            muscleMassKg: 55,
          ),
          onSaveProfile: (p) async => throw Exception('offline'),
        ),
      );

      await tester.tap(find.byKey(const Key('edit_profile_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save profile. Try again.'), findsOneWidget);
      expect(find.byKey(const Key('name_field')), findsOneWidget);
    },
  );

  testWidgets('tapping Daily goals invokes onOpenGoals', (tester) async {
    var opened = 0;
    await tester.pumpWidget(buildScreen(onOpenGoals: () => opened++));

    await tester.ensureVisible(find.text('Daily goals'));
    await tester.tap(find.text('Daily goals'));
    expect(opened, 1);
  });

  testWidgets('tapping Sign out invokes onSignOut', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(buildScreen(onSignOut: () async => signOutCalls++));

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
  });

  testWidgets('shows "up to date" when no update is available', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("You're on the latest version."), findsOneWidget);
  });

  testWidgets(
    'prompts to install and downloads on confirm when an update is available',
    (tester) async {
      String? downloadedUrl;
      await tester.pumpWidget(
        buildScreen(
          onCheckForUpdate: (v) async => ReleaseInfo(
            version: '2.0.0',
            apkDownloadUrl: 'https://example.com/app.apk',
          ),
          onDownloadAndInstall: (url) async => downloadedUrl = url,
        ),
      );

      await tester.ensureVisible(find.text('Check for updates'));
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('Version 2.0.0 is available.'), findsOneWidget);

      await tester.tap(find.text('Download & install'));
      await tester.pumpAndSettle();

      expect(downloadedUrl, 'https://example.com/app.apk');
    },
  );

  testWidgets('shows an error message when checking for updates fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        onCheckForUpdate: (v) async => throw Exception('network error'),
      ),
    );

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not check for updates. Try again.'),
      findsOneWidget,
    );
  });
}
