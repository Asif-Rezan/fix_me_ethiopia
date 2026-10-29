import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/records.dart';

class FirestoreRecordsRepository implements RecordsRepository {
  @override
  Stream<List<AppRecord>> watch({
    required String collection,
    String? ownerField,
    String? ownerId,
    String? documentId,
  }) {
    final source = FirebaseFirestore.instance.collection(collection);
    if (documentId != null) {
      return source
          .doc(documentId)
          .snapshots()
          .map(
            (d) =>
                d.exists ? [AppRecord(d.id, Map.unmodifiable(d.data()!))] : [],
          );
    }
    Query<Map<String, dynamic>> query = source;
    if (ownerField != null) query = query.where(ownerField, isEqualTo: ownerId);
    return query
        .limit(50)
        .snapshots()
        .map(
          (q) => q.docs
              .map((d) => AppRecord(d.id, Map.unmodifiable(d.data())))
              .toList(),
        );
  }
}
