import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/state.dart';
import 'firebase_options.dart';
import 'core/domain.dart';
import 'features/auth/domain/role_policy.dart';
import 'features/auth/presentation/auth_view.dart';
import 'features/booking/presentation/verification_view_model.dart';
import 'features/technician/presentation/media_view_model.dart';
import 'features/notifications/presentation/notifications_view_model.dart';
import 'features/screens/reference_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  if (production) {
    try {
      await Firebase.initializeApp(
        options: const String.fromEnvironment('FIREBASE_API_KEY').isEmpty
            ? DefaultFirebaseOptions.currentPlatform
            : const FirebaseOptions(
                apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
                appId: String.fromEnvironment('FIREBASE_APP_ID'),
                messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
                projectId: String.fromEnvironment(
                  'FIREBASE_PROJECT_ID',
                  defaultValue: 'fixme-ethiopia',
                ),
                storageBucket: String.fromEnvironment(
                  'FIREBASE_STORAGE_BUCKET',
                ),
                authDomain: 'fixme-ethiopia.firebaseapp.com',
                iosBundleId: 'et.fixme.app',
              ),
      );
      const emulators = bool.fromEnvironment('USE_EMULATORS');
      if (emulators) {
        const host = String.fromEnvironment(
          'EMULATOR_HOST',
          defaultValue: 'localhost',
        );
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      }
      if (!kIsWeb && !emulators) {
        await FirebaseAppCheck.instance.activate();
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    } catch (e) {
      startupError =
          'Firebase could not start. Check platform configuration and App Check.\n$e';
    }
  }
  runApp(ProviderScope(child: FixMeApp(startupError: startupError)));
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(accountProvider, (previous, next) {
    if (previous?.asData?.value?.uid != next.asData?.value?.uid) {
      ref.read(flowProvider.notifier).clear();
      ref.invalidate(verificationViewModelProvider);
      ref.invalidate(mediaViewModelProvider);
      ref.invalidate(notificationsViewModelProvider);
    }
    if (next.asData?.value case final Account account) {
      ref.read(flowProvider.notifier).role(account.role);
    }
    refresh.value++;
  });
  final router = GoRouter(
    initialLocation: '/screen/1',
    refreshListenable: refresh,
    redirect: (_, state) {
      if (state.pathParameters['id'] == '5') return '/screen/4';
      if (!production) return null;
      final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
      final account = ref.read(accountProvider);
      return roleRedirect(
        screen: id,
        account: account.asData?.value,
        loading: account.isLoading,
      );
    },
    routes: [
      GoRoute(
        path: '/screen/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '1') ?? 1;
          if (id == 4) return const AuthView();
          return ReferenceScreen(key: ValueKey(id), id: id.clamp(1, 45));
        },
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class FixMeApp extends ConsumerWidget {
  const FixMeApp({super.key, this.startupError});
  final String? startupError;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'FIX ME ETHIOPIA',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        primary: orange,
        secondary: navy,
        surface: Colors.white,
      ),
      fontFamily: 'Inter',
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: navy,
        displayColor: navy,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFBFCFE),
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF90A0B1)),
        contentPadding: const EdgeInsets.all(13),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFE5EBF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFE5EBF0)),
        ),
      ),
    ),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => startupError == null
        ? child!
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(startupError!),
                ),
              ),
            ),
          ),
  );
}
