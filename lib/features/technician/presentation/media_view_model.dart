import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';
import '../domain/media_repository.dart';
import '../data/firebase_media_repository.dart';

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => FirebaseMediaRepository(),
);

class MediaViewModel extends Notifier<List<String>> {
  final List<Uint8List> _pending = [];
  String? profileId;
  @override
  List<String> build() => [];
  Future<void> upload(
    Uint8List bytes, {
    required bool kyc,
    bool profile = false,
  }) async {
    final uid = ref.read(accountProvider).asData?.value?.uid;
    if (!production) {
      state = [...state, 'demo-image-${state.length}'];
      return;
    }
    if (uid == null) throw StateError('Sign in before uploading.');
    final bookingId = ref.read(flowProvider).bookingId;
    if (!kyc && !profile && bookingId.isEmpty) {
      _pending.add(bytes);
      state = [...state, 'pending-${_pending.length}'];
      return;
    }
    final path = profile
        ? 'profiles/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg'
        : kyc
        ? 'kyc/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg'
        : 'bookings/$bookingId/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final result = await ref
        .read(mediaRepositoryProvider)
        .upload(bytes: bytes, path: path);
    if (profile) profileId = result;
    state = [...state, result];
  }

  Future<void> flushBookingPhotos() async {
    if (_pending.isEmpty || !production) return;
    final queued = [..._pending];
    _pending.clear();
    state = [];
    for (final bytes in queued) {
      await upload(bytes, kyc: false);
    }
    await ref.read(repositoryProvider).call('attachBookingPhotos', {
      'bookingId': ref.read(flowProvider).bookingId,
      'paths': state,
    });
  }

  void clear() {
    _pending.clear();
    profileId = null;
    state = [];
  }
}

final mediaViewModelProvider = NotifierProvider<MediaViewModel, List<String>>(
  MediaViewModel.new,
);
