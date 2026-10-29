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
          .map((d) => d.exists ? [AppRecord(d.id, _values(d.data()!))] : []);
    }
    Query<Map<String, dynamic>> query = source;
    if (ownerField != null) query = query.where(ownerField, isEqualTo: ownerId);
    if (collection.endsWith('/messages')) query = query.orderBy('createdAt');
    return query
        .limit(50)
        .snapshots()
        .map(
          (q) => q.docs.map((d) => AppRecord(d.id, _values(d.data()))).toList(),
        );
  }

  Map<String, dynamic> _values(Map<String, dynamic> data) => Map.unmodifiable(
    data.map(
      (key, value) => MapEntry(
        key,
        value is Timestamp
            ? value.toDate().toUtc().add(const Duration(hours: 3))
            : value,
      ),
    ),
  );
}
