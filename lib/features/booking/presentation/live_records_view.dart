import '../../../core/errors/user_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/state.dart';
import '../../../core/presentation/stored_image.dart';
import 'records_view_model.dart';
import 'section_workspace_view.dart';
import 'booking_view_model.dart';
import 'verification_view_model.dart';
import 'quote_details_view.dart';
import '../../account/presentation/account_tools_view.dart';
import '../../account/presentation/account_view_model.dart';
import '../../../core/domain.dart';

class LiveRecordsView extends ConsumerWidget {
  const LiveRecordsView({super.key, required this.screenId});
  final int screenId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspaceScreens.contains(screenId)) {
      return SectionWorkspaceView(screenId: screenId);
    }
    final account = ref.watch(accountProvider).asData?.value;
    final records = ref.watch(currentRecordsProvider(screenId));
    final booking = ref.watch(flowProvider).bookingId;
    void go(int id) => context.push('/screen/$id');
    Future<void> command(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(userMessage(e))));
        }
      }
    }

    if (screenId == 19) {
      final result = ref.watch(verificationViewModelProvider);
      return Column(
        children: [
          Icon(
            result?.matched == true ? Icons.verified_user : Icons.warning_amber,
            size: 80,
            color: result?.matched == true ? Colors.green : Colors.orange,
          ),
          Text(
            result?.matched == true
                ? 'Badge matches this booking'
                : 'Identity not verified',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (result?.photoUrl != null)
            StoredImage(id: result!.photoUrl!, height: 160),
          Text(result?.technicianName ?? 'No verified technician'),
          const Text('This check applies only to your current booking.'),
          const Text(
            'Compare the person at your door with this photo. A badge match alone does not prove physical identity.',
          ),
          TextButton(
            onPressed: () => go(16),
            child: const Text('Return to booking'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          const {
                10: 'Find a professional',
                11: 'Technician profile',
                16: 'Your service',
                17: 'Service location',
                20: 'Review quotation',
                21: 'Payment',
                22: 'Service receipt',
                29: 'Application progress',
                33: 'Job details',
                34: 'Service directions',
                35: 'Arrival & verification',
                36: 'My technician ID',
                37: 'Work progress',
                39: 'Service completion',
              }[screenId] ??
              'Service details',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        if ([17, 34].contains(screenId))
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 64,
                    color: Color(0xFF319DC3),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Directions to your service',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Open the service address in your map app for directions.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        if (screenId == 29)
          Text(
            'Application status: ${readableStatus(account?.approval.name ?? 'pending')}',
            style: const TextStyle(fontSize: 20),
          ),
        records.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'We couldn’t load your updates. Check your connection and try again.',
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(currentRecordsProvider(screenId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return Column(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text('Choose a service to view its details.'),
                  TextButton(
                    onPressed: () =>
                        go(account?.role == AccountRole.technician ? 32 : 23),
                    child: const Text('Choose booking'),
                  ),
                ],
              );
            }
            final filtered = screenId == 10
                ? rows.where((row) {
                    final skills = row.values['skills'] as List? ?? [];
                    final category = ref
                        .read(flowProvider)
                        .fields['categoryId'];
                    return category == null || skills.contains(category);
                  }).toList()
                : rows;
            if (filtered.isEmpty) {
              return Column(
                children: [
                  const Text(
                    'No approved technicians are available for this service yet.',
                  ),
                  TextButton(
                    onPressed: () => go(12),
                    child: const Text('Request this service'),
                  ),
                ],
              );
            }
            return Column(
              children: filtered
                  .map(
                    (row) => Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              row.text(
                                'name',
                                row.text(
                                  'categoryId',
                                  row.text('text', 'Booking ${row.id}'),
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if ([10, 11].contains(screenId) &&
                                row.text('photoId').isNotEmpty)
                              StoredImage(id: row.text('photoId')),
                            if (row.text('quoteId').isNotEmpty)
                              QuoteDetails(
                                quoteId: row.text('quoteId'),
                                canRespond:
                                    account?.role == AccountRole.customer,
                              ),
                            if ([10, 11].contains(screenId)) ...[
                              Text(
                                '${row.text('rating', 'New')} ★ · ${row.text('completedJobs', '0')} repairs · ${row.text('area', 'Addis Ababa')}',
                              ),
                              if (screenId == 11) ...[
                                const SizedBox(height: 12),
                                Text(
                                  row.text(
                                    'bio',
                                    'Approved repair professional.',
                                  ),
                                ),
                                Text(
                                  'Experience: ${row.text('experience', 'Contact for details')}',
                                ),
                              ],
                            ],
                            if (screenId == 11)
                              FavoriteTechnicianButton(technicianId: row.id),
                            if (screenId == 36 &&
                                row.text('badgeToken').isNotEmpty) ...[
                              QrImageView(
                                data: row.text('badgeToken'),
                                size: 220,
                              ),
                              Text(account?.name ?? ''),
                              const Text(
                                'Show this badge to your assigned customer.',
                              ),
                            ],
                            for (final key in [
                              'status',
                              'issue',
                              'scheduledAt',
                              'visitFee',
                              'approvedTotal',
                              'approval',
                              'rating',
                              'availableBalance',
                            ])
                              if (row.values.containsKey(key))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${const {'status': 'Booking status', 'issue': 'Issue', 'scheduledAt': 'Scheduled visit', 'visitFee': 'Visit fee', 'approvedTotal': 'Approved total', 'approval': 'Account status', 'rating': 'Rating', 'availableBalance': 'Available balance'}[key] ?? 'Details'}: ${['status', 'approval'].contains(key) ? readableStatus(row.text(key)) : row.text(key)}',
                                  ),
                                ),
                            if (screenId == 36)
                              const Text(
                                'Show this ID to your customer. Your customer should compare your photo and name before work starts.',
                              ),
                            if ([7, 23, 30, 31, 32].contains(screenId))
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(flowProvider.notifier)
                                      .booking(row.id);
                                  go(
                                    account?.role == AccountRole.technician
                                        ? 33
                                        : 16,
                                  );
                                },
                                child: const Text('View booking'),
                              ),
                            if ([10, 11].contains(screenId))
                              FilledButton(
                                onPressed: () {
                                  ref
                                      .read(flowProvider.notifier)
                                      .field('technicianId', row.id);
                                  ref
                                      .read(flowProvider.notifier)
                                      .field(
                                        'technicianName',
                                        row.text('name'),
                                      );
                                  if (screenId == 10) {
                                    go(11);
                                    return;
                                  }
                                  go(12);
                                },
                                child: const Text('Book technician'),
                              ),
                            if ([33, 37].contains(screenId) &&
                                row.text('status') == 'in_progress' &&
                                account?.role == AccountRole.technician)
                              for (final task in {
                                'inspection': 'Initial inspection',
                                'diagnosis': 'Diagnose the issue',
                                'repair': 'Complete the repair',
                                'test': 'Test operation',
                              }.entries)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(task.value),
                                  value:
                                      (row.values['checklist']
                                          as Map?)?[task.key] ==
                                      true,
                                  onChanged: (value) => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .task(task.key, value ?? false),
                                  ),
                                ),
                            if ([
                              16,
                              21,
                              33,
                              35,
                              37,
                              39,
                            ].contains(screenId)) ...[
                              if (row.text('status') == 'assigned' &&
                                  account?.role == AccountRole.technician) ...[
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .accept(),
                                  ),
                                  child: const Text('Accept assigned job'),
                                ),
                                TextButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .reject(),
                                  ),
                                  child: const Text('Decline request'),
                                ),
                              ],
                              if (row.text('status') == 'payment_pending' &&
                                  account?.role == AccountRole.technician)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .confirmCash(),
                                  ),
                                  child: const Text('Confirm cash received'),
                                ),
                              if (row.text('status') == 'accepted' &&
                                  account?.role == AccountRole.technician)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .transition(BookingStatus.onTheWay),
                                  ),
                                  child: const Text('Mark on the way'),
                                ),
                              if (row.text('status') == 'on_the_way' &&
                                  account?.role == AccountRole.technician)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .transition(BookingStatus.arrived),
                                  ),
                                  child: const Text('Mark arrived'),
                                ),
                              if (row.text('status') == 'arrived' &&
                                  account?.role == AccountRole.customer)
                                FilledButton(
                                  onPressed: () => go(18),
                                  child: const Text('Verify technician badge'),
                                ),
                              if (row.text('status') == 'identity_verified' &&
                                  account?.role == AccountRole.technician)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .transition(BookingStatus.inProgress),
                                  ),
                                  child: const Text('Start work'),
                                ),
                              if (row.text('status') == 'in_progress' &&
                                  account?.role == AccountRole.technician) ...[
                                FilledButton(
                                  onPressed: () => go(38),
                                  child: const Text('Create quotation'),
                                ),
                                if (row.values['quoteApprovedAt'] != null)
                                  FilledButton(
                                    onPressed: () => command(
                                      () => ref
                                          .read(
                                            bookingViewModelProvider.notifier,
                                          )
                                          .transition(
                                            BookingStatus.workCompleted,
                                          ),
                                    ),
                                    child: const Text('Request completion'),
                                  ),
                              ],
                              if (row.text('status') == 'quote_pending' &&
                                  account?.role == AccountRole.customer)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .approveQuote(),
                                  ),
                                  child: const Text('Approve quotation'),
                                ),
                              if (row.text('status') == 'work_completed' &&
                                  account?.role == AccountRole.customer)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .transition(
                                          BookingStatus.customerConfirmed,
                                        ),
                                  ),
                                  child: const Text('Confirm completed work'),
                                ),
                              if (row.text('status') == 'customer_confirmed' &&
                                  account?.role == AccountRole.customer)
                                FilledButton(
                                  onPressed: () => command(
                                    () => ref
                                        .read(bookingViewModelProvider.notifier)
                                        .recordCash(),
                                  ),
                                  child: const Text('Report cash paid'),
                                ),
                              OutlinedButton(
                                onPressed: () => go(44),
                                child: const Text('Open chat'),
                              ),
                            ],
                            if ([16, 33, 34].contains(screenId))
                              BookingAddress(bookingId: row.id),
                            if ([16, 21, 33, 35, 37, 39].contains(screenId))
                              for (final photo
                                  in row.values['issuePhotos'] as List? ?? [])
                                StoredImage(id: photo as String),
                            if ([16, 33].contains(screenId)) ...[
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => go(
                                      account?.role == AccountRole.technician
                                          ? 34
                                          : 17,
                                    ),
                                    icon: const Icon(Icons.map_outlined),
                                    label: const Text('Directions'),
                                  ),
                                  if (row.text('quoteId').isNotEmpty &&
                                      account?.role == AccountRole.customer)
                                    OutlinedButton(
                                      onPressed: () => go(20),
                                      child: const Text('Quotation'),
                                    ),
                                  if (account?.role == AccountRole.customer)
                                    OutlinedButton(
                                      onPressed: () => go(21),
                                      child: const Text('Payment details'),
                                    ),
                                  if (row.text('status') == 'completed' &&
                                      account?.role == AccountRole.customer)
                                    OutlinedButton(
                                      onPressed: () => go(22),
                                      child: const Text('View receipt'),
                                    ),
                                ],
                              ),
                            ],
                            if (screenId == 22) ...[
                              const Divider(height: 28),
                              Text(
                                row.text('status') == 'completed'
                                    ? 'Cash receipt confirmed'
                                    : 'Payment awaiting confirmation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Service reference: ${row.id}'),
                              Text(
                                'Visit fee: ETB ${row.text('visitFee', '300')}',
                              ),
                              Text(
                                'Total: ETB ${row.text('approvedTotal', row.text('visitFee', '300'))}',
                              ),
                              if (row.text('status') == 'completed')
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text:
                                            'FIX ME ETHIOPIA${ref.read(demoModeProvider) ? ' · DEMO RECEIPT' : ''}\nService: ${row.id}\nTotal: ETB ${row.text('approvedTotal', row.text('visitFee'))}\nCash received by technician.',
                                      ),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Receipt copied'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('Copy receipt'),
                                ),
                            ],
                            if (row.text('status') == 'completed' &&
                                account?.role == AccountRole.customer &&
                                [16, 22].contains(screenId))
                              const ReviewComposer(),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (screenId == 25) const AccountTools(),
        if (screenId == 21 || screenId == 41)
          OutlinedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Payment gateway demo'),
                content: const Text(
                  'Online payments are not connected. This demo does not collect money or change your booking payment status. Cash after service is available.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Text('Try online payment (demo)'),
          ),
        if (screenId == 25 || screenId == 43)
          OutlinedButton(
            onPressed: () => go(45),
            child: const Text('Help and support'),
          ),
        if (booking.isEmpty && [16, 33].contains(screenId))
          TextButton(
            onPressed: () =>
                go(account?.role == AccountRole.technician ? 32 : 23),
            child: const Text('Choose a booking'),
          ),
      ],
    );
  }
}

