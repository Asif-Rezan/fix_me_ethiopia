import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/domain.dart';
import '../../core/state.dart';
import '../../data/repositories.dart';
import '../auth/presentation/auth_view_model.dart';
import '../booking/presentation/booking_view_model.dart';
import '../technician/presentation/technician_view_model.dart';
import '../messaging/presentation/messaging_view_model.dart';
import '../booking/presentation/live_records_view.dart';
import '../booking/presentation/records_view_model.dart';
import '../technician/presentation/media_view_model.dart';
import '../notifications/presentation/notifications_view_model.dart';

const navy = Color(0xFF092B4D),
    orange = Color(0xFFFF6410),
    muted = Color(0xFF73869B),
    pale = Color(0xFFF3F6FA);
final designsProvider = FutureProvider<List<dynamic>>(
  (ref) async =>
      jsonDecode(await rootBundle.loadString('assets/data/screens.json'))
          as List<dynamic>,
);
String nodeText(Map<String, dynamic> n) => n['tag'] == 'text'
    ? n['text'] as String
    : (n['children'] as List? ?? [])
          .map((e) => nodeText(Map<String, dynamic>.from(e as Map)))
          .join(n['tag'] == 'br' ? '\n' : '');
String css(Map<String, dynamic> n) =>
    (n['attrs'] as Map?)?['class'] as String? ?? '';
