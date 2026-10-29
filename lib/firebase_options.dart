// Generated public Firebase client configuration. Never add service-account keys here.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ios,
      TargetPlatform.android => android,
      _ => throw UnsupportedError('Use Android, iOS or web for this app.'),
    };
  }

  static const android = FirebaseOptions(
    apiKey: "AIzaSyCVMoMpEuwia-jaauLzqCOxqI5zkAkBd8o",
    appId: "1:64513607604:android:db4e3d41b14987773d14e1",
    messagingSenderId: "64513607604",
    projectId: "fixme-ethiopia",
    storageBucket: "fixme-ethiopia.firebasestorage.app",
  );
  static const ios = FirebaseOptions(
    apiKey: "AIzaSyDjxx4v4VTUE0RRT8iZODy4R6LYgmu_kro",
    appId: "1:64513607604:ios:566b384a42ea96183d14e1",
    messagingSenderId: "64513607604",
    projectId: "fixme-ethiopia",
    storageBucket: "fixme-ethiopia.firebasestorage.app",
    iosBundleId: "et.fixme.app",
    iosClientId:
        "64513607604-373mq2m6g8iibeu3ui2c0qqumddrsjfk.apps.googleusercontent.com",
  );
  static const web = FirebaseOptions(
    apiKey: "AIzaSyAW_GB82HeHqkXT59nRSG8sFx0pMWIEMgI",
    appId: "1:64513607604:web:b617f95deb2f40a63d14e1",
    messagingSenderId: "64513607604",
    projectId: "fixme-ethiopia",
    authDomain: "fixme-ethiopia.firebaseapp.com",
    storageBucket: "fixme-ethiopia.firebasestorage.app",
    measurementId: "G-WE4TLD9QXH",
  );
  static const googleServerClientId =
      "64513607604-3vaen1m59k8r5cdrab0hb4c5jbgpldb7.apps.googleusercontent.com";
  static const googleIosClientId =
      "64513607604-373mq2m6g8iibeu3ui2c0qqumddrsjfk.apps.googleusercontent.com";
}
