import 'package:flutter/foundation.dart';

@immutable
class AppRecord {
  const AppRecord(this.id, this.values);
  final String id;
  final Map<String, dynamic> values;
  String text(String key, [String fallback = '']) {
    final value = values[key];
    if (value is DateTime) {
      return '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return value?.toString() ?? fallback;
  }
}

abstract interface class RecordsRepository {
  Stream<List<AppRecord>> watch({
    required String collection,
    String? ownerField,
    String? ownerId,
    String? documentId,
  });
}
