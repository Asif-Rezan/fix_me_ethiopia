import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';
import '../../../core/errors/user_message.dart';
import '../../messaging/presentation/messaging_view_model.dart';
import '../../booking/presentation/records_view_model.dart';

class SupportCenterView extends ConsumerStatefulWidget {
  const SupportCenterView({super.key});
  @override
  ConsumerState<SupportCenterView> createState() => _SupportCenterViewState();
}

class _SupportCenterViewState extends ConsumerState<SupportCenterView> {
  final description = TextEditingController();
  String search = '';
  bool busy = false;
  static const articles = {
    'How do I book a repair?':
        'Open Explore, choose a service and a technician, describe the issue, then select your address and a convenient visit time. Review the details before confirming.',
    'My technician is late or my booking has an issue':
        'Open your booking and use Chat to contact your technician. If you cannot reach them or need to change the visit, submit a support request below with your booking reference.',
    'How do I verify my technician?':
        'When the technician arrives, open the booking and scan their FixMe QR badge. Compare the name and displayed photo with the person at your door before allowing work to begin.',
    'How do quotations and payments work?':
        'You approve an itemized quotation before repair work. After confirming completed work, pay cash directly to the technician and report payment in the app. The technician confirms receipt to complete the booking.',
    'Where can I find my receipt?':
        'Open a completed booking from service history and choose View receipt. You can copy the receipt details for your records.',
    'Which areas are covered?':
        'We currently serve Bole, Arada, Kirkos, Yeka and Nifas Silk in Addis Ababa. Technician availability varies by service and area.',
    'How do I report a safety concern?':
        'Stop the service if you feel unsafe and move to a safe place. Submit the details below for review. Do not share passwords, payment credentials or identity documents in chat.',
    'Why do chat and notifications need a connection?':
        'New messages, read receipts and booking alerts update while your device is connected. If a message fails to send, keep the text and retry once your connection returns.',
  };
  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(accountProvider).asData?.value?.uid;
    final tickets = uid == null
        ? null
        : ref.watch(
            recordsViewModelProvider((
              collection: 'complaints',
              ownerField: 'userId',
              ownerId: uid,
              documentId: null,
            )),
          );
    final visible = articles.entries
        .where(
          (a) => '${a.key} ${a.value}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'How can we help?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Find answers or send a request to our support team.'),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search help articles',
          ),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No matching articles. Describe your question below.'),
          ),
        for (final article in visible)
          Card(
            child: ExpansionTile(
              title: Text(
                article.key,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: [Text(article.value)],
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Contact support',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          ref.watch(flowProvider).bookingId.isEmpty
              ? 'Choose a booking first to link a request, or send a general question.'
              : 'About booking ${ref.watch(flowProvider).bookingId}',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          minLines: 3,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Describe what happened and how we can help',
          ),
        ),
        FilledButton.icon(
          onPressed: busy || uid == null
              ? null
              : () async {
                  if (description.text.trim().length < 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Describe the issue in at least 10 characters.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await ref
                        .read(messagingViewModelProvider.notifier)
                        .support(description.text.trim());
                    description.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Support request submitted. You can follow its status below.',
                          ),
                        ),
                      );
                    }
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
          icon: const Icon(Icons.support_agent),
          label: Text(busy ? 'Submitting…' : 'Submit support request'),
        ),
        const SizedBox(height: 24),
        const Text(
          'My support requests',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (tickets != null)
          tickets.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) =>
                const Text('Could not load your support requests.'),
            data: (rows) => rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Your submitted requests and their status will appear here.',
                    ),
                  )
                : Column(
                    children: [
                      for (final row in rows)
                        ListTile(
                          leading: const Icon(
                            Icons.confirmation_number_outlined,
                          ),
                          title: Text(row.text('description')),
                          subtitle: Text(row.text('bookingId')),
                          trailing: Chip(
                            label: Text(row.text('status', 'open')),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}
