import 'package:flutter/foundation.dart';

enum BookingStatus {
  requested,
  searching,
  assigned,
  accepted,
  onTheWay,
  arrived,
  identityVerified,
  inProgress,
  quotePending,
  workCompleted,
  customerConfirmed,
  paymentPending,
  completed,
  cancelled,
  disputed;

  String get wire =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
  bool canTransitionTo(BookingStatus next) =>
      transitions[this]?.contains(next) ?? false;
  static const transitions = <BookingStatus, Set<BookingStatus>>{
    requested: {searching, cancelled},
    searching: {assigned, cancelled},
    assigned: {accepted, searching, cancelled},
    accepted: {onTheWay, cancelled},
    onTheWay: {arrived, disputed},
    arrived: {identityVerified, disputed},
    identityVerified: {inProgress, disputed},
    inProgress: {quotePending, workCompleted, disputed},
    quotePending: {inProgress, workCompleted, disputed},
    workCompleted: {customerConfirmed, disputed},
    customerConfirmed: {paymentPending},
    paymentPending: {completed, disputed},
  };
}

@immutable
class VerificationResult {
  const VerificationResult({
    required this.matched,
    required this.bookingId,
    this.technicianName,
    this.photoUrl,
    this.credentialId,
  });
  final bool matched;
  final String bookingId;
  final String? technicianName, photoUrl, credentialId;
}

@immutable
class QuotePrice {
  const QuotePrice({
    required this.visit,
    required this.labor,
    required this.parts,
  });
  final int visit, labor, parts;
  int get total {
    if (visit < 0 || labor < 0 || parts < 0) {
      throw ArgumentError('Prices cannot be negative');
    }
    return visit + labor + parts;
  }
}
