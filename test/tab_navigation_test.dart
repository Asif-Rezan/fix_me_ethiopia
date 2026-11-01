import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:fix_me_ethiopia/features/screens/reference_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fix_me_ethiopia/core/domain.dart';
import 'package:fix_me_ethiopia/core/state.dart';
import 'package:fix_me_ethiopia/main.dart';
import 'package:fix_me_ethiopia/data/repositories.dart';
import 'package:fix_me_ethiopia/features/booking/presentation/records_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<dynamic> designs;
  setUpAll(() async {
    designs =
        jsonDecode(await rootBundle.loadString('assets/data/screens.json'))
            as List<dynamic>;
  });
  testWidgets(
    'bottom tabs retain their screen state and do not add back-stack entries',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DemoRepository()..enter(AccountRole.customer);
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          designsProvider.overrideWith((ref) async => designs),
          recordsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(demoModeProvider.notifier).set(true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FixMeApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/screen/7');
      await tester.pumpAndSettle();
      final home = tester.state(find.byKey(const ValueKey(7)));
      final scroll = find.descendant(
        of: find.byKey(const ValueKey(7)),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      );
      final before = tester
          .state<ScrollableState>(scrollable.first)
          .position
          .pixels;
      for (final label in ['Bookings', 'Explore', 'Profile', 'Home']) {
        await tester.tap(
          find
              .descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).canPop(), false);
      }
      expect(tester.state(find.byKey(const ValueKey(7))), same(home));
      expect(
        tester.state<ScrollableState>(scrollable.first).position.pixels,
        before,
      );
      expect(find.textContaining('DEMO • sample data'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