List<Map<String, dynamic>> children(Map<String, dynamic> n) =>
    (n['children'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

class ReferenceScreen extends ConsumerStatefulWidget {
  const ReferenceScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends ConsumerState<ReferenceScreen> {
  bool busy = false, signingIn = false;
  String? error;
  final form = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  final List<XFile> photos = [];
  int selectedDay = 29;
  String slot = '10:00 AM';
  String? selectedTab;
  int get id => widget.id;
  FlowState get flow => ref.read(flowProvider);
  void go(int page) => context.push('/screen/$page');
  void toast(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String value(String label) =>
      controllers[label]?.text.trim() ?? flow.fields[label] ?? '';
  Future<void> action(String text) async {
    final label = text.replaceAll('→', '').trim();
    if (id == 5 && label.contains('Verify')) {
      await run(() async {
        await ref
            .read(authViewModelProvider.notifier)
            .confirmCode(value('OTP'));
        if (mounted) go(6);
      });
      return;
    }
    if (label.contains('Sign in')) {
      setState(() => signingIn = true);
      return;
    }
    if (label.contains('Forgot')) {
      await run(() async {
        if (value('Email address').isEmpty) {
          throw Exception('Enter your email first.');
        }
        await ref
            .read(authViewModelProvider.notifier)
            .reset(value('Email address'));
        toast(
          production ? 'Password reset email sent.' : 'Demo: no email sent.',
        );
      });
      return;
    }
    if (label.contains('Get Started')) {
      go(2);
      return;
    }
    if (label.contains('View all') || label == 'More') {
      go(8);
      return;
    }
    if (label.contains('See all')) {
      go(
        id == 11
            ? 42
            : id == 30
            ? 31
            : 10,
      );
      return;
    }
    if (label.contains('View Profile')) {
      go(11);
      return;
    }
    if (label.contains('Book Technician')) {
      go(12);
      return;
    }
    if (label.contains('Contact Technician') ||
        label.contains('Chat') ||
        label.contains('Customer') && id == 33) {
      go(44);
      return;
    }
    if (label.contains('Reject') ||
        label.contains('Support') ||
        label.contains('safety')) {
      go(45);
      return;
    }
    if (label.contains('Download Invoice')) {
      await Clipboard.setData(
        ClipboardData(
          text:
              'FIX ME ETHIOPIA\n${flow.bookingId}\n${production ? 'Invoice is available after server payment confirmation.' : 'DEMO receipt • ETB 1,350 • not a payment receipt'}',
        ),
      );
      toast('Invoice details copied');
      return;
    }
    if (label.contains('Show My ID') ||
        label.contains('Credential Details') ||
        label.contains('technician ID')) {
      go(36);
      return;
    }
    if (label.contains('Verification Status')) {
      toast('Waiting for the customer to scan your badge.');
      return;
    }
    if (label.contains('Back to Home')) {
      context.go('/screen/${flow.role == AccountRole.customer ? 7 : 30}');
      return;
    }
    if (label.contains('Back to My Jobs')) {
      go(32);
      return;
    }
    if (label.contains('Turn on flashlight')) {
      toast('Open the camera scanner to use the torch.');
      return;
    }
    if (label.contains('Accept')) {
      await run(() async {
        await ref.read(bookingViewModelProvider.notifier).accept();
        if (mounted) go(33);
      });
      return;
    }
    if (label.contains('Open Job') ||
        label.contains('View Details') ||
        label.contains('View Booking') ||
        label.contains('Review request')) {
      go(flow.role == AccountRole.technician ? 33 : 16);
      return;
    }
    if (label.contains('Book Again')) {
      go(12);
      return;
    }
    if (label.contains('Request Payout')) {
      await run(() async {
        final amount = int.tryParse(
          value('Withdrawal amount').replaceAll(RegExp('[^0-9]'), ''),
        );
        if (amount == null || amount <= 0) {
          throw Exception('Enter a valid withdrawal amount.');
        }
        await ref
            .read(technicianViewModelProvider.notifier)
            .requestPayout(amount);
        toast(
          production
              ? 'Payout request submitted.'
              : 'Demo payout request saved; no funds transferred.',
        );
      });
      return;
    }
    if (label.contains('Confirm Payment')) {
      await run(() async {
        await ref.read(bookingViewModelProvider.notifier).recordCash();
        if (mounted) go(22);
      });
      return;
    }
    if (label.contains('Approve Quote')) {
      await run(() async {
        await ref.read(bookingViewModelProvider.notifier).approveQuote();
        if (mounted) go(21);
      });
      return;
    }
    if (label.contains('Send Quote')) {
      await run(() async {
        final labor = int.tryParse(
          value('Labor cost').replaceAll(RegExp('[^0-9]'), ''),
        );
        final parts = int.tryParse(
          value('Parts cost').replaceAll(RegExp('[^0-9]'), ''),
        );
        if (labor == null || parts == null) {
          throw Exception('Enter labor and parts costs.');
        }
        await ref
            .read(bookingViewModelProvider.notifier)
            .quote(labor, parts, value('Part description'));
        toast(production ? 'Quotation sent.' : 'Demo quotation saved.');
        if (mounted) go(37);
      });
      return;
    }
    if (label.contains('Mark On The Way') || label.contains('Mark Arrived')) {
      await run(() async {
        await ref
            .read(bookingViewModelProvider.notifier)
            .transition(
              id == 33 ? BookingStatus.onTheWay : BookingStatus.arrived,
            );
        if (mounted) go(id == 33 ? 34 : 35);
      });
      return;
    }
    if (label.contains('Create Quotation')) {
      go(38);
      return;
    }
    if (label.contains('Confirm Booking')) {
      await run(() async {
        final bookingId = await ref
            .read(bookingViewModelProvider.notifier)
            .create({
              'categoryId': 'refrigerator',
              'issue': flow.fields['Describe the issue'] ?? '',
              'address': flow.fields['Address'] ?? 'Bole, Addis Ababa',
              'scheduledAt':
                  flow.fields['scheduledAt'] ??
                  DateTime.now()
                      .add(const Duration(days: 1))
                      .toUtc()
                      .toIso8601String(),
              'slot': flow.fields['slot'] ?? slot,
            });
        ref.read(flowProvider.notifier).booking(bookingId);
        await ref.read(mediaViewModelProvider.notifier).flushBookingPhotos();
        if (mounted) go(16);
      });
      return;
    }
    if (label.contains('Create Account') || label == 'Sign In') {
      if (!(form.currentState?.validate() ?? false)) return;
      await run(() async {
        await ref
            .read(authViewModelProvider.notifier)
            .authenticate(
              signIn: signingIn,
              name: value('Full name'),
              email: value('Email address'),
              password: value('Password'),
              role: flow.role,
            );
        if (mounted) {
          go(signingIn ? (flow.role == AccountRole.customer ? 7 : 30) : 6);
        }
      });
      return;
    }
    if (label.contains('Submit for Review')) {
      await run(() async {
        if (production && photos.length < 2) {
          throw Exception('Upload your identity documents before submitting.');
        }
        await ref.read(technicianViewModelProvider.notifier).submit();
        if (mounted) go(29);
      });
      return;
    }
    if (id == 29) {
      toast(
        'Your application is pending review. You will be notified when its status changes.',
      );
      return;
    }
    if (label.contains('Save Profile')) {
      if (!(form.currentState?.validate() ?? false)) return;
      await run(() async {
        await ref.read(authViewModelProvider.notifier).completeProfile();
        if (mounted) go(flow.role == AccountRole.customer ? 7 : 26);
      });
      return;
    }
    if (id == 18) {
      await scan();
      return;
    }
    if (id == 4 || id == 6 || id == 12 || id == 13 || id == 26) {
      if (!(form.currentState?.validate() ?? false)) return;
    }
    final next = <int, int>{
      2: 3,
      3: 4,
      5: 6,
      6: 7,
      9: 10,
      12: 13,
      13: 14,
      14: 15,
      17: 16,
      19: 16,
      26: 27,
      27: 28,
    };
    if (id == 14 && flow.fields['scheduledAt'] == null) {
      ref
          .read(flowProvider.notifier)
          .field(
            'scheduledAt',
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              selectedDay,
              10,
            ).toUtc().toIso8601String(),
          );
      ref.read(flowProvider.notifier).field('slot', slot);
    }
    if (next.containsKey(id)) {
      go(next[id]!);
      return;
    }
    toast('Select an option to continue.');
  }

  Future<void> upload() async {
    await run(() async {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
      );
      for (final file in picked) {
        await ref
            .read(mediaViewModelProvider.notifier)
            .upload(await file.readAsBytes(), kyc: id == 28);
      }
      if (picked.isNotEmpty) setState(() => photos.addAll(picked));
    });
  }

  Future<void> scan() async {
    if (!production) {
      final c = TextEditingController(text: 'DEMO-FIXME-00002');
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Demo badge verification'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(labelText: 'Demo credential'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Test match'),
            ),
          ],
        ),
      );
      c.dispose();
      if (code != null) {
        await verify(code);
      }
      return;
    }
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));
    if (code != null) await verify(code);
  }

  Future<void> verify(String code) => run(() async {
    if (flow.bookingId.isEmpty && production) {
      throw Exception('Select an active booking first.');
    }
    final r = await ref.read(bookingViewModelProvider.notifier).verify(code);
    ref.read(flowProvider.notifier).verify(r.matched);
    if (!r.matched) {
      throw Exception('Badge mismatch. Do not start work. Contact support.');
    }
    if (mounted) go(19);
  });
  @override
  Widget build(BuildContext context) {
    final designs = ref.watch(designsProvider);
    ref.watch(flowProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: designs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) =>
                  Center(child: Text('Unable to load screens: $e')),
              data: (all) {
                final screen = Map<String, dynamic>.from(all[id - 1] as Map);
                return Column(
                  children: [
                    if (!production)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFFF2E7),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'DEMO • sample data • no real payments or identity checks',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, color: navy),
                        ),
                      ),
                    if (id != 1)
                      Container(
                        height: 49,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: pale)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => go(
                                flow.role == AccountRole.customer ? 7 : 30,
                              ),
                              child: Image.asset(
                                'assets/brand/logo.jpeg',
                                width: 66,
                                height: 42,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: () => go(24),
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                size: 19,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Account and preview',
                              onSelected: (v) async {
                                if (v == 'logout') {
                                  await ref
                                      .read(authViewModelProvider.notifier)
                                      .logout();
                                  ref.read(flowProvider.notifier).clear();
                                  if (context.mounted) context.go('/screen/3');
                                } else if (v == 'preview') {
                                  showGallery(all);
                                } else if (v == 'demo') {
                                  ref
                                      .read(flowProvider.notifier)
                                      .role(AccountRole.technician);
                                  (ref.read(repositoryProvider)
                                          as DemoRepository)
                                      .enter(AccountRole.technician);
                                  go(30);
                                }
                              },
                              itemBuilder: (_) => [
                                if (!production)
                                  const PopupMenuItem(
                                    value: 'preview',
                                    child: Text('Preview all 45 screens'),
                                  ),
                                if (!production)
                                  const PopupMenuItem(
                                    value: 'demo',
                                    child: Text('Preview technician account'),
                                  ),
                                const PopupMenuItem(
                                  value: 'logout',
                                  child: Text('Sign out'),
                                ),
                              ],
                              icon: const Icon(
                                Icons.account_circle_outlined,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Form(
                        key: form,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (error != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: const Color(0xFFFFECE7),
                                  child: Text(
                                    error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              if (busy)
                                const LinearProgressIndicator(color: orange),
                              if (production &&
                                  productionDataScreens.contains(id))
                                LiveRecordsView(screenId: id)
                              else
                                ...children(screen).map(render),
                              if (id == 24)
                                TextButton.icon(
                                  onPressed: () => run(() async {
                                    await ref
                                        .read(
                                          notificationsViewModelProvider
                                              .notifier,
                                        )
                                        .enable();
                                    toast(
                                      'Device registered for notifications.',
                                    );
                                  }),
                                  icon: const Icon(
                                    Icons.notifications_active_outlined,
                                  ),
                                  label: const Text(
                                    'Enable device notifications',
                                  ),
                                ),
                              if (id == 4) ...[
                                TextButton.icon(
                                  onPressed: () => run(() async {
                                    await ref
                                        .read(authViewModelProvider.notifier)
                                        .social();
                                    if (mounted) go(6);
                                  }),
                                  icon: const Icon(Icons.login),
                                  label: const Text('Continue with Google'),
                                ),
                                if (Theme.of(context).platform ==
                                    TargetPlatform.iOS)
                                  TextButton(
                                    onPressed: () => run(() async {
                                      await ref
                                          .read(authViewModelProvider.notifier)
                                          .social(apple: true);
                                      if (mounted) go(6);
                                    }),
                                    child: const Text('Continue with Apple'),
                                  ),
                                TextButton(
                                  onPressed: () => run(() async {
                                    await ref
                                        .read(authViewModelProvider.notifier)
                                        .sendCode(value('Phone number'));
                                    if (mounted) go(5);
                                  }),
                                  child: const Text('Sign in with phone'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => signingIn = !signingIn),
                                  child: Text(
                                    signingIn
                                        ? 'Create a new account'
                                        : 'Already have an account? Sign in',
                                  ),
                                ),
                                if (signingIn)
                                  FilledButton(
                                    onPressed: () => action('Sign In'),
                                    child: const Text('Sign In'),
                                  ),
                                TextButton(
                                  onPressed: () => action('Forgot'),
                                  child: const Text('Forgot password?'),
                                ),
                              ],
                              if (production && id == 13)
                                TextFormField(
                                  initialValue: flow.fields['Address'],
                                  decoration: const InputDecoration(
                                    labelText: 'Full service address',
                                  ),
                                  onChanged: (v) => ref
                                      .read(flowProvider.notifier)
                                      .field('Address', v),
                                  validator: (v) =>
                                      v == null || v.trim().length < 8
                                      ? 'Enter your full service address'
                                      : null,
                                ),
                              if (production && id == 14)
                                TextButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 90),
                                      ),
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                    );
                                    if (date != null) {
                                      ref
                                          .read(flowProvider.notifier)
                                          .field(
                                            'scheduledAt',
                                            DateTime(
                                              date.year,
                                              date.month,
                                              date.day,
                                              10,
                                            ).toUtc().toIso8601String(),
                                          );
                                      setState(() => selectedDay = date.day);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_month),
                                  label: const Text('Choose booking date'),
                                ),
                              if (id == 18)
                                FilledButton.icon(
                                  onPressed: scan,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Open camera scanner'),
                                ),
                              if (id == 44) ...[
                                ...flow.messages.map(
                                  (m) => Align(
                                    alignment: Alignment.centerRight,
                                    child: box(
                                      Text(
                                        m,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      color: orange,
                                    ),
                                  ),
                                ),
                                TextField(
                                  controller: controllers.putIfAbsent(
                                    'Message',
                                    () => TextEditingController(),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: () => run(() async {
                                        final text = value('Message');
                                        if (text.isEmpty) return;
                                        await ref
                                            .read(
                                              messagingViewModelProvider
                                                  .notifier,
                                            )
                                            .send(text);
                                        controllers['Message']!.clear();
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                              if (id == 45)
                                TextField(
                                  controller: controllers.putIfAbsent(
                                    'Support message',
                                    () => TextEditingController(),
                                  ),
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Describe your issue',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: () => run(() async {
                                        if (value('Support message').length <
                                            10) {
                                          throw Exception(
                                            'Please describe the issue in at least 10 characters.',
                                          );
                                        }
                                        await ref
                                            .read(
                                              messagingViewModelProvider
                                                  .notifier,
                                            )
                                            .support(value('Support message'));
                                        toast('Support request submitted.');
                                      }),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (screen['nav'] == true) bottomNav(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void showGallery(List<dynamic> all) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            const ListTile(
              title: Text('Design preview • all 45 native screens'),
            ),
            for (final s in all)
              ListTile(
                title: Text(
                  '${s['id']}. ${s['name'].toString().replaceAll('_', ' ')}',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  go(s['id'] as int);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget bottomNav() {
    final tech = flow.role == AccountRole.technician;
    final targets = tech ? [30, 32, 36, 40, 43] : [7, 23, 8, 44, 25];
    final labels = tech
        ? ['Home', 'Jobs', 'ID Card', 'Earnings', 'Profile']
        : ['Home', 'Bookings', 'Explore', 'Chat', 'Profile'];
    final icons = tech
        ? [
            Icons.home_outlined,
            Icons.list_alt,
            Icons.badge_outlined,
            Icons.account_balance_wallet_outlined,
            Icons.account_circle_outlined,
          ]
        : [
            Icons.home_outlined,
            Icons.calendar_month_outlined,
            Icons.search,
            Icons.chat_bubble_outline,
            Icons.account_circle_outlined,
          ];
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: pale)),
      ),
      child: Row(
        children: List.generate(
          5,
          (i) => Expanded(
            child: InkWell(
              onTap: () => go(targets[i]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icons[i],
                    size: 22,
                    color: id == targets[i] ? orange : muted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 9,
                      color: id == targets[i] ? orange : muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget box(
    Widget child, {
    Color color = Colors.white,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Color border = const Color(0xFFE9EEF3),
  }) => Container(
    padding: padding ?? const EdgeInsets.all(15),
    margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06052241),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
  Widget col(
    List<Map<String, dynamic>> nodes, {
    bool center = false,
    Color? color,
  }) => DefaultTextStyle.merge(
    style: TextStyle(color: color),
    child: Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: nodes.map(render).toList(),
    ),
  );
  Widget txt(
    String t, {
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.normal,
    TextAlign? align,
  }) => Text(
    t,
    style: TextStyle(
      fontSize: size,
      color: color ?? navy,
      fontWeight: weight,
      height: 1.35,
    ),
    textAlign: align,
  );
  Widget render(Map<String, dynamic> n) {
    final tag = n['tag'] as String,
        c = css(n),
        nodes = children(n),
        t = nodeText(n).trim();
    bool has(String v) => c.split(' ').contains(v);
    if (tag == 'text') return txt(t);
    if (tag == 'br') return const SizedBox(height: 1);
    if (has('splash')) {
      return Column(
        children: [
          const SizedBox(height: 70),
          Image.asset(
            'assets/brand/logo.jpeg',
            width: 220,
            height: 210,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 28),
          txt('Your Trusted', size: 29, weight: FontWeight.w800),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                  text: 'Home Service ',
                  style: TextStyle(color: orange),
                ),
                TextSpan(text: 'Partner'),
              ],
            ),
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
          const SizedBox(height: 14),
          txt(
            'Reliable professionals, verified identities and\nconvenient home repair.',
            color: muted,
            align: TextAlign.center,
          ),
          const SizedBox(height: 38),
          const Icon(Icons.home_repair_service_rounded, size: 100, color: navy),
          const SizedBox(height: 55),
          button('Get Started'),
        ],
      );
    }
    if (has('heroicon') || has('wordmark') || has('ethiopia')) {
      return const SizedBox.shrink();
    }
    if (has('section-head')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 17),
        child: col(nodes),
      );
    }
    if (tag == 'h1') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: txt(
          signingIn && id == 4 ? 'Welcome back' : t,
          size: 25,
          weight: FontWeight.w800,
        ),
      );
    }
    if (tag == 'h2') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: txt(t, size: 16, weight: FontWeight.w700),
      );
    }
    if (tag == 'h3') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
        child: txt(t, size: 14, weight: FontWeight.w700),
      );
    }
    if (tag == 'p') {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: txt(t, size: 12, color: muted),
      );
    }
    if (tag == 'small' || has('muted') || has('micro')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: txt(t, size: 11, color: muted),
      );
    }
    if (has('fieldlabel')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 7),
        child: txt(t, size: 12, weight: FontWeight.w700),
      );
    }
    if (has('field')) {
      final all = ref.read(designsProvider).asData?.value;
      String label = '';
      void locate(List<Map<String, dynamic>> list) {
        for (var i = 0; i < list.length; i++) {
          if (identical(list[i], n) || jsonEncode(list[i]) == jsonEncode(n)) {
            if (i > 0 && css(list[i - 1]).contains('fieldlabel')) {
              label = nodeText(list[i - 1]);
            }
          }
          locate(children(list[i]));
        }
      }

      if (all != null) {
        locate(children(Map<String, dynamic>.from(all[id - 1] as Map)));
      }
      if (label.isEmpty) label = t;
      final key = label;
      final password = label.toLowerCase().contains('password');
      final phone = label.toLowerCase().contains('phone');
      final email = label.toLowerCase().contains('email');
      final number =
          label.toLowerCase().contains('cost') ||
          label.toLowerCase().contains('amount') ||
          label.contains('experience');
      return TextFormField(
        controller: controllers.putIfAbsent(
          key,
          () => TextEditingController(text: flow.fields[key] ?? ''),
        ),
        obscureText: password,
        keyboardType: email
            ? TextInputType.emailAddress
            : phone
            ? TextInputType.phone
            : number
            ? TextInputType.number
            : TextInputType.text,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 12, color: navy),
        decoration: InputDecoration(hintText: t),
        onChanged: (v) => ref.read(flowProvider.notifier).field(key, v),
        validator: (v) {
          if (key.contains('optional') ||
              key.contains('Landmark') ||
              key.contains('brand')) {
            return null;
          }
          if (v == null || v.trim().isEmpty) {
            return 'Please enter ${key.toLowerCase()}';
          }
          if (email && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
            return 'Enter a valid email';
          }
          if (password && v.length < 8) return 'Use at least 8 characters';
          return null;
        },
      );
    }
    if (has('btn') || has('thinbtn') || has('mini-btn')) {
      return button(
        t,
        secondary: has('secondary') || has('thinbtn'),
        compact: has('thinbtn') || has('mini-btn'),
      );
    }
    if (has('search')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: TextField(
          onChanged: (v) => ref.read(flowProvider.notifier).field('search', v),
          onSubmitted: (_) => go(9),
          decoration: InputDecoration(
            hintText: t.replaceAll('⌕', '').trim(),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: IconButton(
              onPressed: () => go(9),
              icon: const Icon(Icons.tune, size: 18),
            ),
          ),
        ),
      );
    }
    if (has('tabs') || has('pills')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          children: nodes.map((ch) {
            final s = nodeText(ch);
            return ChoiceChip(
              label: txt(
                s,
                size: 11,
                color: (selectedTab ?? nodeText(nodes.first)) == s
                    ? Colors.white
                    : muted,
              ),
              selected: (selectedTab ?? nodeText(nodes.first)) == s,
              selectedColor: orange,
              backgroundColor: pale,
              side: BorderSide.none,
              onSelected: (_) {
                setState(() => selectedTab = s);
                if (s.toLowerCase().contains('technician')) {
                  ref.read(flowProvider.notifier).role(AccountRole.technician);
                }
                if (s == 'Customer') {
                  ref.read(flowProvider.notifier).role(AccountRole.customer);
                }
              },
            );
          }).toList(),
        ),
      );
    }
    if (has('card')) {
      if (id == 3) {
        return InkWell(
          onTap: () => ref
              .read(flowProvider.notifier)
              .role(
                t.contains('Technician')
                    ? AccountRole.technician
                    : AccountRole.customer,
              ),
          child: box(
            col(nodes),
            color:
                (flow.role == AccountRole.technician) ==
                    t.contains('Technician')
                ? const Color(0xFFFFF9F4)
                : Colors.white,
            border:
                (flow.role == AccountRole.technician) ==
                    t.contains('Technician')
                ? orange
                : const Color(0xFFE9EEF3),
          ),
        );
      }
      return box(col(nodes));
    }
    if (has('split')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: has('total') ? const EdgeInsets.only(top: 12) : null,
        decoration: has('total')
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: pale)),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (nodes.isNotEmpty) Expanded(flex: 3, child: render(nodes.first)),
            ...nodes.skip(1).map((node) => Flexible(child: render(node))),
          ],
        ),
      );
    }
    if (has('services')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: LayoutBuilder(
          builder: (_, bounds) {
            final count = has('larger') ? 3 : 4;
            return Wrap(
              spacing: 8,
              runSpacing: 16,
              children: nodes
                  .map(
                    (v) => SizedBox(
                      width: (bounds.maxWidth - (count - 1) * 8) / count,
                      child: render(v),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      );
    }
    if (has('service')) {
      return InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          if (id == 27) {
            ref.read(flowProvider.notifier).select(t);
          } else {
            ref.read(flowProvider.notifier).field('category', t);
            go(10);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: flow.selected.contains(t)
                ? Border.all(color: orange)
                : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: nodes
                .map(
                  (node) => node['tag'] == 'b'
                      ? Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: txt(
                            nodeText(node),
                            size: 10,
                            weight: FontWeight.w700,
                            align: TextAlign.center,
                          ),
                        )
                      : render(node),
                )
                .toList(),
          ),
        ),
      );
    }
    if (has('serviceico')) {
      return Container(
        height: id == 7 ? 59 : 78,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF5FB),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Icon(serviceIcon(t), color: const Color(0xFF319DC3), size: 30),
      );
    }
    if (has('listrow')) {
      return InkWell(
        onTap: () => rowAction(t),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          constraints: const BoxConstraints(minHeight: 65),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: pale)),
          ),
          child: Row(
            children: nodes
                .map(
                  (v) => css(v).contains('grow')
                      ? Expanded(child: render(v))
                      : render(v),
                )
                .toList(),
          ),
        ),
      );
    }
    if (has('bubble')) {
      return Container(
        width: 39,
        height: 39,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF5FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(serviceIcon(t), color: const Color(0xFF47799D), size: 20),
      );
    }
    if (has('grow')) return col(nodes);
    if (has('chev')) {
      return const Icon(Icons.chevron_right, size: 20, color: muted);
    }
    if (has('avatar')) {
      final big = has('big') || has('jumbo');
      return Padding(
        padding: EdgeInsets.symmetric(vertical: big ? 18 : 0),
        child: CircleAvatar(
          radius: big ? 50 : 24,
          backgroundColor: const Color(0xFFE4F2FB),
          child: Icon(
            Icons.person,
            color: const Color(0xFF1976C7),
            size: big ? 70 : 32,
          ),
        ),
      );
    }
    if (has('person')) {
      return Row(
        children: nodes
            .map(
              (v) => !css(v).contains('avatar') && !css(v).contains('chev')
                  ? Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: render(v),
                      ),
                    )
                  : render(v),
            )
            .toList(),
      );
    }
    if (has('profilehero')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: col(nodes, center: true),
      );
    }
    if (has('stats')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: nodes
              .map(
                (v) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: render(v),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    if (has('stat')) {
      return box(
        col(nodes, center: true),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
      );
    }
    if (has('chip')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: has('ok')
              ? const Color(0xFFE6F8F0)
              : has('pending')
              ? const Color(0xFFFFF1DB)
              : pale,
          borderRadius: BorderRadius.circular(99),
        ),
        child: txt(
          t,
          size: 10,
          color: has('ok') ? const Color(0xFF13805A) : muted,
        ),
      );
    }
    if (has('greeting')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: col(nodes),
      );
    }
    if (has('banner') || has('earncard')) {
      return Container(
        constraints: has('banner')
            ? const BoxConstraints(minHeight: 154)
            : null,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF052C50), Color(0xFF0B4876)],
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (has('banner')) ...[
                  txt('FIXME ETHIOPIA', size: 10, color: Colors.white),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: txt(
                          'Your home,\nin expert hands.',
                          size: 23,
                          color: Colors.white,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const Icon(
                        Icons.engineering,
                        size: 70,
                        color: Color(0xFF9ECBE8),
                      ),
                    ],
                  ),
                  txt(
                    'Trusted repair. Anytime.',
                    color: Colors.white,
                    size: 11,
                  ),
                ] else
                  ...nodes.map(
                    (v) => txt(
                      nodeText(v),
                      size: v['tag'] == 'h1' ? 32 : 11,
                      color: Colors.white,
                      weight: v['tag'] == 'h1'
                          ? FontWeight.w800
                          : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (has('illustration')) {
      return Container(
        height: has('modest') ? 190 : 258,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFFE6F4FF), Colors.white]),
        ),
        child: const Icon(Icons.engineering_rounded, size: 125, color: navy),
      );
    }
    if (has('rolepic')) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          t.contains('🏠') ? Icons.home_rounded : Icons.engineering_rounded,
          size: 58,
          color: navy,
        ),
      );
    }
    if (has('dots')) {
      return Center(child: txt('●　○　○', size: 20, color: orange));
    }
    if (has('upload') || has('photogrid')) {
      return InkWell(
        onTap: upload,
        child: box(
          Column(
            children: [
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: muted,
                size: 32,
              ),
              const SizedBox(height: 10),
              txt(
                photos.isEmpty
                    ? 'Tap to upload photos'
                    : '${photos.length} photos selected',
                color: muted,
                align: TextAlign.center,
              ),
            ],
          ),
          padding: const EdgeInsets.all(25),
        ),
      );
    }
    if (has('map')) {
      return Container(
        height: has('tall') ? 445 : 220,
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF4F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: CustomPaint(painter: MapPainter())),
            const Icon(Icons.location_pin, size: 65, color: orange),
            Positioned(
              bottom: 15,
              child: txt(
                'BOLE · ADDIS ABABA • Map preview',
                size: 10,
                color: muted,
              ),
            ),
          ],
        ),
      );
    }
    if (has('month')) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: txt(
          '‹       October 2026       ›',
          size: 16,
          weight: FontWeight.w800,
          align: TextAlign.center,
        ),
      );
    }
    if (has('calendar')) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children:
            List.generate(
              31,
              (i) => LayoutBuilder(builder: (_, b) => const SizedBox.shrink()),
            ).isEmpty
            ? []
            : List.generate(
                31,
                (i) => SizedBox(
                  width:
                      (MediaQuery.sizeOf(context).width.clamp(0, 480) - 76) / 7,
                  height: 36,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: selectedDay == i + 1 ? orange : pale,
                      foregroundColor: selectedDay == i + 1
                          ? Colors.white
                          : navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => selectedDay = i + 1),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
      );
    }
    if (has('slots')) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nodes.map((v) {
          final s = nodeText(v);
          return ChoiceChip(
            label: Text(s, style: const TextStyle(fontSize: 10)),
            selected: slot == s,
            onSelected: (_) => setState(() => slot = s),
            selectedColor: orange,
          );
        }).toList(),
      );
    }
    if (has('step')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE6F9F2),
              child: Icon(Icons.check, size: 18, color: Color(0xFF14805B)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: col(
                nodes.where((v) => !css(v).contains('check')).toList(),
              ),
            ),
          ],
        ),
      );
    }
    if (has('scanner')) {
      return InkWell(
        onTap: scan,
        child: Container(
          height: 385,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF061E34),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: orange, width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 150,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              txt(
                'Tap to scan a technician badge',
                color: Colors.white,
                size: 11,
              ),
            ],
          ),
        ),
      );
    }
    if (has('success')) {
      return Container(
        width: 104,
        height: 104,
        margin: const EdgeInsets.fromLTRB(0, 40, 0, 30),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFD9F8EB),
        ),
        child: const Icon(Icons.check, size: 65, color: Color(0xFF079867)),
      );
    }
    if (has('money')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: txt(t, size: 34, weight: FontWeight.w900),
      );
    }
    if (has('online')) {
      return SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        tileColor: const Color(0xFFE8FAF1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        title: txt(
          flow.online ? 'Available for jobs' : 'Offline',
          color: const Color(0xFF15714F),
        ),
        value: flow.online,
        onChanged: (_) => run(() async {
          await ref
              .read(technicianViewModelProvider.notifier)
              .availability(!flow.online);
        }),
      );
    }
    if (has('progress')) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 15),
        child: LinearProgressIndicator(
          value: .42,
          color: orange,
          backgroundColor: pale,
          borderRadius: BorderRadius.all(Radius.circular(99)),
          minHeight: 8,
        ),
      );
    }
    if (has('idcard')) {
      return box(
        col(nodes, center: true),
        color: const Color(0xFFEBF6FF),
        padding: const EdgeInsets.all(24),
      );
    }
    if (has('fakeqr')) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.badge_outlined, size: 100, color: navy),
            Text(
              'Credential issued after server approval',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      );
    }
    if (has('idbrand')) {
      return Image.asset('assets/brand/logo.jpeg', width: 110, height: 70);
    }
    if (has('bars')) {
      return SizedBox(
        height: 142,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
            7,
            (i) => Expanded(
              child: Container(
                height: [48.0, 75.0, 58.0, 95.0, 65.0, 100.0, 82.0][i],
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: orange,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (has('ratingbig')) return txt(t, size: 40, weight: FontWeight.w900);
    if (has('otp')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: TextFormField(
          controller: controllers.putIfAbsent(
            'OTP',
            () => TextEditingController(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6-digit verification code',
          ),
          validator: (v) => v?.length == 6 ? null : 'Enter all 6 digits',
        ),
      );
    }
    if (has('msg')) {
      return Align(
        alignment: has('mine') ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 290),
          padding: const EdgeInsets.all(13),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: has('mine') ? orange : const Color(0xFFEDF3FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: txt(t, size: 13, color: has('mine') ? Colors.white : navy),
        ),
      );
    }
    if (has('chatinput')) return const SizedBox.shrink();
    if (tag == 'a') {
      return InkWell(
        onTap: () => action(t),
        child: txt(t, size: 11, color: orange, weight: FontWeight.w700),
      );
    }
    if (tag == 'b' || tag == 'strong') {
      return txt(t, size: has('navy') ? 16 : 13, weight: FontWeight.w700);
    }
    if (tag == 'span' && nodes.isEmpty) return txt(t);
    if (has('center')) return col(nodes, center: true);
    return nodes.isEmpty ? txt(t) : col(nodes);
  }

  Widget button(String text, {bool secondary = false, bool compact = false}) =>
      Padding(
        padding: EdgeInsets.only(top: compact ? 10 : 16, bottom: 10),
        child: SizedBox(
          height: compact ? 38 : 47,
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: secondary ? pale : orange,
              foregroundColor: secondary ? navy : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: busy ? null : () => action(text),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    text.replaceAll('→', '').trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 17),
              ],
            ),
          ),
        ),
      );
  void rowAction(String t) {
    if (id == 28) {
      upload();
      return;
    }
    if (t.contains('earnings') ||
        t.contains('Payout') ||
        t.contains('Bank account')) {
      go(41);
      return;
    }
    if (t.contains('ID') || t.contains('verification')) {
      go(36);
      return;
    }
    if (t.contains('Notifications')) {
      go(24);
      return;
    }
    if (t.contains('Help') ||
        t.contains('Support') ||
        t.contains('booking has') ||
        t.contains('refund')) {
      go(45);
      return;
    }
    if (id == 20 || id == 24) {
      go(20);
      return;
    }
    if (t.contains('Address') ||
        t.contains('address') ||
        t.contains('coverage')) {
      go(13);
      return;
    }
    if (t.contains('skills')) {
      go(27);
      return;
    }
    if (t.contains('Schedule') || t.contains('time')) {
      go(14);
      return;
    }
    if (t.contains('Customer')) {
      go(44);
      return;
    }
    if (t.contains('Home')) {
      ref.read(flowProvider.notifier).select(t);
      toast('Address selected');
      return;
    }
    if (t.contains('Mobile money') || t.contains('Bank card')) {
      toast(
        'Online payments require a configured payment gateway. Choose cash after service.',
      );
      return;
    }
    if (t.contains('Cash')) {
      ref.read(flowProvider.notifier).select('cash');
      toast('Cash after service selected');
      return;
    }
    if (id == 37) {
      if (production && !flow.verified) {
        toast('Booking identity verification is required before work starts.');
        return;
      }
      ref.read(flowProvider.notifier).select(t);
      return;
    }
    toast('Selected: $t');
  }
}

