import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';

class AccountViewModel extends AsyncNotifier<void> {
  @override
  void build() {}
  Future<void> saveAddress(String label, String address) async {
    if (label.trim().isEmpty || address.trim().length < 8) {
      throw ArgumentError('Enter a label and a full address.');
    }
    await ref.read(repositoryProvider).call('saveAddress', {
      'label': label.trim(),
      'address': address.trim(),
    });
  }

  Future<void> favorite(String technicianId, bool favorite) => ref
      .read(repositoryProvider)
      .call('toggleFavorite', {
        'technicianId': technicianId,
        'favorite': favorite,
      })
      .then((_) {});
}

final accountViewModelProvider = AsyncNotifierProvider<AccountViewModel, void>(
  AccountViewModel.new,
);
