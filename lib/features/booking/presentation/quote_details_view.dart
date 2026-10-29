import '../../../core/errors/user_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'records_view_model.dart';
import 'booking_view_model.dart';

class QuoteDetails extends ConsumerWidget {
  const QuoteDetails({
    super.key,
    required this.quoteId,
    required this.canRespond,
  });
  final String quoteId;
  final bool canRespond;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      recordsViewModelProvider((
        collection: 'quotes',
        ownerField: null,
        ownerId: null,
        documentId: quoteId,
      )),
    );
    Future<void> respond(bool approve) async {
      try {
        if (approve) {
          await ref.read(bookingViewModelProvider.notifier).approveQuote();
        } else {
          await ref.read(bookingViewModelProvider.notifier).rejectQuote();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(userMessage(e))));
        }
      }
    }

    return data.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, s) => const Text(
        'Quotation could not load. Do not approve until you can review it.',
      ),
      data: (rows) {
        if (rows.isEmpty) return const Text('Quotation unavailable.');
        final quote = rows.first;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Service quotation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(quote.text('description')),
                for (final item in {
                  'visit': 'Visit fee',
                  'labor': 'Labor',
                  'parts': 'Parts',
                  'total': 'Total',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.value),
                        Text(
                          'ETB ${quote.text(item.key)}',
                          style: TextStyle(
                            fontWeight: item.key == 'total'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text('Status: ${quote.text('status')}'),
                if (canRespond && quote.text('status') == 'pending') ...[
                  FilledButton(
                    onPressed: () => respond(true),
                    child: const Text('Approve quotation'),
                  ),
                  TextButton(
                    onPressed: () => respond(false),
                    child: const Text('Reject quotation'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
