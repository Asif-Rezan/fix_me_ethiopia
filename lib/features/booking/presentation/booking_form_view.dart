import '../../../core/errors/user_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/state.dart';
import 'booking_view_model.dart';
import 'records_view_model.dart';
import '../../technician/presentation/media_view_model.dart';

class BookingFormView extends ConsumerStatefulWidget {
  const BookingFormView({super.key, required this.step});
  final int step;
  @override
  ConsumerState<BookingFormView> createState() => _BookingFormViewState();
}

class _BookingFormViewState extends ConsumerState<BookingFormView> {
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = userMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void field(String key, String value) =>
      ref.read(flowProvider.notifier).field(key, value);
  Future<void> next() async {
    if (!form.currentState!.validate()) return;
    if (widget.step == 14 &&
        ref.read(flowProvider).fields['scheduledAt'] == null) {
      setState(() => error = 'Choose a date and time.');
      return;
    }
    if (widget.step < 15) {
      context.push('/screen/${widget.step + 1}');
      return;
    }
    await run(() async {
      final fields = ref.read(flowProvider).fields;
      final id = await ref.read(bookingViewModelProvider.notifier).create({
        'categoryId': fields['categoryId'] ?? 'refrigerator',
        'technicianId': fields['technicianId'],
        'issue': fields['Describe the issue'] ?? '',
        'address': fields['Address'] ?? '',
        'scheduledAt': fields['scheduledAt'] ?? '',
      });
      try {
        await ref.read(mediaViewModelProvider.notifier).flushBookingPhotos();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Booking created. Some photos could not upload; you can retry from booking details.',
              ),
            ),
          );
        }
      }
      if (mounted) context.go('/screen/16');
      assert(id.isNotEmpty);
    });
  }

  Future<void> schedule() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    // Ethiopian service schedules use Addis Ababa time (UTC+3, no DST).
    final scheduled = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour - 3,
      time.minute,
    );
    if (!scheduled.isAfter(DateTime.now())) {
      setState(() => error = 'Choose a future time.');
      return;
    }
    field('scheduledAt', scheduled.toIso8601String());
    field(
      'scheduleLabel',
      '${date.day}/${date.month}/${date.year} · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} Addis Ababa',
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(flowProvider), fields = flow.fields;
    final title = {
      12: 'Book a service',
      13: 'Service location',
      14: 'Choose a time',
      15: 'Confirm your booking',
    }[widget.step]!;
    final account = ref.watch(accountProvider).asData?.value;
    final saved = widget.step == 13 && account != null
        ? ref.watch(
            recordsViewModelProvider((
              collection: 'customers/${account.uid}/addresses',
              ownerField: null,
              ownerId: null,
              documentId: null,
            )),
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.step == 15
                          ? 'Check your details before confirming.'
                          : 'Step ${widget.step - 11} of 3 · ${widget.step == 12
                                ? 'Tell us about the problem.'
                                : widget.step == 13
                                ? 'Where do you need help?'
                                : 'Book at your convenience.'}',
                      style: const TextStyle(color: Color(0xFF73869B)),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.home_repair_service_outlined),
                        title: Text(
                          fields['categoryName'] ?? 'Refrigerator repair',
                        ),
                        subtitle: Text(
                          (fields['technicianName'] ?? '').isEmpty
                              ? 'We will help assign an approved technician.'
                              : 'With ${fields['technicianName']}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.step == 12) ...[
                      input(
                        'Describe the issue',
                        hint: 'Tell us what is not working',
                        lines: 3,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final picked = await ImagePicker()
                                    .pickMultiImage(
                                      imageQuality: 75,
                                      maxWidth: 1200,
                                    );
                                if (picked.length +
                                        ref
                                            .read(mediaViewModelProvider)
                                            .length >
                                    8) {
                                  throw ArgumentError(
                                    'Attach up to eight images.',
                                  );
                                }
                                for (final image in picked) {
                                  await ref
                                      .read(mediaViewModelProvider.notifier)
                                      .upload(
                                        await image.readAsBytes(),
                                        kyc: false,
                                      );
                                }
                              }),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          'Add issue photos (${ref.watch(mediaViewModelProvider).length}/8)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      input(
                        'Appliance brand',
                        hint: 'e.g. Samsung, LG, Beko',
                        required: false,
                      ),
                    ],
                    if (widget.step == 13) ...[
                      if (saved != null)
                        saved.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, s) =>
                              const Text('Saved addresses could not load.'),
                          data: (rows) => Column(
                            children: rows
                                .map(
                                  (row) => ListTile(
                                    leading: const Icon(
                                      Icons.location_on_outlined,
                                    ),
                                    title: Text(row.text('label')),
                                    subtitle: Text(row.text('address')),
                                    onTap: () {
                                      field('Address', row.text('address'));
                                      setState(() {});
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      input(
                        'Address',
                        hint: 'Street, building, floor and apartment',
                        lines: 3,
                        keyValue: fields['Address'],
                      ),
                      const SizedBox(height: 16),
                      input(
                        'Landmark',
                        hint: 'Directions to help your technician find you',
                        required: false,
                      ),
                    ],
                    if (widget.step == 14) ...[
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 84,
                        color: Color(0xFF092B4D),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        fields['scheduleLabel'] ?? 'No time selected',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : schedule,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Choose date and time'),
                      ),
                      const Text(
                        'All service times are in Addis Ababa time (UTC+3).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (widget.step == 15) ...[
                      item('Issue', fields['Describe the issue'] ?? ''),
                      item('Address', fields['Address'] ?? ''),
                      item('Date & time', fields['scheduleLabel'] ?? ''),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Estimated charges',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Visit fee: ETB ${fields['visitFee'] ?? '300'}',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Labor and parts require your approval of a quotation. No payment is collected when booking.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: busy ? null : next,
                        child: busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.step == 15
                                    ? 'Confirm booking'
                                    : widget.step == 14
                                    ? 'Review booking'
                                    : 'Continue',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget input(
    String name, {
    String? hint,
    int lines = 1,
    bool required = true,
    String? keyValue,
  }) => TextFormField(
    key: ValueKey('$name-$keyValue'),
    initialValue: ref.read(flowProvider).fields[name] ?? '',
    maxLines: lines,
    decoration: InputDecoration(labelText: name, hintText: hint),
    onChanged: (v) => field(name, v),
    validator: (v) => required && (v == null || v.trim().length < 5)
        ? 'Please enter $name'
        : null,
  );
  Widget item(String label, String value) => ListTile(
    title: Text(
      label,
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(fontSize: 14, color: Color(0xFF092B4D)),
    ),
  );
}
