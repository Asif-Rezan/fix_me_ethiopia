import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain.dart';
import '../../../core/state.dart';
import '../domain/auth_gateway.dart';

class AuthViewModel extends AsyncNotifier<void> {
  @override
  void build() {}
  Future<void> authenticate({
    required bool signIn,
    required String name,
    required String email,
    required String password,
    required AccountRole role,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(repositoryProvider);
    state = await AsyncValue.guard(() async {
      if (signIn) {
        await repo.signIn(email, password);
      } else {
        await repo.register(name, email, password, role);
      }
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> reset(String email) =>
      ref.read(repositoryProvider).resetPassword(email);
  Future<void> logout() async {
    await ref.read(repositoryProvider).signOut();
    ref.read(flowProvider.notifier).clear();
  }

  Future<void> social({bool apple = false}) async {
    final repo = ref.read(repositoryProvider);
    if (repo is! AuthGateway) {
      throw StateError(
        'Social sign-in is only available in the Firebase build.',
      );
    }
    await (apple
        ? (repo as AuthGateway).signInWithApple(
            ref.read(flowProvider).role.name,
          )
        : (repo as AuthGateway).signInWithGoogle(
            ref.read(flowProvider).role.name,
          ));
  }

  Future<void> sendCode(String phone) async {
    final repo = ref.read(repositoryProvider);
    if (repo is! AuthGateway) {
      throw StateError('Phone SMS is unavailable in demo mode.');
    }
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      throw ArgumentError(
        'Use an international phone number, for example +251911234567.',
      );
    }
    await (repo as AuthGateway).sendPhoneCode(phone);
  }

  Future<void> confirmCode(String code) async {
    final repo = ref.read(repositoryProvider);
    if (repo is! AuthGateway) {
      throw StateError('Demo does not send or verify SMS.');
    }
    await (repo as AuthGateway).confirmPhoneCode(
      code,
      ref.read(flowProvider).role.name,
    );
  }

  Future<void> completeProfile() => ref
      .read(repositoryProvider)
      .call('completeProfile', {'profile': ref.read(flowProvider).fields})
      .then((_) {});
}

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, void>(
  AuthViewModel.new,
);
