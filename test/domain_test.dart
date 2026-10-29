import 'package:flutter_test/flutter_test.dart';
import 'package:fix_me_ethiopia/core/domain.dart';
import 'package:fix_me_ethiopia/data/repositories.dart';

void main() {
  test('authorized roles route to correct home', () {
    expect(
      const Account('c', AccountRole.customer, Approval.approved, 'A').home,
      7,
    );
    expect(
      const Account('t', AccountRole.technician, Approval.pending, 'T').home,
      29,
    );
    expect(
      const Account('t', AccountRole.technician, Approval.approved, 'T').home,
      30,
    );
  });
  test('work cannot start before verification', () {
    expect(
      BookingStatus.arrived.canTransitionTo(BookingStatus.inProgress),
      false,
    );
    expect(
      BookingStatus.identityVerified.canTransitionTo(BookingStatus.inProgress),
      true,
    );
    expect(
      BookingStatus.completed.canTransitionTo(BookingStatus.requested),
      false,
    );
  });
  test('integer ETB prices reject negative amounts', () {
    expect(const QuotePrice(visit: 300, labor: 600, parts: 450).total, 1350);
    expect(
      () => const QuotePrice(visit: 300, labor: -1, parts: 0).total,
      throwsArgumentError,
    );
  });
  test('mock credential match and mismatch remain explicit', () async {
    final repo = DemoRepository();
    expect((await repo.verify('demo', 'bad')).matched, false);
    expect((await repo.verify('demo', 'DEMO-FIXME-00002')).matched, true);
  });
  test('mock repository rejects skipping status', () async {
    final repo = DemoRepository();
    expect(
      () => repo.call('transitionBooking', {'status': 'completed'}),
      throwsStateError,
    );
  });
}
