import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/domain.dart';
import '../../booking/data/firestore_commands.dart';
import '../../../firebase_options.dart';
import '../domain/auth_gateway.dart';

class FirebaseRepository implements ServiceRepository, AuthGateway {
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get db => FirebaseFirestore.instance;
  Future<void>? _googleInitialization;

  @override
  Stream<Account?> get accounts {
    // Switch profile listeners when auth changes. asyncExpand would wait forever
    // on the previous Firestore listener and silently miss sign-out/sign-in.
    late StreamController<Account?> controller;
    StreamSubscription<User?>? authentication;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profile;
    var generation = 0;
    controller = StreamController<Account?>(
      onListen: () {
        authentication = auth.authStateChanges().listen(
          (user) async {
            final revision = ++generation;
            await profile?.cancel();
            if (revision != generation || controller.isClosed) return;
            if (user == null) {
              controller.add(null);
              return;
            }
            profile = db
                .collection('users')
                .doc(user.uid)
                .snapshots()
                .listen(
                  (doc) {
                    if (revision != generation || controller.isClosed) return;
                    try {
                      final data = doc.data();
                      if (data == null) {
                        controller.add(
                          Account(
                            user.uid,
                            AccountRole.customer,
                            Approval.incomplete,
                            user.displayName ?? '',
                          ),
                        );
                        return;
                      }
                      final role = AccountRole.values.byName(
                        data['role'] as String,
                      );
                      final approval = Approval.values.byName(
                        data['approval'] as String? ?? 'incomplete',
                      );
                      controller.add(
                        Account(
                          user.uid,
                          role,
                          role == AccountRole.customer &&
                                  approval == Approval.approved &&
                                  data['profileComplete'] != true
                              ? Approval.incomplete
                              : approval,
                          data['name'] as String? ?? user.displayName ?? '',
                        ),
                      );
                    } catch (error, stack) {
                      controller.addError(error, stack);
                    }
                  },
                  onError: (Object error, StackTrace stack) {
                    if (!controller.isClosed) controller.addError(error, stack);
                  },
                );
          },
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed) controller.addError(error, stack);
          },
        );
      },
      onCancel: () async {
        generation++;
        await authentication?.cancel();
        await profile?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _ensureProfile({
    required String name,
    required AccountRole role,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Sign in before creating a profile.');
    await db.runTransaction((transaction) async {
      final ref = db.collection('users').doc(user.uid);
      final doc = await transaction.get(ref);
      if (doc.exists) return; // Existing roles are never overwritten on login.
      final approval = role == AccountRole.customer ? 'approved' : 'incomplete';
      final displayName = name.trim().isEmpty
          ? user.displayName ?? 'New member'
          : name.trim();
      transaction.set(ref, {
        'name': displayName,
        'role': role.name,
        'approval': approval,
        'profileComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        db
            .collection(
              role == AccountRole.customer ? 'customers' : 'technicians',
            )
            .doc(user.uid),
        {
          'name': displayName,
          'approval': approval,
          'online': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  @override
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> register(
    String name,
    String email,
    String password,
    AccountRole role,
  ) async {
    await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await auth.currentUser!.updateDisplayName(name.trim());
    await _ensureProfile(name: name, role: role);
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    if (!kIsWeb && _googleInitialization != null) {
      await GoogleSignIn.instance.signOut();
    }
  }

  @override
  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    if (endpoint == 'completeProfile') {
      final user = auth.currentUser;
      if (user == null) throw StateError('Sign in first.');
      final input = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
      final profile = <String, String>{};
      for (final key in ['Full name', 'Email', 'City', 'Address']) {
        final value = input[key];
        if (value is String && value.trim().isNotEmpty) {
          profile[key] = value.trim();
        }
      }
      await db.collection('users').doc(user.uid).update({
        'name': profile['Full name'] ?? user.displayName ?? 'New member',
        'profile': profile,
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return {'ok': true};
    }
    return FirestoreCommands(db, auth).execute(endpoint, data);
  }

  @override
  Future<VerificationResult> verify(String bookingId, String credential) async {
    try {
      final data = await call('verifyTechnician', {
        'bookingId': bookingId,
        'credential': credential,
      });
      return VerificationResult(
        matched: data['matched'] == true,
        bookingId: bookingId,
        technicianName: data['name'] as String?,
        photoUrl: data['photoUrl'] as String?,
        credentialId: data['credentialId'] as String?,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return VerificationResult(matched: false, bookingId: bookingId);
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWithGoogle(String role) async {
    if (kIsWeb) {
      await auth.signInWithPopup(
        GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      );
    } else {
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? DefaultFirebaseOptions.googleIosClientId
            : null,
        serverClientId: DefaultFirebaseOptions.googleServerClientId,
      );
      await _googleInitialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google did not return an identity token.');
      }
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }
    await _ensureProfile(
      name: auth.currentUser?.displayName ?? '',
      role: AccountRole.values.byName(role),
    );
  }

  @override
  Future<void> signInWithApple(String role) async {
    await auth.signInWithProvider(AppleAuthProvider());
    await _ensureProfile(
      name: auth.currentUser?.displayName ?? '',
      role: AccountRole.values.byName(role),
    );
  }
}
