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
