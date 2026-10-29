import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fix_me_ethiopia/main.dart';
import 'package:fix_me_ethiopia/features/screens/reference_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<dynamic> designs;
  setUpAll(() async {
    designs =
        jsonDecode(await rootBundle.loadString('assets/data/screens.json'))
            as List<dynamic>;
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final id in [3, 7, 15, 30, 36]) {
    testWidgets('visual screen $id', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [designsProvider.overrideWith((ref) async => designs)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(
            key: ValueKey('capture'),
            child: FixMeApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/screen/$id');
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/screen_$id.png'),
      );
    });
  }
}
