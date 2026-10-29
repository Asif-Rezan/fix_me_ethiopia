import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_me_ethiopia/core/domain.dart';
import 'package:fix_me_ethiopia/core/state.dart';
import 'package:fix_me_ethiopia/features/auth/domain/auth_gateway.dart';
import 'package:fix_me_ethiopia/features/auth/presentation/auth_view.dart';

class TestAuth implements ServiceRepository, AuthGateway {
  String? provider, email;
  bool fail = false;
  @override
  Stream<Account?> get accounts => const Stream.empty();
  @override
  Future<void> signInWithGoogle(String role) async {
    provider = 'google';
    if (fail) throw StateError('Cancelled');
  }

  @override
  Future<void> signInWithApple(String role) async {
    provider = 'apple';
  }

  @override
  Future<void> signIn(String email, String password) async {
    this.email = email;
  }

  @override
  Future<void> register(
    String name,
    String email,
    String password,
    AccountRole role,
  ) async {
    this.email = email;
  }

  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> data,
  ) async => {};
  @override
  Future<VerificationResult> verify(
    String bookingId,
    String credential,
  ) async => VerificationResult(matched: false, bookingId: bookingId);
}

Future<void> pump(WidgetTester tester, TestAuth auth) async {
  final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (_, s) => const AuthView()),
      GoRoute(
        path: '/screen/6',
        builder: (_, s) => const Scaffold(body: Text('Authenticated profile')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(auth)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('authentication offers Google and email with no phone or OTP', (
    tester,
  ) async {
    await pump(tester, TestAuth());
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Phone number'), findsNothing);
    expect(find.text('Sign in with phone'), findsNothing);
    expect(find.textContaining('OTP'), findsNothing);
  });
  testWidgets('Google sign-in invokes the auth gateway and navigates', (
    tester,
  ) async {
    final auth = TestAuth();
    await pump(tester, auth);
    await tester.ensureVisible(find.byKey(const ValueKey('google-sign-in')));
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pumpAndSettle();
    expect(auth.provider, 'google');
    expect(find.text('Authenticated profile'), findsOneWidget);
  });
  testWidgets('email sign-in only validates email and password', (
    tester,
  ) async {
    final auth = TestAuth();
    await pump(tester, auth);
    await tester.ensureVisible(find.text('Already have an account? Sign in'));
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'existing-password',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(auth.email, 'user@example.com');
    expect(find.text('Authenticated profile'), findsOneWidget);
  });
  testWidgets('Google failure stays on auth and permits retry', (tester) async {
    final auth = TestAuth()..fail = true;
    await pump(tester, auth);
    await tester.ensureVisible(find.byKey(const ValueKey('google-sign-in')));
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign-in was cancelled'), findsOneWidget);
    expect(find.text('Authenticated profile'), findsNothing);
  });
}
