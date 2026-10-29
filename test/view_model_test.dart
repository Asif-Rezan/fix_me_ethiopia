import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fix_me_ethiopia/core/state.dart';
import 'package:fix_me_ethiopia/core/domain.dart';
import 'package:fix_me_ethiopia/data/repositories.dart';
import 'package:fix_me_ethiopia/features/auth/domain/role_policy.dart';
import 'package:fix_me_ethiopia/features/booking/presentation/booking_view_model.dart';
import 'package:fix_me_ethiopia/features/booking/presentation/verification_view_model.dart';

void main() {
  test('guard prevents unapproved technician and cross-role routes', () {
    const pending = Account('t', AccountRole.technician, Approval.pending, 'T');
    expect(roleRedirect(screen: 31, account: pending), '/screen/29');
    expect(roleRedirect(screen: 7, account: pending), '/screen/29');
    expect(roleRedirect(screen: 36, account: null), '/screen/3');
    expect(
      roleRedirect(
        screen: 30,
        account: const Account(
          'c',
          AccountRole.customer,
          Approval.approved,
          'C',
        ),
      ),
      '/screen/7',
    );
    expect(
      roleRedirect(
        screen: 30,
        account: const Account(
          't',
          AccountRole.technician,
          Approval.approved,
          'T',
        ),
      ),
      null,
    );
  });
  test(
    'booking view model stores repository booking and verification results',
    () async {
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
      );
      addTearDown(container.dispose);
      final vm = container.read(bookingViewModelProvider.notifier);
      final id = await vm.create({'categoryId': 'refrigerator'});
      expect(container.read(flowProvider).bookingId, id);
      final matched = await vm.verify('DEMO-FIXME-00002');
      expect(matched.matched, true);
      expect(
        container.read(verificationViewModelProvider)?.technicianName,
        'Tesfaye Alemu',
      );
      await vm.verify('mismatch');
      expect(container.read(flowProvider).verified, false);
    },
  );
}
