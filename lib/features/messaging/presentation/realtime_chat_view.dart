import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain.dart';
import '../../../core/records.dart';
import '../../../core/state.dart';
import '../../../core/errors/user_message.dart';
import '../../booking/presentation/records_view_model.dart';

const _ink = Color(0xFF102F4C);
const _muted = Color(0xFF8291A4);
const _accent = Color(0xFFF18035);
const _background = Color(0xFFF5F7FA);

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640),
          child: RealtimeChatView(fullHeight: true),
        ),
      ),
    ),
  );
}

class RealtimeChatView extends ConsumerStatefulWidget {
  const RealtimeChatView({super.key, this.fullHeight = false});
  final bool fullHeight;
  @override
  ConsumerState<RealtimeChatView> createState() => _RealtimeChatViewState();
}

class _RealtimeChatViewState extends ConsumerState<RealtimeChatView>
    with WidgetsBindingObserver {
  final input = TextEditingController();
  Timer? typingTimer;
  bool sending = false, activeOnly = false;
  String? error, activeBooking, lastReadMessage;
  String search = '';
  late ServiceRepository repository;
  @override
  void initState() {
    super.initState();
    repository = ref.read(repositoryProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  void quiet(String action, Map<String, dynamic> data) {
    unawaited(
      repository
          .call(action, data)
          .catchError((Object _) => <String, dynamic>{}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    typingTimer?.cancel();
    input.dispose();
    if (activeBooking != null) {
      quiet('setChatPresence', {'bookingId': activeBooking, 'online': false});
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (activeBooking != null) {
      quiet('setChatPresence', {
        'bookingId': activeBooking,
        'online': state == AppLifecycleState.resumed,
      });
    }
  }

  AsyncValue<List<AppRecord>> rows(
    String collection, {
    String? field,
    String? owner,
    String? document,
  }) => ref.watch(
    recordsViewModelProvider((
      collection: collection,
      ownerField: field,
      ownerId: owner,
      documentId: document,
    )),
  );
  void open(String id) {
    input.clear();
    typingTimer?.cancel();
    ref.read(flowProvider.notifier).booking(id);
    setState(() {
      error = null;
      lastReadMessage = null;
    });
  }

  Future<void> send() async {
    final text = input.text.trim(), booking = ref.read(flowProvider).bookingId;
    if (text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await repository.call('sendMessage', {
        'bookingId': booking,
        'text': text,
      });
      input.clear();
    } catch (e) {
      if (mounted) setState(() => error = userMessage(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget frame(Widget child) => widget.fullHeight
      ? child
      : SizedBox(
          height:
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).vertical -
              80,
          child: child,
        );
  Widget stateMessage(
    IconData icon,
    String title,
    String detail, {
    VoidCallback? retry,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: _ink),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.5),
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider).asData?.value;
    if (account == null) return const SizedBox.shrink();
    final booking = ref.watch(flowProvider).bookingId;
    if (activeBooking != booking) {
      if (activeBooking != null) {
        quiet('setChatPresence', {'bookingId': activeBooking, 'online': false});
      }
      activeBooking = booking.isEmpty ? null : booking;
      if (booking.isNotEmpty) {
        quiet('setChatPresence', {'bookingId': booking, 'online': true});
      }
    }
    if (booking.isEmpty) {
      final bookings = rows(
        'bookings',
        field: account.role == AccountRole.customer
            ? 'customerId'
            : 'technicianId',
        owner: account.uid,
      );
      return frame(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messages',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'A little conversation. A better service.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.forum_outlined, color: _accent),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: InputDecoration(
                  hintText: 'Search conversations',
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                  fillColor: _background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All messages'),
                    selected: !activeOnly,
                    onSelected: (_) => setState(() => activeOnly = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Active services'),
                    selected: activeOnly,
                    onSelected: (_) => setState(() => activeOnly = true),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDF0F5)),
            Expanded(
              child: bookings.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => stateMessage(
                  Icons.wifi_off_rounded,
                  'Couldn’t load messages',
                  'Check your connection and try again.',
                  retry: () => ref.invalidate(recordsViewModelProvider),
                ),
                data: (items) {
                  final assigned = items
                      .where(
                        (r) =>
                            r.text('technicianId').isNotEmpty &&
                            (!activeOnly ||
                                ![
                                  'completed',
                                  'cancelled',
                                ].contains(r.text('status'))) &&
                            '${r.text('technicianName')} ${r.text('customerName')} ${r.text('name')} ${r.id}'
                                .toLowerCase()
                                .contains(search.toLowerCase()),
                      )
                      .toList();
                  if (assigned.isEmpty) {
                    return stateMessage(
                      Icons.chat_bubble_outline,
                      search.isEmpty
                          ? 'Your conversations start here'
                          : 'No matching conversations',
                      search.isEmpty
                          ? 'Once a technician is assigned, you can share directions and discuss your repair here.'
                          : 'Try a name, service or booking number.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: assigned.length,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.only(left: 94),
                      child: Divider(height: 1, color: Color(0xFFEDF0F5)),
                    ),
                    itemBuilder: (_, i) => _ConversationTile(
                      booking: assigned[i],
                      account: account,
                      onTap: () => open(assigned[i].id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    final messages = rows('conversations/$booking/messages');
    final reads = rows('conversations/$booking/reads').asData?.value ?? [];
    final presence =
        rows('conversations/$booking/presence').asData?.value ?? [];
    final typing = rows('conversations/$booking/typing').asData?.value ?? [];
    final service = rows(
      'bookings',
      document: booking,
    ).asData?.value.firstOrNull;
    final name =
        service?.text(
          account.role == AccountRole.customer
              ? 'technicianName'
              : 'customerName',
          account.role == AccountRole.customer
              ? 'Your technician'
              : 'Your customer',
        ) ??
        'Service conversation';
    final online = presence.any(
      (r) => r.id != account.uid && r.values['value'] == true,
    );
    final isTyping = typing.any(
      (r) =>
          r.id != account.uid &&
          r.values['value'] is num &&
          DateTime.now().millisecondsSinceEpoch - (r.values['value'] as num) <
              7000,
    );
    final items = messages.asData?.value;
    if (items != null &&
        items.isNotEmpty &&
        lastReadMessage != items.last.id &&
        ModalRoute.of(context)?.isCurrent != false &&
        TickerMode.valuesOf(context).enabled) {
      lastReadMessage = items.last.id;
      quiet('markConversationRead', {'bookingId': booking});
    }
    return frame(
      Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 14),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'All conversations',
                  onPressed: () => open(''),
                  icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                ),
                _Avatar(name: name, size: 44, online: online),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTyping
                            ? 'Typing…'
                            : online
                            ? 'Online now'
                            : 'Reply when they’re available',
                        style: TextStyle(
                          fontSize: 11,
                          color: online ? const Color(0xFF36A082) : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View booking',
                  onPressed: () => context.push(
                    '/screen/${account.role == AccountRole.technician ? 33 : 16}',
                  ),
                  icon: const Icon(Icons.more_horiz_rounded, color: _ink),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFFFF4EC),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              children: [
                const Icon(
                  Icons.home_repair_service_outlined,
                  size: 19,
                  color: _accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    service?.text(
                          'name',
                          service.text('categoryId', 'Service booking'),
                        ) ??
                        'Service booking',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
                Text(
                  booking,
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: _background,
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => stateMessage(
                  Icons.wifi_off_rounded,
                  'This chat isn’t ready yet',
                  'Please try again shortly.',
                  retry: () => ref.invalidate(recordsViewModelProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return stateMessage(
                      Icons.waving_hand_outlined,
                      'Say hello to $name',
                      'Share directions or ask a question about your service.',
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final row = items[items.length - 1 - index];
                      final mine = row.text('senderId') == account.uid;
                      final date = row.values['createdAt'];
                      final timestamp = date is DateTime
                          ? date
                                .subtract(const Duration(hours: 3))
                                .millisecondsSinceEpoch
                          : 0;
                      final seen =
                          mine &&
                          reads.any(
                            (r) =>
                                r.id != account.uid &&
                                r.values['value'] is num &&
                                (r.values['value'] as num) >= timestamp,
                          );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            if (index == items.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9EEF4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _dateLabel(date),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: mine
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!mine) ...[
                                  _Avatar(name: name, size: 28),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width *
                                          .72,
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      15,
                                      12,
                                      15,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine ? _ink : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(
                                          mine ? 18 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          mine ? 4 : 18,
                                        ),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x05000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.text('text'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: mine ? Colors.white : _ink,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _time(date),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: mine
                                                    ? Colors.white60
                                                    : _muted,
                                              ),
                                            ),
                                            if (mine) ...[
                                              const SizedBox(width: 6),
                                              Icon(
                                                seen
                                                    ? Icons.done_all_rounded
                                                    : Icons.done_rounded,
                                                size: 14,
                                                color: seen
                                                    ? const Color(0xFF8AD8CA)
                                                    : Colors.white60,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (mine) const SizedBox(width: 2),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (isTyping)
            Container(
              width: double.infinity,
              color: _background,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                '$name is typing…',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          if (error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF0EB),
              padding: const EdgeInsets.all(12),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEDF0F5))),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    onChanged: (text) {
                      setState(() {});
                      typingTimer?.cancel();
                      quiet('setTyping', {
                        'bookingId': booking,
                        'typing': text.isNotEmpty,
                      });
                      typingTimer = Timer(const Duration(seconds: 4), () {
                        if (mounted) {
                          quiet('setTyping', {
                            'bookingId': booking,
                            'typing': false,
                          });
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Write a message…',
                      counterText: '',
                      filled: true,
                      fillColor: _background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: sending || input.text.trim().isEmpty
                        ? null
                        : send,
                    style: IconButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: const Color(0xFFFFE5D4),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFFD9AB8B),
                    ),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) => name
    .split(' ')
    .where((s) => s.isNotEmpty)
    .take(2)
    .map((s) => s[0])
    .join()
    .toUpperCase();
String _time(dynamic date) => date is DateTime
    ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
    : '';
String _dateLabel(dynamic date) {
  if (date is! DateTime) return 'Service conversation';
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day
      ? 'Today'
      : '${date.day}/${date.month}/${date.year}';
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 52, this.online = false});
  final String name;
  final double size;
  final bool online;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFFE5EEF4),
          child: Text(
            _initials(name),
            style: TextStyle(
              color: _ink,
              fontSize: size * .3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF38B18A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.booking,
    required this.account,
    required this.onTap,
  });
  final AppRecord booking;
  final Account account;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages =
        ref
            .watch(
              recordsViewModelProvider((
                collection: 'conversations/${booking.id}/messages',
                ownerField: null,
                ownerId: null,
                documentId: null,
              )),
            )
            .asData
            ?.value ??
        [];
    final reads =
        ref
            .watch(
              recordsViewModelProvider((
                collection: 'conversations/${booking.id}/reads',
                ownerField: null,
                ownerId: null,
                documentId: null,
              )),
            )
            .asData
            ?.value ??
        [];
    final readAt =
        reads.where((r) => r.id == account.uid).firstOrNull?.values['value']
            as num? ??
        0;
    final unread = messages.where((r) {
      final date = r.values['createdAt'];
      return r.text('senderId') != account.uid &&
          date is DateTime &&
          date.subtract(const Duration(hours: 3)).millisecondsSinceEpoch >
              readAt;
    }).length;
    final name = booking.text(
      account.role == AccountRole.customer ? 'technicianName' : 'customerName',
      account.role == AccountRole.customer
          ? 'Your technician'
          : 'Your customer',
    );
    final last = messages.lastOrNull;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            _Avatar(name: name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                      Text(
                        _time(last?.values['createdAt']),
                        style: TextStyle(
                          fontSize: 10,
                          color: unread > 0 ? _accent : _muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    last?.text('text') ?? 'Start a conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: unread > 0 ? _ink : _muted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${booking.text('name', booking.text('categoryId'))} · ${booking.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
