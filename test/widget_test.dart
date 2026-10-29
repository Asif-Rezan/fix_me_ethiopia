import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fix_me_ethiopia/main.dart';
import 'package:fix_me_ethiopia/features/screens/reference_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<dynamic> screens;
  setUpAll(() async {
    screens =
        jsonDecode(await rootBundle.loadString('assets/data/screens.json'))
            as List<dynamic>;
  });
  testWidgets('splash opens onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [designsProvider.overrideWith((ref) async => screens)],
        child: const FixMeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your Trusted'), findsOneWidget);
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Home repairs, made simple'), findsOneWidget);
  });
  for (var id = 1; id <= 45; id++) {
    testWidgets('screen $id renders at mobile width without exceptions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [designsProvider.overrideWith((ref) async => screens)],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: ReferenceScreen(id: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
