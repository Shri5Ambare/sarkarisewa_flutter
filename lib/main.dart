// ═══════════════════════════════════════════════════════════════════════════
// CLIENT APP ENTRY POINT — Android / iOS / desktop builds.
//
// ✅  flutter build apk          (Android — this file)
// ✅  flutter build ipa          (iOS — this file)
// ❌  NEVER import admin_screen.dart or router_admin.dart here.
//
// Admin code lives in main_admin_web.dart and is NEVER part of this tree.
// ═══════════════════════════════════════════════════════════════════════════
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'router.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'widgets/session_tracker.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Enable offline caching for Firestore for better performance and offline viewing
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Secure Firebase services with App Check
  // Public key only; pass via --dart-define=RECAPTCHA_SITE_KEY=...
  const recaptchaKey = String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
  if (kIsWeb) {
    if (recaptchaKey.isEmpty) {
      debugPrint('WARNING: RECAPTCHA_SITE_KEY not set in .env - App Check disabled on web.');
    } else {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(recaptchaKey),
      );
    }
  } else {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AndroidPlayIntegrityProvider(),
      providerApple: AppleDeviceCheckProvider(),
    );
  }

  // Set up Firebase Cloud Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInitSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: androidInitSettings, iOS: iosInitSettings),
  );

  // Request permission for iOS/Android 13+
  await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true, provisional: false,
  );

  // Foreground notification presentation options (iOS)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  // Subscribe to the global marketing topic (Not supported on Web)
  if (!kIsWeb) {
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
  }

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  runApp(const SarkariSewaApp());
}
class SarkariSewaApp extends StatelessWidget {
  const SarkariSewaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final router = buildRouter(authProvider);
          return SessionTracker(
            child: MaterialApp.router(
              title: 'SarkariSewa',
              theme: AppTheme.light,
              routerConfig: router,
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}
