import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state.dart';

abstract interface class AppTelemetry {
  Future<void> screen(String name);
  Future<void> event(String name, {Map<String, Object> parameters});
  Future<void> failure(String operation, Object error, StackTrace stack);
}

class NoopTelemetry implements AppTelemetry {
  @override
  Future<void> screen(String name) async {}
  @override
  Future<void> event(
    String name, {
    Map<String, Object> parameters = const {},
  }) async {}
  @override
  Future<void> failure(
    String operation,
    Object error,
    StackTrace stack,
  ) async {}
}

class FirebaseTelemetry implements AppTelemetry {
  final analytics = FirebaseAnalytics.instance;
  @override
  Future<void> screen(String name) => _safe(
    () => analytics.logScreenView(screenName: name, screenClass: 'Flutter'),
  );
  @override
  Future<void> event(
    String name, {
    Map<String, Object> parameters = const {},
  }) => _safe(() => analytics.logEvent(name: name, parameters: parameters));
  @override
  Future<void> failure(
    String operation,
    Object error,
    StackTrace stack,
  ) => _safe(() async {
    if (kIsWeb) return;
    // Deliberately omit exception messages and request payloads: authentication
    // or network errors can contain email addresses, paths, and other PII.
    await FirebaseCrashlytics.instance.recordError(
      StateError('Operation failed: $operation (${error.runtimeType})'),
      stack,
      reason: operation,
      fatal: false,
    );
  });
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      /* Telemetry never blocks an app operation. */
    }
  }

  static Future<void> initialize() async {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            StateError('Uncaught Flutter ${details.exception.runtimeType}'),
            details.stack ?? StackTrace.current,
            fatal: true,
          ),
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            StateError('Uncaught ${error.runtimeType}'),
            stack,
            fatal: true,
          ),
        );
        return true;
      };
    }
  }
}

final telemetryProvider = Provider<AppTelemetry>(
  (ref) => production ? FirebaseTelemetry() : NoopTelemetry(),
);

class TelemetryObserver extends NavigatorObserver {
  TelemetryObserver(this.telemetry);
  final AppTelemetry telemetry;
  void track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) unawaited(telemetry.screen(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      track(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      track(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      track(newRoute);
}
