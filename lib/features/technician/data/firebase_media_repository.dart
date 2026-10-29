import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../domain/media_repository.dart';

Uint8List compressPhoto(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw ArgumentError('Choose a JPEG, PNG or WebP image.');
  final resized = image.width > 1200 || image.height > 1200
      ? img.copyResize(
          image,
          width: image.width >= image.height ? 1200 : null,
          height: image.height > image.width ? 1200 : null,
        )
      : image;
  for (final quality in [80, 65, 50, 35]) {
    final jpg = img.encodeJpg(resized, quality: quality);
    if (jpg.length <= 290000) return jpg;
  }
  throw ArgumentError('This image is too large. Choose a smaller photo.');
}

/// Small compressed image documents keep the MVP on Firestore Spark, without
/// provisioning a paid Cloud Storage bucket. KYC is owner/admin read only.
class FirebaseMediaRepository implements MediaRepository {
  @override
  Future<String> upload({
    required Uint8List bytes,
    required String path,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 10 MB.');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    final parts = path.split('/'),
        kind = path.startsWith('kyc/')
            ? 'kyc'
            : path.startsWith('profiles/')
            ? 'profile'
            : 'booking';
    final photo = await compute(compressPhoto, bytes);
    final ref = await FirebaseFirestore.instance
        .collection('private_media')
        .add({
          'ownerId': uid,
          'kind': kind,
          'bookingId': kind == 'booking' ? parts[1] : '',
          'base64': base64Encode(photo),
          'createdAt': FieldValue.serverTimestamp(),
        });
    return ref.id;
  }
}
