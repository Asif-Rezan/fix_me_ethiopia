import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/booking.dart';

class VerificationViewModel extends Notifier<VerificationResult?> {
  @override
  VerificationResult? build() => null;
  void received(VerificationResult value) => state = value;
  void clear() => state = null;
}

final verificationViewModelProvider =
    NotifierProvider<VerificationViewModel, VerificationResult?>(
      VerificationViewModel.new,
    );
