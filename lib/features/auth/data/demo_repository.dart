import 'dart:async';
import '../../../core/domain.dart';

class DemoRepository implements ServiceRepository {
  final _accounts = StreamController<Account?>.broadcast();
  Account? current;
  BookingStatus status = BookingStatus.requested;
  final List<Map<String, dynamic>> bookings = [];
  @override
  Stream<Account?> get accounts async* {
    yield current;
    yield* _accounts.stream;
  }

  void enter(AccountRole role) {
    current = Account(
      'demo',
      role,
      Approval.approved,
      role == AccountRole.customer ? 'Abebe Kebede' : 'Tesfaye Alemu',
    );
    _accounts.add(current);
  }

  @override
  Future<void> signIn(String email, String password) async {
    enter(AccountRole.customer);
  }

  @override
  Future<void> register(
    String name,
    String email,
    String password,
    AccountRole role,
  ) async {
    current = Account(
      'demo',
      role,
      role == AccountRole.technician ? Approval.incomplete : Approval.approved,
      name,
    );
    _accounts.add(current);
  }

  @override
  Future<void> signOut() async {
    current = null;
    _accounts.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (endpoint == 'createBooking') {
      status = BookingStatus.requested;
      final id = 'DEMO-${bookings.length + 1025}';
      bookings.add({...data, 'id': id});
      return {'bookingId': id};
    }
    if (endpoint == 'transitionBooking') {
      final next = BookingStatus.values.firstWhere(
        (s) => s.wire == data['status'],
      );
      if (!status.canTransitionTo(next)) {
        throw StateError(
          'This booking cannot move from ${status.wire} to ${next.wire}',
        );
      }
      status = next;
    }
    if (endpoint == 'submitTechnicianApplication') {
      current = Account(
        'demo',
        AccountRole.technician,
        Approval.pending,
        current?.name ?? 'Technician',
      );
      _accounts.add(current);
    }
    return {'demo': true, 'ok': true};
  }

  @override
  Future<VerificationResult> verify(
    String bookingId,
    String credential,
  ) async => VerificationResult(
    matched: credential == 'DEMO-FIXME-00002',
    bookingId: bookingId,
    technicianName: 'Tesfaye Alemu',
    credentialId: credential,
  );
}
