import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';

/// Spark-compatible commands. Every transaction is independently validated by
/// deployed Firestore rules: callers cannot grant roles, skip work or set prices.
class FirestoreCommands {
  FirestoreCommands(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String get uid =>
      auth.currentUser?.uid ?? (throw StateError('Sign in first.'));
  FieldValue get now => FieldValue.serverTimestamp();
  String text(dynamic value, {int max = 2000}) {
    if (value is! String || value.trim().isEmpty || value.length > max) {
      throw ArgumentError('Enter valid text.');
    }
    return value.trim();
  }

  String hash(String value) => sha256.convert(utf8.encode(value)).toString();
  DocumentReference<Map<String, dynamic>> booking(Map<String, dynamic> data) =>
      db.collection('bookings').doc(text(data['bookingId'], max: 100));
  void move(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    String status, {
    Map<String, dynamic> extra = const {},
  }) {
    final event = ref.collection('booking_events').doc();
    tx.update(ref, {
      'status': status,
      'updatedAt': now,
      'lastEventId': event.id,
      ...extra,
    });
    tx.set(event, {'status': status, 'actorId': uid, 'createdAt': now});
  }

  Future<Map<String, dynamic>> execute(
    String command,
    Map<String, dynamic> data,
  ) async {
    switch (command) {
      case 'createBooking':
        final category = await db
            .collection('service_categories')
            .doc(text(data['categoryId'], max: 100))
            .get();
        if (category.data()?['active'] != true) {
          throw StateError('This service is unavailable.');
        }
        final date = DateTime.parse(text(data['scheduledAt']));
        if (!date.isAfter(DateTime.now())) {
          throw ArgumentError('Choose a future time.');
        }
        final ref = db.collection('bookings').doc(),
            eventId = db.collection('bookings').doc().id;
        final batch = db.batch();
        batch.set(ref, {
          'customerId': uid,
          'technicianId':
              data['technicianId'] is String &&
                  (data['technicianId'] as String).isNotEmpty
              ? data['technicianId']
              : null,
          'categoryId': category.id,
          'issue': text(data['issue']),
          'scheduledAt': Timestamp.fromDate(date),
          'status':
              data['technicianId'] is String &&
                  (data['technicianId'] as String).isNotEmpty
              ? 'assigned'
              : 'requested',
          'visitFee': category.data()!['visitFee'],
          'createdAt': now,
          'updatedAt': now,
          'lastEventId': eventId,
        });
        batch.set(ref.collection('private').doc('address'), {
          'customerId': uid,
          'address': text(data['address'], max: 500),
        });
        batch.set(ref.collection('booking_events').doc(eventId), {
          'status':
              data['technicianId'] is String &&
                  (data['technicianId'] as String).isNotEmpty
              ? 'assigned'
              : 'requested',
          'actorId': uid,
          'createdAt': now,
        });
        await batch.commit();
        return {'bookingId': ref.id};
      case 'acceptBooking':
      case 'rejectBooking':
      case 'transitionBooking':
        final ref = booking(data);
        await db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) throw StateError('Booking not found.');
          move(
            tx,
            ref,
            command == 'acceptBooking'
                ? 'accepted'
                : command == 'rejectBooking'
                ? 'searching'
                : text(data['status']),
            extra: command == 'rejectBooking' ? {'technicianId': null} : {},
          );
        });
        return {'ok': true};
      case 'verifyTechnician':
        final ref = booking(data),
            credentialHash = hash(text(data['credential'], max: 256));
        return db.runTransaction((tx) async {
          final b = (await tx.get(ref)).data();
          if (b == null || b['customerId'] != uid || b['status'] != 'arrived') {
            throw StateError(
              'Only the assigned customer can verify an arrived technician.',
            );
          }
          // Missing/invalid credentials cannot be read. A denied read is a mismatch,
          // never grounds for a local verified transition.
          final credential = await tx.get(
            db.collection('technician_credentials').doc(credentialHash),
          );
          final c = credential.data();
          if (c == null ||
              c['active'] != true ||
              c['technicianId'] != b['technicianId']) {
            return {'matched': false};
          }
          final tech = (await tx.get(
            db.collection('technicians').doc(c['technicianId'] as String),
          )).data();
          if (tech?['approval'] != 'approved') return {'matched': false};
          final verification = db.collection('qr_verifications').doc();
          move(
            tx,
            ref,
            'identity_verified',
            extra: {
              'verifiedAt': now,
              'verifiedCredentialId': credentialHash,
              'verificationId': verification.id,
            },
          );
          tx.set(verification, {
            'bookingId': ref.id,
            'customerId': uid,
            'technicianId': b['technicianId'],
            'credentialId': credentialHash,
            'matched': true,
            'createdAt': now,
          });
          return {
            'matched': true,
            'credentialId': credentialHash,
            'name': tech!['name'],
            'photoUrl': tech['photoId'],
          };
        });
      case 'createQuote':
        final ref = booking(data), quote = db.collection('quotes').doc();
        await db.runTransaction((tx) async {
          final b = (await tx.get(ref)).data();
          if (b == null) throw StateError('Booking not found.');
          final labor = data['labor'], parts = data['parts'];
          if (labor is! int || parts is! int || labor < 0 || parts < 0) {
            throw ArgumentError('Enter valid labor and parts costs.');
          }
          tx.set(quote, {
            'bookingId': ref.id,
            'customerId': b['customerId'],
            'technicianId': uid,
            'visit': b['visitFee'],
            'labor': labor,
            'parts': parts,
            'total': (b['visitFee'] as int) + labor + parts,
            'description': text(data['description']),
            'status': 'pending',
            'createdAt': now,
          });
          move(tx, ref, 'quote_pending', extra: {'quoteId': quote.id});
        });
        return {'quoteId': quote.id};
      case 'approveQuote':
      case 'rejectQuote':
        final ref = booking(data);
        await db.runTransaction((tx) async {
          final b = (await tx.get(ref)).data();
          if (b == null) throw StateError('Booking missing.');
          final qRef = db.collection('quotes').doc(b['quoteId'] as String);
          final q = (await tx.get(qRef)).data();
          if (q == null) throw StateError('Quote missing.');
          final approve = command == 'approveQuote';
          tx.update(qRef, {
            'status': approve ? 'approved' : 'rejected',
            'respondedAt': now,
          });
          move(
            tx,
            ref,
            'in_progress',
            extra: approve
                ? {'quoteApprovedAt': now, 'approvedTotal': q['total']}
                : {
                    'quoteApprovedAt': FieldValue.delete(),
                    'approvedTotal': FieldValue.delete(),
                  },
          );
        });
        return {'ok': true};
      case 'recordCashPayment':
      case 'confirmCashReceived':
        final ref = booking(data),
            pay = db.collection('payments').doc(text(data['bookingId']));
        await db.runTransaction((tx) async {
          final b = (await tx.get(ref)).data();
          if (b == null) throw StateError('Booking missing.');
          if (command == 'recordCashPayment') {
            tx.set(pay, {
              'bookingId': ref.id,
              'customerId': uid,
              'technicianId': b['technicianId'],
              'amount': b['approvedTotal'],
              'method': 'cash',
              'status': 'customer_reported',
              'createdAt': now,
            });
            move(tx, ref, 'payment_pending');
          } else {
            await tx.get(pay);
            tx.update(pay, {'status': 'settled', 'settledAt': now});
            move(tx, ref, 'completed', extra: {'completedAt': now});
          }
        });
        return {'ok': true};
      case 'submitTechnicianApplication':
        final skills = List<String>.from(data['skills'] as List? ?? []),
            documents = List<String>.from(data['documents'] as List? ?? []);
        if (skills.isEmpty || documents.length < 2) {
          throw ArgumentError(
            'Select skills and upload at least two identity documents.',
          );
        }
        final batch = db.batch();
        batch.update(db.collection('users').doc(uid), {
          'approval': 'pending',
          'updatedAt': now,
        });
        batch.update(db.collection('technicians').doc(uid), {
          'approval': 'pending',
          'skills': skills,
          'online': false,
        });
        batch.set(db.collection('technician_private').doc(uid), {
          'profile': data['profile'] ?? {},
          'documents': documents,
          'submittedAt': now,
          'photoId': data['photoId'],
        }, SetOptions(merge: true));
        await batch.commit();
        return {'ok': true};
      case 'setAvailability':
        await db.collection('technicians').doc(uid).update({
          'online': data['online'] == true,
        });
        return {'ok': true};
      case 'sendMessage':
        final ref = booking(data), b = (await ref.get()).data();
        if (b == null || b['technicianId'] == null) {
          throw StateError('Chat opens once a technician is assigned.');
        }
        final conversation = db.collection('conversations').doc(ref.id),
            batch = db.batch();
        batch.set(conversation, {
          'participants': [b['customerId'], b['technicianId']],
          'updatedAt': now,
        }, SetOptions(merge: true));
        batch.set(conversation.collection('messages').doc(), {
          'senderId': uid,
          'text': text(data['text']),
          'createdAt': now,
        });
        await batch.commit();
        return {'ok': true};
      case 'createComplaint':
        final ref = await db.collection('complaints').add({
          'userId': uid,
          'bookingId': data['bookingId'] ?? '',
          'description': text(data['description']),
          'status': 'open',
          'createdAt': now,
        });
        return {'ticketId': ref.id};
      case 'registerPushToken':
        final token = text(data['token'], max: 4096);
        await db
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(hash(token))
            .set({'token': token, 'updatedAt': now});
        return {'ok': true};
      case 'updateWork':
        final task = text(data['task'], max: 40);
        if (!['inspection', 'diagnosis', 'repair', 'test'].contains(task) ||
            data['done'] is! bool) {
          throw ArgumentError('Invalid checklist item.');
        }
        await booking(data).update({'checklist.$task': data['done']});
        return {'ok': true};
      case 'attachBookingPhotos':
        final paths = List<String>.from(data['paths'] as List? ?? []);
        await booking(
          data,
        ).update({'issuePhotos': FieldValue.arrayUnion(paths)});
        return {'ok': true};
      case 'submitReview':
        final ref = booking(data), b = (await ref.get()).data();
        if (b == null) throw StateError('Booking missing.');
        await db.collection('reviews').doc(ref.id).set({
          'bookingId': ref.id,
          'customerId': uid,
          'technicianId': b['technicianId'],
          'rating': data['rating'],
          'text': text(data['text']),
          'createdAt': now,
        });
        return {'ok': true};
      case 'saveAddress':
        final addressId =
            data['id'] as String? ?? db.collection('customers').doc().id;
        await db
            .collection('customers')
            .doc(uid)
            .collection('addresses')
            .doc(addressId)
            .set({
              'label': text(data['label'], max: 60),
              'address': text(data['address'], max: 500),
              'updatedAt': now,
            });
        return {'id': addressId};
      case 'toggleFavorite':
        final ref = db
            .collection('customers')
            .doc(uid)
            .collection('favorites')
            .doc(text(data['technicianId'], max: 100));
        if (data['favorite'] == true) {
          await ref.set({'createdAt': now});
        } else {
          await ref.delete();
        }
        return {'ok': true};
      case 'requestPayout':
        // Cash is paid directly to the technician; it creates no platform-held balance.
        throw StateError(
          'Cash earnings are paid directly to you. Online payouts will be available after the payment gateway is implemented.',
        );
      default:
        throw UnsupportedError('Unsupported operation: $command');
    }
  }
}
