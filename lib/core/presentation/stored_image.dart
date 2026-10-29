import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/booking/presentation/records_view_model.dart';

class StoredImage extends ConsumerWidget {
  const StoredImage({super.key, required this.id, this.height = 120});
  final String id;
  final double height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id.startsWith('https://')) {
      return Image.network(
        id,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => Icon(Icons.person_outline, size: height),
      );
    }
    final data = ref.watch(
      recordsViewModelProvider((
        collection: 'private_media',
        ownerField: null,
        ownerId: null,
        documentId: id,
      )),
    );
    return data.when(
      loading: () => SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, s) => SizedBox(
        height: height,
        child: const Icon(Icons.broken_image_outlined),
      ),
      data: (rows) {
        if (rows.isEmpty) return const Icon(Icons.broken_image_outlined);
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              base64Decode(rows.first.text('base64')),
              height: height,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {
          return const Icon(Icons.broken_image_outlined);
        }
      },
    );
  }
}
