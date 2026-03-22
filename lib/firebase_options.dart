// lib/firebase_options.dart
// ═══════════════════════════════════════════════════════════════════
// Project: sarkari-f5155
// Updated: 2026-02-22
// Configuration complete for Web, Android, and iOS.
// ═══════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  // ── Web (complete ✅) ─────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyC0rX6zPFkapNaHsb-ytc0o3vzItxq_pj0',
    appId:             '1:753185635900:web:04a12db5129368c9148d39',
    messagingSenderId: '753185635900',
    projectId:         'sarkari-f5155',
    authDomain:        'sarkari-f5155.firebaseapp.com',
    storageBucket:     'sarkari-f5155.firebasestorage.app',
    measurementId:     'G-RPSDG186X6',
  );

  // ── Android ───────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyCe4xssaPA2CsqiqGcUOfWiTEiMWsUYlBQ',
    appId:             '1:753185635900:android:5e3099aec868b625148d39',
    messagingSenderId: '753185635900',
    projectId:         'sarkari-f5155',
    storageBucket:     'sarkari-f5155.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:        'AIzaSyByMINqbvwm4zs9O5BylUJG_aPOuM7yjNg',
    appId:         '1:753185635900:ios:4d4adc5f80519c73148d39',
    messagingSenderId: '753185635900',
    projectId:     'sarkari-f5155',
    storageBucket: 'sarkari-f5155.firebasestorage.app',
    iosBundleId:   'np.sarkarisewa.sarkarisewa',
  );
}
