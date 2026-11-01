import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain.dart';
import '../../../core/records.dart';
import '../../../core/state.dart';
import '../../../core/errors/user_message.dart';
import '../../account/presentation/account_tools_view.dart';
import '../../messaging/presentation/realtime_chat_view.dart';
import '../../notifications/presentation/notification_center_view.dart';
import 'records_view_model.dart';

const workspaceScreens = {7, 23, 24, 25, 30, 31, 32, 40, 41, 42, 43, 44};

class SectionWorkspaceView extends ConsumerStatefulWidget {
  const SectionWorkspaceView({super.key, required this.screenId});
  final int screenId;
  @override
  ConsumerState<SectionWorkspaceView> createState() =>
      _SectionWorkspaceViewState();
}

class _SectionWorkspaceViewState extends ConsumerState<SectionWorkspaceView> {
  String filter = 'All', search = '';
  bool busy = false;

  int get id => widget.screenId;
  void go(int screen) => context.push('/screen/$screen');
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
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

  AsyncValue<List<AppRecord>> records(
    String collection, {
    String? ownerField,
    String? ownerId,
    String? documentId,
  }) => ref.watch(
    recordsViewModelProvider((
      collection: collection,
      ownerField: ownerField,
      ownerId: ownerId,
      documentId: documentId,
    )),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF73869B))),
      ],
    ),
  );
  Widget tile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback tap,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDF5FB),
        child: Icon(icon, color: const Color(0xFF092B4D)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: tap,
    ),
  );
  Widget load(
    AsyncValue<List<AppRecord>> value,
    Widget Function(List<AppRecord>) render,
  ) => value.when(
    loading: () => const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => tile(
      'Unable to load this section',
      'Tap to try again',
      Icons.wifi_off,
      () => ref.invalidate(recordsViewModelProvider),
    ),
    data: render,
  );
  Widget empty(
    String title,
    String subtitle,
    String action,
    VoidCallback tap,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        const Icon(
          Icons.home_repair_service_outlined,
          size: 56,
          color: Color(0xFF319DC3),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: tap, child: Text(action)),
      ],
    ),
  );
  void openBooking(AppRecord row, bool tech) {
    ref.read(flowProvider.notifier).booking(row.id);
    go(tech ? 33 : 16);
  }

  Widget bookingCard(AppRecord row, bool tech) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openBooking(row, tech),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handyman_outlined, color: Color(0xFF319DC3)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.text('name', row.text('categoryId')),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            Chip(
              label: Text(readableStatus(row.text('status'))),
              visualDensity: VisualDensity.compact,
            ),
            Text(row.text('issue')),
            const SizedBox(height: 8),
            Text(
              row.text('scheduledAt'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.text(
                      tech ? 'customerName' : 'technicianName',
                      tech ? 'Customer' : 'Awaiting assignment',
                    ),
                  ),
                ),
                Text(
                  'ETB ${row.text('approvedTotal', row.text('visitFee', '300'))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              row.id,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (id == 44) return const RealtimeChatView();
    if (id == 24) return const NotificationCenterView();
    final account = ref.watch(accountProvider).asData?.value;
    if (account == null) return const SizedBox.shrink();
    final tech = account.role == AccountRole.technician;
    final uid = account.uid;
    if ([25, 43].contains(id)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'My account',
            'Your details, preferences and service essentials',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text(
                      account.name
                          .split(' ')
                          .map((s) => s.isEmpty ? '' : s[0])
                          .take(2)
                          .join(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(tech ? 'Repair professional' : 'FixMe customer'),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      ref.watch(demoModeProvider)
                          ? 'Demo account'
                          : readableStatus(account.approval.name),
                    ),
                  ),
                ],
              ),
            ),
          ),
          load(
            records('users', documentId: uid),
            (rows) => Column(
              children: [
                for (final row in rows) ...[
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(
                      row.text('email', 'Add your email in profile setup'),
                    ),
                  ),
                  if (row.text('phone').isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Phone'),
                      subtitle: Text(row.text('phone')),
                    ),
                ],
              ],
            ),
          ),
          if (!tech) ...[
            tile(
              'My bookings',
              'Upcoming visits and service history',
              Icons.calendar_month_outlined,
              () => go(23),
            ),
            tile(
              'Favorite technicians',
              'Your saved repair professionals',
              Icons.favorite_border,
              () => go(42),
            ),
            const AccountTools(),
          ],
          if (tech) ...[
            tile(
              'My technician ID',
              'View your QR badge',
              Icons.badge_outlined,
              () => go(36),
            ),
            tile(
              'Earnings',
              'Cash receipts and completed services',
              Icons.account_balance_wallet_outlined,
              () => go(40),
            ),
            tile(
              'Customer reviews',
              'Feedback from your service visits',
              Icons.star_outline,
              () => go(42),
            ),
            tile(
              'Payment information',
              'How you receive service payments',
              Icons.payments_outlined,
              () => go(41),
            ),
          ],
          tile(
            'Help and support',
            'Booking, payment and safety questions',
            Icons.help_outline,
            () => go(45),
          ),
        ],
      );
    }
    if (id == 41) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'Payment information',
            'Clear records for every completed service',
          ),
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 72,
            color: Color(0xFF319DC3),
          ),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash after service',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '1. Customer approves the itemized quotation.\n\n2. Complete the repair and request confirmation.\n\n3. Customer reports paying cash directly to you.\n\n4. Confirm receipt to close the booking.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your earnings record updates after receipt is confirmed. Online transfers are not connected.',
                  ),
                ],
              ),
            ),
          ),
          tile(
            'View earnings',
            'Browse your confirmed service payments',
            Icons.receipt_long_outlined,
            () => go(40),
          ),
        ],
      );
    }
    if (id == 42 && tech) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('Customer reviews', 'Feedback from your completed repairs'),
          load(
            records('reviews', ownerField: 'technicianId', ownerId: uid),
            (rows) => rows.isEmpty
                ? empty(
                    'Build your reputation',
                    'Customer reviews appear after completed services.',
                    'View jobs',
                    () => go(32),
                  )
                : Column(
                    children: [
                      for (final row in rows)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row.text('rating')} ★',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 22,
                                  ),
                                ),
                                Text(
                                  row.text('customerName', 'Customer'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(row.text('text')),
                                Text(
                                  row.text('bookingId'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      );
    }
    if (id == 42) {
      final favorites = records('customers/$uid/favorites');
      final technicians = records(
        'technicians',
        ownerField: 'approval',
        ownerId: 'approved',
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('Favorite technicians', 'Great service, saved for next time'),
          load(
            favorites,
            (saved) => load(technicians, (rows) {
              final ids = saved
                  .map((r) => r.text('technicianId', r.id))
                  .toSet();
              final selected = rows.where((r) => ids.contains(r.id)).toList();
              if (selected.isEmpty) {
                return empty(
                  'Find your go-to professional',
                  'Save technicians from their profiles to book them again.',
                  'Browse technicians',
                  () => go(10),
                );
              }
              return Column(
                children: [
                  for (final row in selected)
                    tile(
                      row.text('name'),
                      '${row.text('rating')} ★ · ${row.text('area', 'Addis Ababa')}',
                      Icons.person_outline,
                      () {
                        ref
                            .read(flowProvider.notifier)
                            .field('technicianId', row.id);
                        go(11);
                      },
                    ),
                ],
              );
            }),
          ),
        ],
      );
    }
    if (id == 40) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'My earnings',
            'Confirmed cash received directly from customers',
          ),
          load(records('payments', ownerField: 'technicianId', ownerId: uid), (
            rows,
          ) {
            final settled = rows
                .where(
                  (r) =>
                      r.text('status') == 'completed' ||
                      r.text('status') == 'confirmed' ||
                      r.text('status') == 'settled',
                )
                .toList();
            final total = settled.fold<num>(
              0,
              (sum, r) =>
                  sum + ((r.values['amount'] ?? r.values['total'] ?? 0) as num),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF092B4D),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total cash received',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'ETB $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${settled.length} confirmed services',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (rows.isEmpty)
                  empty(
                    'Your next repair starts here',
                    'Confirmed payments appear after a completed service.',
                    'View jobs',
                    () => go(32),
                  ),
                for (final row in rows)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(row.text('name', row.text('bookingId'))),
                    subtitle: Text(
                      '${row.text('method', 'Cash')} · ${row.text('createdAt')}',
                    ),
                    trailing: Text(
                      'ETB ${row.text('amount', row.text('total'))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            );
          }),
        ],
      );
    }
    return load(
      records(
        'bookings',
        ownerField: tech ? 'technicianId' : 'customerId',
        ownerId: uid,
      ),
      (rows) {
        final active = rows
            .where(
              (r) => !['completed', 'cancelled'].contains(r.text('status')),
            )
            .toList();
        final home = id == 7 || id == 30;
        final visible =
            (home
                    ? active
                    : id == 31
                    ? rows.where((r) => r.text('status') == 'assigned').toList()
                    : rows)
                .where(
                  (r) =>
                      (filter == 'All' ||
                          (filter == 'Active'
                              ? ![
                                  'completed',
                                  'cancelled',
                                ].contains(r.text('status'))
                              : r.text('status') == filter.toLowerCase())) &&
                      '${r.text('name')} ${r.id} ${r.text('issue')}'
                          .toLowerCase()
                          .contains(search.toLowerCase()),
                )
                .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(
              home
                  ? 'Hello, ${account.name.split(' ').first}'
                  : id == 31
                  ? 'Job requests'
                  : tech
                  ? 'My jobs'
                  : 'My bookings',
              home
                  ? 'Let’s make today a little easier.'
                  : 'Keep every service detail in one place.',
            ),
            if (home) ...[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF092B4D),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      tech
                          ? Icons.handyman_outlined
                          : Icons.home_repair_service_outlined,
                      size: 38,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tech
                          ? 'Your skills. Happier homes.'
                          : 'A helping hand for your home',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tech
                          ? '${active.length} active jobs · ${rows.where((r) => r.text('status') == 'completed').length} completed'
                          : 'Trusted repair professionals across Addis Ababa.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => go(tech ? 32 : 8),
                      child: Text(tech ? 'Manage my jobs' : 'Book a service'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (tech)
                SwitchListTile(
                  title: const Text('Available for jobs'),
                  subtitle: const Text(
                    'Let customers know you are ready to help',
                  ),
                  value: ref.watch(flowProvider).online,
                  onChanged: (_) => run(() async {
                    await ref.read(repositoryProvider).call('setAvailability', {
                      'online': !ref.read(flowProvider).online,
                    });
                    ref.read(flowProvider.notifier).online();
                  }),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(tech ? 'All jobs' : 'Bookings'),
                    onPressed: () => go(tech ? 32 : 23),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.favorite_border, size: 18),
                    label: Text(tech ? 'Earnings' : 'Favorites'),
                    onPressed: () => go(tech ? 40 : 42),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Support'),
                    onPressed: () => go(45),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Upcoming services',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
            ] else ...[
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search service or booking number',
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final label in [
                      'All',
                      'Active',
                      'Completed',
                      'Cancelled',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: filter == label,
                          onSelected: (_) => setState(() => filter = label),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (visible.isEmpty)
              empty(
                'No ${filter == 'All' ? '' : filter.toLowerCase()} services',
                tech
                    ? 'Your assigned jobs will appear here.'
                    : 'Find a service and schedule your first visit.',
                tech ? 'Refresh jobs' : 'Browse services',
                () {
                  if (tech) {
                    ref.invalidate(recordsViewModelProvider);
                  } else {
                    go(8);
                  }
                },
              ),
            for (final row in visible.where(
              (r) => id != 31 || r.text('status') == 'assigned',
            ))
              bookingCard(row, tech),
          ],
        );
      },
    );
  }
}
