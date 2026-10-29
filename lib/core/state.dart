import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories.dart';
import 'domain.dart';

const production = !bool.fromEnvironment('USE_MOCKS', defaultValue: false);
final repositoryProvider = Provider<ServiceRepository>(
  (ref) => production ? FirebaseRepository() : DemoRepository(),
);
final accountProvider = StreamProvider<Account?>(
  (ref) => ref.watch(repositoryProvider).accounts,
);

class FlowState {
  const FlowState({
    this.role = AccountRole.customer,
    this.bookingId = '',
    this.verified = false,
    this.fields = const {},
    this.selected = const {},
    this.messages = const [],
    this.online = true,
  });
  final AccountRole role;
  final String bookingId;
  final bool verified, online;
  final Map<String, String> fields;
  final Set<String> selected;
  final List<String> messages;
  FlowState copy({
    AccountRole? role,
    String? bookingId,
    bool? verified,
    Map<String, String>? fields,
    Set<String>? selected,
    List<String>? messages,
    bool? online,
  }) => FlowState(
    role: role ?? this.role,
    bookingId: bookingId ?? this.bookingId,
    verified: verified ?? this.verified,
    fields: fields ?? this.fields,
    selected: selected ?? this.selected,
    messages: messages ?? this.messages,
    online: online ?? this.online,
  );
}

class FlowController extends Notifier<FlowState> {
  @override
  FlowState build() => const FlowState();
  void role(AccountRole value) => state = state.copy(role: value);
  void field(String key, String value) =>
      state = state.copy(fields: {...state.fields, key: value});
  void select(String key) => state = state.copy(
    selected: state.selected.contains(key)
        ? ({...state.selected}..remove(key))
        : {...state.selected, key},
  );
  void booking(String id) => state = state.copy(bookingId: id, verified: false);
  void verify(bool matched) => state = state.copy(verified: matched);
  void message(String value) =>
      state = state.copy(messages: [...state.messages, value]);
  void online() => state = state.copy(online: !state.online);
  void clear() => state = const FlowState();
}

final flowProvider = NotifierProvider<FlowController, FlowState>(
  FlowController.new,
);
