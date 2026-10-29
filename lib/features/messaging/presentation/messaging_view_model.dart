import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';

class MessagingViewModel extends AsyncNotifier<void> {
  @override
  void build() {}
  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    await ref.read(repositoryProvider).call('sendMessage', {
      'bookingId': ref.read(flowProvider).bookingId,
      'text': text.trim(),
    });
    ref.read(flowProvider.notifier).message(text.trim());
  }

  Future<void> support(String description) async {
    if (description.trim().length < 10) {
      throw ArgumentError('Describe the issue in at least 10 characters.');
    }
    await ref.read(repositoryProvider).call('createComplaint', {
      'bookingId': ref.read(flowProvider).bookingId,
      'description': description.trim(),
    });
  }
}

final messagingViewModelProvider =
    AsyncNotifierProvider<MessagingViewModel, void>(MessagingViewModel.new);
