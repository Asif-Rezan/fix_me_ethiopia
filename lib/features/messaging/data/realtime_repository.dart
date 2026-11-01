import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/records.dart';
import '../../booking/data/firestore_records_repository.dart';

/// Booking membership is mirrored by the trusted project-owner sync worker.
/// Clients cannot grant themselves access to a conversation.
class RealtimeRepository implements RecordsRepository {
  static const databaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: 'https://fixme-ethiopia-default-rtdb.firebaseio.com',
  );
  static FirebaseDatabase get database => FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: databaseUrl,
  );
  String get uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Sign in first.'));
  @override
  Stream<List<AppRecord>> watch({
    required String collection,
    String? ownerField,
    String? ownerId,
    String? documentId,
  }) {
    String? path;
    if (collection == 'notifications') {
      if (ownerId == null) return Stream.value([]);
      path = 'notifications/$ownerId';
    } else if (collection.startsWith('conversations/')) {
      path = collection.replaceFirst('conversations/', 'rooms/');
    }
    if (path == null) {
      return FirestoreRecordsRepository().watch(
        collection: collection,
        ownerField: ownerField,
        ownerId: ownerId,
        documentId: documentId,
      );
    }
    Query query = database.ref(documentId == null ? path : '$path/$documentId');
    if (documentId == null &&
        (collection == 'notifications' || collection.endsWith('/messages'))) {
      query = query.orderByChild('createdAt').limitToLast(100);
    }
    return query.onValue.map((event) {
      final snapshots = documentId == null
          ? event.snapshot.children
          : [event.snapshot];
      final rows = snapshots.where((s) => s.exists).map((s) {
        final raw = s.value;
        final values = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{'value': raw};
        for (final key in ['createdAt', 'readAt', 'updatedAt']) {
          if (values[key] is num) {
            values[key] = DateTime.fromMillisecondsSinceEpoch(
              (values[key] as num).toInt(),
              isUtc: true,
            ).add(const Duration(hours: 3));
          }
        }
        return AppRecord(s.key!, values);
      }).toList();
      return collection == 'notifications' ? rows.reversed.toList() : rows;
    });
  }

  Future<Map<String, dynamic>> command(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final userId = uid;
    final booking = data['bookingId'] as String? ?? '';
    final room = database.ref('rooms/$booking');
    switch (endpoint) {
      case 'sendMessage':
        final text = (data['text'] as String? ?? '').trim();
        if (booking.isEmpty || text.isEmpty || text.length > 2000) {
          throw ArgumentError(
            'Choose a booking and enter a message of up to 2000 characters.',
          );
        }
        final members = await room.child('members').get();
        final participants = Map<String, dynamic>.from(
          members.value as Map? ?? {},
        );
        if (participants[userId] != true) {
          throw StateError(
            'This conversation is not ready. Please try again shortly.',
          );
        }
        final message = room.child('messages').push();
        await message.set({
          'senderId': userId,
          'text': text,
          'createdAt': ServerValue.timestamp,
        });
        // A notification failure never retries/duplicates an already-saved message.
        // The trusted sync worker also reconciles missing chat notifications.
        for (final recipient in participants.keys.where((id) => id != userId)) {
          try {
            await database
                .ref('notifications/$recipient/chat-${message.key}')
                .set({
                  'name': 'New message',
                  'text': text,
                  'type': 'chat',
                  'bookingId': booking,
                  'messageId': message.key,
                  'senderId': userId,
                  'createdAt': ServerValue.timestamp,
                });
          } catch (_) {
            /* Reconciled by the trusted worker. */
          }
        }
        try {
          await room.child('typing/$userId').remove();
        } catch (_) {}
      case 'markConversationRead':
        if (booking.isNotEmpty) {
          await room.child('reads/$userId').set(ServerValue.timestamp);
        }
        if (booking.isNotEmpty) {
          final alerts = await database
              .ref('notifications/$userId')
              .orderByChild('bookingId')
              .equalTo(booking)
              .limitToLast(100)
              .get();
          final updates = <String, Object?>{};
          for (final alert in alerts.children) {
            if (alert.child('type').value == 'chat' &&
                !alert.child('readAt').exists) {
              updates['${alert.key}/readAt'] = ServerValue.timestamp;
            }
          }
          if (updates.isNotEmpty) {
            await database.ref('notifications/$userId').update(updates);
          }
        }
      case 'setTyping':
        if (booking.isNotEmpty) {
          if (data['typing'] == true) {
            await room.child('typing/$userId').onDisconnect().remove();
            await room.child('typing/$userId').set(ServerValue.timestamp);
          } else {
            await room.child('typing/$userId').remove();
          }
        }
      case 'setChatPresence':
        if (booking.isNotEmpty) {
          final presence = room.child('presence/$userId');
          if (data['online'] == true) {
            await presence.onDisconnect().remove();
            await presence.set(true);
          } else {
            await presence.remove();
            await room.child('typing/$userId').remove();
          }
        }
      case 'markNotificationRead':
        final notification = data['notificationId'] as String?;
        if (notification == null || notification.isEmpty) {
          throw ArgumentError('Choose a notification.');
        }
        await database
            .ref('notifications/$userId/$notification/readAt')
            .set(ServerValue.timestamp);
      case 'markAllNotificationsRead':
        final snapshot = await database
            .ref('notifications/$userId')
            .orderByChild('createdAt')
            .limitToLast(100)
            .get();
        final updates = <String, Object?>{};
        for (final row in snapshot.children) {
          if (!row.child('readAt').exists) {
            updates['${row.key}/readAt'] = ServerValue.timestamp;
          }
        }
        if (updates.isNotEmpty) {
          await database.ref('notifications/$userId').update(updates);
        }
      default:
        throw UnsupportedError('Unknown realtime action.');
    }
    return {'ok': true};
  }
}
