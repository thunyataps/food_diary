import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/profile/profile_screen.dart';
import 'package:food_diary/models/user_profile.dart';

void main() {
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
      ),
    ));

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
  });
}
