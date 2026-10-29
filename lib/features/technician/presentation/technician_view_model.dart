import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';
import 'media_view_model.dart';

class TechnicianViewModel extends AsyncNotifier<void> {
  @override
  void build() {}
  Future<void> submit() async {
    final session = ref.read(flowProvider);
    await ref.read(repositoryProvider).call('submitTechnicianApplication', {
      'skills': session.selected.toList(),
      'profile': session.fields,
      'documents': ref.read(mediaViewModelProvider),
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
