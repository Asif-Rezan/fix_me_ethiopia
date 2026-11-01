import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain.dart';
import '../../../core/state.dart';

/// Defers notification navigation until the authenticated profile is ready.
class PushNavigation extends ConsumerStatefulWidget {
  const PushNavigation({super.key, required this.child, required this.router});
  final Widget child;
  final GoRouter router;
  @override
  ConsumerState<PushNavigation> createState() => _PushNavigationState();
}

class _PushNavigationState extends ConsumerState<PushNavigation> {
  StreamSubscription<RemoteMessage>? opened;
  RemoteMessage? pending;
  @override
  void initState() {
    super.initState();
    if (!production || ref.read(demoModeProvider)) return;
    opened = FirebaseMessaging.onMessageOpenedApp.listen(received);
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null && mounted) received(message);
        })
        .catchError((Object _) {});
  }

  void received(RemoteMessage message) {
    pending = message;
    navigate();
  }

  void navigate() {
    final account = ref.read(accountProvider).asData?.value;
    final message = pending;
    if (account == null || message == null || ref.read(demoModeProvider)) {
      return;
    }
    pending = null;
    final booking = message.data['bookingId'];
    if (booking is! String ||
        booking.isEmpty ||
        booking.length > 100 ||
        booking.contains('/')) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(flowProvider.notifier).booking(booking);
      widget.router.push(
        '/screen/${message.data['type'] == 'chat'
            ? 44
            : account.role == AccountRole.technician
            ? 33
            : 16}',
      );
    });
  }

  @override
  void dispose() {
    opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountProvider, (_, next) {
      if (next.asData?.value != null) navigate();
    });
    return widget.child;
  }
}
