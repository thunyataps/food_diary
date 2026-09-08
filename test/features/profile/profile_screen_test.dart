import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/profile/profile_screen.dart';
import 'package:food_diary/features/update/update_checker.dart';
import 'package:food_diary/models/user_profile.dart';

void main() {
  testWidgets(
      'shows fields once initialProfile arrives after the first build (async fetch via FutureBuilder)',
      (tester) async {
    Widget build(UserProfile? profile) => MaterialApp(
          home: ProfileScreen(
            email: 'alex@example.com',
            latestWeightKg: null,
            initialProfile: profile,
            onSaveProfile: (p) async {},
            onOpenGoals: () {},
            onSignOut: () async {},
            currentVersion: '1.0.0',
            onCheckForUpdate: (v) async => null,
            onDownloadAndInstall: (url) async {},
          ),
        );

    // First build: the caller's fetch hasn't resolved yet (FutureBuilder's
    // "waiting" state), so initialProfile is null — matches production.
    await tester.pumpWidget(build(null));
    expect(find.text('Alex'), findsNothing);

    // The fetch resolves: caller rebuilds the same ProfileScreen with the
    // real profile now available.
    await tester.pumpWidget(build(
      UserProfile(name: 'Alex', age: 30, heightCm: 170, bodyFatPct: 20, muscleMassKg: 55),
    ));
    await tester.pump();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('prefills fields from initialProfile and saves edited values', (tester) async {
    UserProfile? saved;
    final profile = UserProfile(
      name: 'Alex',
      age: 30,
      heightCm: 170,
      bodyFatPct: 20,
      muscleMassKg: 55,
    );

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: 68.5,
        initialProfile: profile,
        onSaveProfile: (p) async => saved = p,
        onOpenGoals: () {},
        onSignOut: () async {},
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async => null,
        onDownloadAndInstall: (url) async {},
      ),
    ));

    expect(find.text('alex@example.com'), findsOneWidget);
    expect(find.text('68.5 kg'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name_field')), 'Alexis');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Alexis');
    expect(saved!.age, 30);
  });

  testWidgets('all profile fields are optional and can be left blank', (tester) async {
    UserProfile? saved;
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: null,
        initialProfile: null,
        onSaveProfile: (p) async => saved = p,
        onOpenGoals: () {},
        onSignOut: () async {},
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async => null,
        onDownloadAndInstall: (url) async {},
      ),
    ));

    expect(find.text('No weight logged yet'), findsOneWidget);

    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, isNull);
    expect(saved!.age, isNull);
  });

  testWidgets('tapping Daily goals invokes onOpenGoals', (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: null,
        initialProfile: null,
        onSaveProfile: (p) async {},
        onOpenGoals: () => opened++,
        onSignOut: () async {},
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async => null,
        onDownloadAndInstall: (url) async {},
      ),
    ));

    await tester.ensureVisible(find.text('Daily goals'));
    await tester.tap(find.text('Daily goals'));
    expect(opened, 1);
  });

  testWidgets('tapping Sign out invokes onSignOut', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: null,
        initialProfile: null,
        onSaveProfile: (p) async {},
        onOpenGoals: () {},
        onSignOut: () async => signOutCalls++,
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async => null,
        onDownloadAndInstall: (url) async {},
      ),
    ));

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
  });

  testWidgets('shows "up to date" when no update is available', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: null,
        initialProfile: null,
        onSaveProfile: (p) async {},
        onOpenGoals: () {},
        onSignOut: () async {},
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async => null,
        onDownloadAndInstall: (url) async {},
      ),
    ));

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("You're on the latest version."), findsOneWidget);
  });

  testWidgets('prompts to install and downloads on confirm when an update is available',
      (tester) async {
    String? downloadedUrl;
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: null,
        initialProfile: null,
        onSaveProfile: (p) async {},
        onOpenGoals: () {},
        onSignOut: () async {},
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async =>
            ReleaseInfo(version: '2.0.0', apkDownloadUrl: 'https://example.com/app.apk'),
        onDownloadAndInstall: (url) async => downloadedUrl = url,
      ),
    ));

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Version 2.0.0 is available.'), findsOneWidget);

    await tester.tap(find.text('Download & install'));
    await tester.pumpAndSettle();

    expect(downloadedUrl, 'https://example.com/app.apk');
  });

  testWidgets('shows an error message when checking for updates fails', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        email: 'alex@example.com',
        latestWeightKg: null,
        initialProfile: null,
        onSaveProfile: (p) async {},
        onOpenGoals: () {},
        onSignOut: () async {},
        currentVersion: '1.0.0',
        onCheckForUpdate: (v) async => throw Exception('network error'),
        onDownloadAndInstall: (url) async {},
      ),
    ));

    await tester.ensureVisible(find.text('Check for updates'));
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Could not check for updates. Try again.'), findsOneWidget);
  });
}
