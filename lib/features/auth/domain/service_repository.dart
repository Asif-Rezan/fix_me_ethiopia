import 'account.dart';
import '../../booking/domain/booking.dart';

abstract interface class ServiceRepository {
  Stream<Account?> get accounts;
  Future<void> signIn(String email, String password);
  Future<void> register(
    String name,
    String email,
    String password,
    AccountRole role,
  );
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<Map<String, dynamic>> call(String endpoint, Map<String, dynamic> data);
  Future<VerificationResult> verify(String bookingId, String credential);
}