class BookingAddress extends ConsumerWidget {
  const BookingAddress({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(
      recordsViewModelProvider((
        collection: 'bookings/$bookingId/private',
        ownerField: null,
        ownerId: null,
        documentId: 'address',
      )),
    );
    return record.when(
      loading: () => const SizedBox.shrink(),
      error: (_, s) => const Text('Address unavailable'),
      data: (rows) => rows.isEmpty
          ? const SizedBox.shrink()
          : ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Service address'),
              subtitle: Text(rows.first.text('address')),
              trailing: IconButton(
                tooltip: 'Open free map',
                icon: const Icon(Icons.map_outlined),
                onPressed: () => launchUrl(
                  Uri.https('www.openstreetmap.org', '/search', {
                    'query': rows.first.text('address'),
                  }),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
    );
  }
}

class ReviewComposer extends ConsumerStatefulWidget {
  const ReviewComposer({super.key});
  @override
  ConsumerState<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends ConsumerState<ReviewComposer> {
  final text = TextEditingController();
  int rating = 5;
  bool busy = false, saved = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => saved
      ? const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Thank you for sharing your review!'),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 28),
            const Text(
              'How was your service?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i stars',
                    onPressed: () => setState(() => rating = i),
                    icon: Icon(
                      i <= rating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: text,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Tell us about your repair experience',
              ),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (text.text.trim().length < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Add a few words about your service.',
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        await ref
                            .read(bookingViewModelProvider.notifier)
                            .review(rating, text.text.trim());
                        if (mounted) setState(() => saved = true);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(userMessage(e))),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Submit review'),
            ),
          ],
        );
}

class FavoriteTechnicianButton extends ConsumerStatefulWidget {
  const FavoriteTechnicianButton({super.key, required this.technicianId});
  final String technicianId;
  @override
  ConsumerState<FavoriteTechnicianButton> createState() =>
      _FavoriteTechnicianButtonState();
}

class _FavoriteTechnicianButtonState
    extends ConsumerState<FavoriteTechnicianButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(accountProvider).asData?.value?.uid;
    if (uid == null) return const SizedBox.shrink();
    final favorite = ref.watch(
      recordsViewModelProvider((
        collection: 'customers/$uid/favorites',
        ownerField: null,
        ownerId: null,
        documentId: widget.technicianId,
      )),
    );
    final saved = favorite.asData?.value.isNotEmpty ?? false;
    return TextButton.icon(
      onPressed: busy || favorite.isLoading
          ? null
          : () async {
              setState(() => busy = true);
              try {
                await ref
                    .read(accountViewModelProvider.notifier)
                    .favorite(widget.technicianId, !saved);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(userMessage(e))));
                }
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
      icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
      label: Text(saved ? 'Saved · tap to remove' : 'Save favorite'),
    );
  }
}
