import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/records.dart';
import '../../../core/state.dart';
import '../data/firestore_records_repository.dart';

final recordsRepositoryProvider = Provider<RecordsRepository>(
  (ref) => FirestoreRecordsRepository(),
);
typedef RecordQuery = ({
  String collection,
  String? ownerField,
  String? ownerId,
  String? documentId,
});
final recordsViewModelProvider = StreamProvider.autoDispose
    .family<List<AppRecord>, RecordQuery>(
      (ref, query) => ref
          .watch(recordsRepositoryProvider)
          .watch(
            collection: query.collection,
            ownerField: query.ownerField,
            ownerId: query.ownerId,
            documentId: query.documentId,
          ),
    );
RecordQuery queryForScreen(
  int id,
  String uid,
  String bookingId,
  bool technician,
) {
  if ([
    7,
    16,
    17,
    20,
    21,
    22,
    23,
    30,
    31,
    32,
    33,
    34,
    35,
    37,
    39,
  ].contains(id)) {
    return (
      collection: 'bookings',
      ownerField: technician ? 'technicianId' : 'customerId',
      ownerId: uid,
      documentId: [16, 17, 20, 21, 22, 33, 34, 35, 37, 39].contains(id)
          ? (bookingId.isEmpty ? '__none__' : bookingId)
          : null,
    );
  }
  if ([10, 11, 42].contains(id)) {
    return (
      collection: 'technicians',
      ownerField: 'approval',
      ownerId: 'approved',
      documentId: null,
    );
  }
  if (id == 24) {
    return (
      collection: 'notifications',
      ownerField: 'userId',
      ownerId: uid,
      documentId: null,
    );
  }
  if (id == 40) {
    return (
      collection: 'payments',
      ownerField: 'technicianId',
      ownerId: uid,
      documentId: null,
    );
  }
  if ([36, 41].contains(id)) {
    return (
      collection: 'technician_private',
      ownerField: null,
      ownerId: null,
      documentId: uid,
    );
  }
  if (id == 44) {
    return (
      collection: 'conversations/$bookingId/messages',
      ownerField: null,
      ownerId: null,
      documentId: null,
    );
  }
  return (
    collection: 'users',
    ownerField: null,
    ownerId: null,
    documentId: uid,
  );
}

final productionDataScreens = {
  7,
  10,
  11,
  16,
  17,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  39,
  40,
  41,
  42,
  43,
  44,
};
// This provider is intentionally independent of widget state and Firebase widgets.
final currentRecordsProvider = StreamProvider.autoDispose
    .family<List<AppRecord>, int>((ref, id) {
      final account = ref.watch(accountProvider).asData?.value;
      if (account == null) return Stream.value([]);
      final query = id == 11
          ? (
              collection: 'technicians',
              ownerField: null,
              ownerId: null,
              documentId:
                  ref.watch(flowProvider).fields['technicianId'] ?? '__none__',
            )
          : queryForScreen(
              id,
              account.uid,
              ref.watch(flowProvider).bookingId,
              account.role.name == 'technician',
            );
      return ref
          .watch(recordsRepositoryProvider)
          .watch(
            collection: query.collection,
            ownerField: query.ownerField,
            ownerId: query.ownerId,
            documentId: query.documentId,
          );
    });
