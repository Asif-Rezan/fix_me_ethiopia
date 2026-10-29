import 'dart:typed_data';

abstract interface class MediaRepository {
  Future<String> upload({required Uint8List bytes, required String path});
}
