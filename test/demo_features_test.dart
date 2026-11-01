import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fix_me_ethiopia/core/domain.dart';
import 'package:fix_me_ethiopia/features/support/presentation/support_center_view.dart';
import 'package:fix_me_ethiopia/core/state.dart';
import 'package:fix_me_ethiopia/data/repositories.dart';
import 'package:fix_me_ethiopia/features/booking/presentation/section_workspace_view.dart';
import 'package:fix_me_ethiopia/features/booking/presentation/live_records_view.dart';
import 'package:fix_me_ethiopia/features/booking/presentation/records_view_model.dart';

void main() {
  test(
    'seed has both roles, catalog, bookings, quotations and earnings',
    () async {
      final repo = DemoRepository();
      expect(
        (await repo.watch(collection: 'service_categories').first).length,
        12,
      );
      expect((await repo.watch(collection: 'technicians').first).length, 6);
      expect((await repo.watch(collection: 'bookings').first).length, 6);
      expect(
        (await repo.watch(collection: 'quotes').first).single.text('status'),
        'pending',
      );
      repo.enter(AccountRole.customer);
      final id =
          (await repo.call('createBooking', {
                'categoryId': 'plumbing',
                'issue': 'Leaking tap',
                'address': 'Bole, Addis Ababa',
              }))['bookingId']
              as String;
      await repo.call('sendMessage', {
        'bookingId': id,
        'text': 'Please ring the bell',
      });
      expect(
        (await repo.watch(collection: 'conversations/$id/messages').first)
            .single
            .text('text'),
        'Please ring the bell',
      );
      await repo.call('saveAddress', {
        'label': 'Parents',
        'address': 'Arada, Addis Ababa',
      });
      expect(
        (await repo
                .watch(collection: 'customers/demo-customer/addresses')
                .first)
            .length,
        3,
      );
      await repo.call('markAllNotificationsRead', {});
      expect(
        (await repo
                .watch(
                  collection: 'notifications',
                  ownerField: 'userId',
                  ownerId: 'demo-customer',
                )
                .first)
            .every((r) => r.values['readAt'] != null),
        true,
      );
      repo.enter(AccountRole.technician);
      await repo.call('acceptBooking', {'bookingId': id});
      await repo.call('transitionBooking', {
        'bookingId': id,
        'status': 'on_the_way',
      });
      await repo.call('transitionBooking', {
        'bookingId': id,
        'status': 'arrived',
      });
      await repo.verify(id, 'DEMO-FIXME-00002');
      await repo.call('transitionBooking', {
        'bookingId': id,
        'status': 'in_progress',
      });
      await repo.call('createQuote', {
        'bookingId': id,
        'labor': 600,
        'parts': 450,
        'description': 'Replace seal',
      });
      repo.enter(AccountRole.customer);
      await repo.call('approveQuote', {'bookingId': id});
      repo.enter(AccountRole.technician);
      await repo.call('transitionBooking', {
        'bookingId': id,
        'status': 'work_completed',
      });
      repo.enter(AccountRole.customer);
      await repo.call('transitionBooking', {
        'bookingId': id,
        'status': 'customer_confirmed',
      });
      await repo.call('recordCashPayment', {'bookingId': id});
      repo.enter(AccountRole.technician);
      await repo.call('confirmCashReceived', {'bookingId': id});
      expect(
        (await repo.watch(collection: 'payments', documentId: id).first).single
            .text('amount'),
        '1350',
      );
    },
  );
  for (final role in AccountRole.values) {
    final screens = role == AccountRole.customer
        ? [7, 10, 11, 16, 17, 20, 21, 22, 23, 24, 25, 42, 44]
        : [24, 30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44];
    for (final id in screens) {
      testWidgets('populated $role section $id at phone width', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = DemoRepository()..enter(role);
        final container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            accountProvider.overrideWith((ref) => Stream.value(repo.current)),
            recordsRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);
        container.read(demoModeProvider.notifier).set(true);
        container
            .read(flowProvider.notifier)
            .booking(
              id == 22
                  ? 'FX-1028'
                  : id == 20
                  ? 'FX-1027'
                  : 'FX-1025',
            );
        container
            .read(flowProvider.notifier)
            .field('technicianId', 'demo-technician');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: id == 45
                      ? const SupportCenterView()
                      : workspaceScreens.contains(id)
                      ? SectionWorkspaceView(screenId: id)
                      : LiveRecordsView(screenId: id),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Nothing here yet'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
