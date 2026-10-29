import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';
import 'media_view_model.dart';
import '../../catalog/domain/service_category.dart';

class TechnicianViewModel extends AsyncNotifier<void> {
  @override
  void build() {}
  Future<void> submit() async {
    final session = ref.read(flowProvider);
    if (production &&
        ref.read(mediaViewModelProvider.notifier).profileId == null) {
      throw ArgumentError(
        'Upload a profile photo and two identity document images before submitting.',
      );
    }
    await ref.read(repositoryProvider).call('submitTechnicianApplication', {
      'skills': session.selected.map(categoryId).toSet().toList(),
      'profile': session.fields,
      'documents': ref
          .read(mediaViewModelProvider)
          .where(
            (id) => id != ref.read(mediaViewModelProvider.notifier).profileId,
          )
          .toList(),
      'photoId': ref.read(mediaViewModelProvider.notifier).profileId,
    });
  }

  Future<void> requestPayout(int amount) async {
    if (amount <= 0) throw ArgumentError('Enter a positive payout amount');
    await ref.read(repositoryProvider).call('requestPayout', {
      'amount': amount,
      'idempotencyKey': 'payout-${DateTime.now().microsecondsSinceEpoch}',
    });
  }

  Future<void> availability(bool online) async {
    await ref.read(repositoryProvider).call('setAvailability', {
      'online': online,
    });
    ref.read(flowProvider.notifier).online();
  }
}

final technicianViewModelProvider =
    AsyncNotifierProvider<TechnicianViewModel, void>(TechnicianViewModel.new);
