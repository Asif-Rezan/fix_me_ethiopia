import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fix_me_ethiopia/core/errors/user_message.dart';

void main() {
  test('SDK errors never expose database names or raw messages', () {
    for (final code in [
      'permission-denied',
      'unavailable',
      'not-found',
      'invalid-credential',
      'quota-exceeded',
      'unknown',
    ]) {
      final result = userMessage(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: code,
          message:
              'Firebase internal database users/secret private stack trace',
        ),
      );
      expect(result.toLowerCase(), isNot(contains('firebase')));
      expect(result.toLowerCase(), isNot(contains('firestore')));
      expect(result, isNot(contains('users/secret')));
      expect(result, isNot(contains(code)));
    }
  });
  test('unknown errors show a safe fallback', () {
    expect(
      userMessage(StateError('Firebase database internal failure')),
      'Something went wrong. Please try again. If it continues, contact support.',
    );
  });
  test('deliberate validation messages stay useful', () {
    expect(
      userMessage(ArgumentError('Please enter your full address.')),
      'Please enter your full address.',
    );
    expect(
      userMessage(StateError('Cancelled')),
      contains('Sign-in was cancelled'),
    );
  });
  test('booking statuses use customer-readable language', () {
    expect(readableStatus('identity_verified'), 'Technician verified');
    expect(readableStatus('on_the_way'), 'Technician on the way');
  });
}
