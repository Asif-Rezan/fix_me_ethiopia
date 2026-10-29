import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/domain.dart';
import '../domain/auth_gateway.dart';

class FirebaseRepository implements ServiceRepository, AuthGateway {
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get db => FirebaseFirestore.instance;
  @override
  Stream<Account?> get accounts => auth.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream.value(null);
    }
    return db.collection('users').doc(user.uid).snapshots().map((doc) {
      final d = doc.data();
      if (d == null) {
        return Account(
          user.uid,
          AccountRole.customer,
          Approval.incomplete,
          user.displayName ?? '',
        );
      }
      return Account(
        user.uid,
        AccountRole.values.byName(d['role'] as String),
        Approval.values.byName(d['approval'] as String? ?? 'incomplete'),
        d['name'] as String? ?? '',
      );
    });
  });
  @override
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> register(
    String name,
    String email,
    String password,
    AccountRole role,
  ) async {
    await auth.createUserWithEmailAndPassword(email: email, password: password);
    await call('createProfile', {'name': name, 'role': role.name});
  }

  @override
  Future<void> signOut() => auth.signOut();
  @override
  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email);
  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(endpoint)
        .call<Map<String, dynamic>>(data);
    return result.data;
  }

  @override
  Future<VerificationResult> verify(String bookingId, String credential) async {
    final d = await call('verifyTechnician', {
      'bookingId': bookingId,
      'credential': credential,
    });
    return VerificationResult(
      matched: d['matched'] == true,
      bookingId: bookingId,
      technicianName: d['name'] as String?,
      photoUrl: d['photoUrl'] as String?,
      credentialId: d['credentialId'] as String?,
    );
  }

  Future<void> _ensureSocialProfile(String role) async {
    final user = auth.currentUser!;
    final doc = await db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await call('createProfile', {
        'name': user.displayName ?? user.phoneNumber ?? 'New member',
        'role': role,
      });
    }
  }

  String? _verificationId;
  @override
  Future<void> signInWithGoogle(String role) async {
    await auth.signInWithProvider(GoogleAuthProvider());
    await _ensureSocialProfile(role);
  }

  @override
  Future<void> signInWithApple(String role) async {
    await auth.signInWithProvider(AppleAuthProvider());
    await _ensureSocialProfile(role);
  }

  @override
  Future<void> sendPhoneCode(String phone) async {
    final complete = Completer<void>();
    await auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        await auth.signInWithCredential(credential);
        if (!complete.isCompleted) complete.complete();
      },
      verificationFailed: (error) {
        if (!complete.isCompleted) complete.completeError(error);
      },
      codeSent: (id, token) {
        _verificationId = id;
        if (!complete.isCompleted) complete.complete();
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
    await complete.future;
  }

  @override
  Future<void> confirmPhoneCode(String code, String role) async {
    final id = _verificationId;
    if (id == null) throw StateError('Request a new phone code.');
    await auth.signInWithCredential(
      PhoneAuthProvider.credential(verificationId: id, smsCode: code),
    );
    await _ensureSocialProfile(role);
  }
}
