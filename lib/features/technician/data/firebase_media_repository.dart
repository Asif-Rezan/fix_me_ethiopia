import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../domain/media_repository.dart';

class FirebaseMediaRepository implements MediaRepository {
  @override
  Future<String> upload({
    required Uint8List bytes,
    required String path,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 10 MB.');
    }
    await FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }
}
