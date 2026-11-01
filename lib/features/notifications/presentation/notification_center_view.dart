import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain.dart';
import '../../../core/records.dart';
import '../../../core/state.dart';
import '../../../core/errors/user_message.dart';
import '../../booking/presentation/records_view_model.dart';

final notificationFeedProvider = StreamProvider<List<AppRecord>>((ref) {
  final uid = ref.watch(accountProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(<AppRecord>[]);
  return ref
      .watch(recordsRepositoryProvider)
      .watch(collection: 'notifications', ownerField: 'userId', ownerId: uid);
});

class NotificationCenterView extends ConsumerStatefulWidget {
  const NotificationCenterView({super.key});
  @override
  ConsumerState<NotificationCenterView> createState() =>
      _NotificationCenterViewState();
}

class _NotificationCenterViewState
    extends ConsumerState<NotificationCenterView> {
  bool unreadOnly = false, busy = false;
  Future<void> command(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).call(action, data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider);
    final count =
        feed.asData?.value.where((r) => r.values['readAt'] == null).length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text('$count unread updates'),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            FilterChip(
              label: const Text('Unread only'),
              selected: unreadOnly,
              onSelected: (v) => setState(() => unreadOnly = v),
            ),
            TextButton(
              onPressed: busy || count == 0
                  ? null
                  : () => command('markAllNotificationsRead'),
              child: const Text('Mark all read'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        feed.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            children: [
              const Text('Could not load notifications.'),
              TextButton(
                onPressed: () => ref.invalidate(notificationFeedProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (rows) {
            final visible = rows
                .where((r) => !unreadOnly || r.values['readAt'] == null)
                .toList();
            if (visible.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: Color(0xFF319DC3),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'You’re all caught up',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'New messages and booking updates will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final row in visible)
                  Card(
                    color: row.values['readAt'] == null
                        ? const Color(0xFFF0F7FC)
                        : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: Icon(
                        row.text('type') == 'chat'
                            ? Icons.chat_bubble_outline
                            : Icons.home_repair_service_outlined,
                        color: const Color(0xFF319DC3),
                      ),
                      title: Text(
                        row.text('name', 'Service update'),
                        style: TextStyle(
                          fontWeight: row.values['readAt'] == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(row.text('text')),
                          const SizedBox(height: 6),
                          Text(
                            row.text('createdAt'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: row.values['readAt'] == null
                          ? const Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFFED7A28),
                            )
                          : null,
                      onTap: () async {
                        await command('markNotificationRead', {
                          'notificationId': row.id,
                        });
                        if (!context.mounted || row.text('bookingId').isEmpty) {
                          return;
                        }
                        ref
                            .read(flowProvider.notifier)
                            .booking(row.text('bookingId'));
                        context.push(
                          '/screen/${row.text('type') == 'chat'
                              ? 44
                              : ref.read(accountProvider).asData?.value?.role == AccountRole.technician
                              ? 33
                              : 16}',
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
