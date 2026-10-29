import 'package:flutter/foundation.dart';

@immutable
class AppRecord {
  const AppRecord(this.id, this.values);
  final String id;
  final Map<String, dynamic> values;
  String text(String key, [String fallback = '']) =>
      values[key]?.toString() ?? fallback;
}

abstract interface class RecordsRepository {
  Stream<List<AppRecord>> watch({
    required String collection,
    String? ownerField,
    String? ownerId,
    String? documentId,
  });
}
