import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/state.dart';
import '../../../core/presentation/stored_image.dart';
import 'records_view_model.dart';
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
          ).showSnackBar(SnackBar(content: Text(e.toString())));
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
          Text('Credential: ${result?.credentialId ?? "unavailable"}'),
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
        if (screenId == 7 || screenId == 30) ...[
          Text(
            'Hello, ${account?.name ?? ''}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => go(screenId == 7 ? 8 : 32),
            child: Text(
              screenId == 7 ? 'Find a repair service' : 'View my jobs',
            ),
          ),
        ],
        if ([17, 34].contains(screenId))
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Live map requires a configured map and location provider. Your booking address appears below.',
              ),
            ),
          ),
        if (screenId == 29)
          Text(
            'Application status: ${account?.approval.name ?? 'loading'}',
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
                    'Unable to load your data. Check connection and Firebase setup.',
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
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Nothing here yet. Your updates will appear here.'),
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
                            if (screenId == 11)
                              TextButton.icon(
                                onPressed: () => command(
                                  () => ref
                                      .read(accountViewModelProvider.notifier)
                                      .favorite(row.id, true),
                                ),
                                icon: const Icon(Icons.favorite_border),
                                label: const Text('Save favorite'),
                              ),
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
                                  child: Text('$key: ${row.text(key)}'),
                                ),
                            if (screenId == 36)
                              const Text(
                                'A printed badge identifies a server-issued credential. Always compare the technician’s photo and name. Badge display is available only after approval.',
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
                            if ([16, 33, 37].contains(screenId)) ...[
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
                            if ([16, 33, 37].contains(screenId))
                              for (final photo
                                  in row.values['issuePhotos'] as List? ?? [])
                                StoredImage(id: photo as String),
                            if (screenId == 22)
                              const Text(
                                'A receipt is issued after the server confirms settlement. A reported cash payment is not yet a settled payment.',
                              ),
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
            ),
    );
  }
}