IconData serviceIcon(String text) {
  if (text.contains('🧊') || text.contains('Fridge')) {
    return Icons.kitchen_outlined;
  }
  if (text.contains('❄')) return Icons.ac_unit;
  if (text.contains('💡')) return Icons.lightbulb_outline;
  if (text.contains('📡')) return Icons.satellite_alt;
  if (text.contains('🚰') || text.contains('🫧')) return Icons.plumbing;
  if (text.contains('📺')) return Icons.tv;
  if (text.contains('📍')) return Icons.location_on_outlined;
  if (text.contains('📷')) return Icons.camera_alt_outlined;
  if (text.contains('💳')) return Icons.credit_card;
  if (text.contains('👨') || text.contains('👤')) return Icons.person_outline;
  return Icons.grid_view_outlined;
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD9E6EB)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final controller = MobileScannerController();
  bool captured = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan assigned technician badge'),
      actions: [
        IconButton(
          onPressed: () => controller.toggleTorch(),
          icon: const Icon(Icons.flashlight_on),
        ),
      ],
    ),
    body: MobileScanner(
      controller: controller,
      onDetect: (capture) {
        final code = capture.barcodes.firstOrNull?.rawValue;
        if (!captured && code != null) {
          captured = true;
          Navigator.pop(context, code);
        }
      },
    ),
  );
}
