import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain.dart';
import '../../../core/state.dart';
import 'verification_view_model.dart';

/// Booking commands have no dependency on widgets, BuildContext or navigation.
class BookingViewModel extends AsyncNotifier<String?> {
  @override
  String? build() => null;
  ServiceRepository get repository => ref.read(repositoryProvider);
  Future<String> create(Map<String, dynamic> request) async {
    state = const AsyncLoading();
    try {
      final result = await repository.call('createBooking', request);
      final id = result['bookingId'] as String;
      ref.read(flowProvider.notifier).booking(id);
      state = AsyncData(id);
      return id;
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow;
    }
  }

  Future<void> transition(BookingStatus next) async {
    await repository.call('transitionBooking', {
      'bookingId': ref.read(flowProvider).bookingId,
      'status': next.wire,
    });
  }

  Future<VerificationResult> verify(String code) async {
    final id = ref.read(flowProvider).bookingId;
    if (production && id.isEmpty) {
      throw StateError('Select an active booking first.');
    }
    final result = await repository.verify(id, code);
    ref.read(flowProvider.notifier).verify(result.matched);
    ref.read(verificationViewModelProvider.notifier).received(result);
    return result;
  }

  Future<void> quote(int labor, int parts, String description) async {
    QuotePrice(visit: 300, labor: labor, parts: parts).total;
    await repository.call('createQuote', {
      'bookingId': ref.read(flowProvider).bookingId,
      'labor': labor,
      'parts': parts,
      'description': description,
    });
  }

  Future<void> approveQuote() => repository
      .call('approveQuote', {'bookingId': ref.read(flowProvider).bookingId})
      .then((_) {});
  Future<void> recordCash() => repository
      .call('recordCashPayment', {
        'bookingId': ref.read(flowProvider).bookingId,
      })
      .then((_) {});
  Future<void> accept() => repository
      .call('acceptBooking', {'bookingId': ref.read(flowProvider).bookingId})
      .then((_) {});
  Future<void> reject() => repository
      .call('rejectBooking', {'bookingId': ref.read(flowProvider).bookingId})
      .then((_) {});
  Future<void> confirmCash() => repository
      .call('confirmCashReceived', {
        'bookingId': ref.read(flowProvider).bookingId,
      })
      .then((_) {});
}

final bookingViewModelProvider =
    AsyncNotifierProvider<BookingViewModel, String?>(BookingViewModel.new);
