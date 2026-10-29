import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';
import '../domain/push_gateway.dart';
import '../data/firebase_push_gateway.dart';

final pushGatewayProvider = Provider<PushGateway>(
  (ref) => FirebasePushGateway(),
);

class NotificationsViewModel extends AsyncNotifier<void> {
  StreamSubscription<String>? _subscription;
  @override
  void build() {
    ref.onDispose(() => _subscription?.cancel());
  }

  Future<void> enable() async {
    if (!production) {
      throw StateError('Push delivery is unavailable in demo mode.');
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final gateway = ref.read(pushGatewayProvider);
      final token = await gateway.requestToken();
      if (token == null) {
        throw StateError(
          'No device push token is available. Check platform configuration.',
        );
      }
      await ref.read(repositoryProvider).call('registerPushToken', {
        'token': token,
      });
      await _subscription?.cancel();
      _subscription = gateway.refreshedTokens.listen((value) {
        ref
            .read(repositoryProvider)
            .call('registerPushToken', {'token': value})
            .catchError((Object e) => <String, dynamic>{'error': e.toString()});
      });
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }
}

final notificationsViewModelProvider =
    AsyncNotifierProvider<NotificationsViewModel, void>(
      NotificationsViewModel.new,
    );
