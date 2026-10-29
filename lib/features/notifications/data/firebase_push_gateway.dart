import 'package:firebase_messaging/firebase_messaging.dart';
import '../domain/push_gateway.dart';

class FirebasePushGateway implements PushGateway {
  @override
  Future<String?> requestToken() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError(
        'Please enable notifications in your phone settings.',
      );
    }
    final registered = FirebaseMessaging.instance.onRegistered.first.timeout(
      const Duration(seconds: 30),
    );
    await FirebaseMessaging.instance.register();
    return registered;
  }

  @override
  Stream<String> get refreshedTokens => FirebaseMessaging.instance.onRegistered;
}
