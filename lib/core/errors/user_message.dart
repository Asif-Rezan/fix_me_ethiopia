import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Only display known, deliberately written messages. Never render SDK error
/// strings: they can contain database paths, tokens, configuration and PII.
String userMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
        'Please check your internet connection and try again.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' =>
        'The email or password doesn’t match. Please try again.',
      'invalid-email' => 'Please enter a valid email address.',
      'email-already-in-use' =>
        'An account already uses this email. Please sign in instead.',
      'weak-password' =>
        'Please choose a stronger password with at least 8 characters.',
      'too-many-requests' || 'resource-exhausted' || 'quota-exceeded' =>
        'This service is busy right now. Please wait a little and try again.',
      'user-disabled' =>
        'Your account is currently unavailable. Please contact support.',
      'permission-denied' =>
        'This action isn’t available for your account. Refresh and try again, or contact support.',
      'unauthenticated' ||
      'requires-recent-login' ||
      'user-token-expired' => 'Please sign in again to continue.',
      'not-found' => 'We couldn’t find this item. Refresh and try again.',
      'failed-precondition' ||
      'aborted' => 'This request has changed. Refresh it and try again.',
      'popup-closed-by-user' || 'cancelled' || 'canceled' =>
        'Sign-in was cancelled. You can try again when you’re ready.',
      'popup-blocked' =>
        'Please allow the sign-in window in your browser, then try again.',
      'operation-not-allowed' ||
      'configuration-not-found' ||
      'invalid-api-key' ||
      'app-not-authorized' =>
        'Sign-in is unavailable right now. Please try another sign-in option or contact support.',
      _ =>
        'We couldn’t complete this action. Please try again. If it continues, contact support.',
    };
  }
  if (error is GoogleSignInException) {
    return error.code.name == 'canceled'
        ? 'Sign-in was cancelled. You can try again when you’re ready.'
        : 'Google sign-in is unavailable right now. Please try email sign-in or try again later.';
  }
  final message = error is ArgumentError
      ? error.message
      : error is StateError
      ? error.message
      : null;
  if (message is String) {
    if (message.toLowerCase() == 'cancelled' ||
        message.toLowerCase() == 'canceled') {
      return 'Sign-in was cancelled. You can try again when you’re ready.';
    }
    // Domain validation copy is safe only when explicitly phrased for a user.
    final forbidden = RegExp(
      r'firebase|firestore|database|exception|https?://|unsupported|stack|\btoken\b|\bconfiguration\b|[{}]',
      caseSensitive: false,
    );
    final validation = RegExp(
      r'^(Please |Enter |Choose |Select |Upload |Attach |Use at least |Your |This image |Cash earnings |Sign in |Only the assigned customer |Booking not found|Chat opens |A maximum of )',
    );
    if (message.length <= 220 &&
        !forbidden.hasMatch(message) &&
        validation.hasMatch(message)) {
      return message;
    }
  }
  return 'Something went wrong. Please try again. If it continues, contact support.';
}

String readableStatus(String value) => switch (value) {
  'requested' => 'Request received',
  'searching' => 'Finding a technician',
  'assigned' => 'Technician assigned',
  'accepted' => 'Booking accepted',
  'on_the_way' => 'Technician on the way',
  'arrived' => 'Technician arrived',
  'identity_verified' => 'Technician verified',
  'in_progress' => 'Work in progress',
  'quote_pending' => 'Waiting for quotation approval',
  'work_completed' => 'Work completed',
  'customer_confirmed' => 'Work confirmed',
  'payment_pending' => 'Payment confirmation pending',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  'disputed' => 'Support review requested',
  'approved' => 'Approved',
  'pending' => 'Under review',
  'incomplete' => 'Profile incomplete',
  'rejected' => 'Needs changes',
  'suspended' => 'Account unavailable',
  _ => 'Processing',
};
