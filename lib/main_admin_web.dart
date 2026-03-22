// ═══════════════════════════════════════════════════════════════════════════
// ADMIN WEB ENTRY POINT — web only. Never use this as an APK/iOS build target.
//
// ✅  Web:     flutter build web --target=lib/main_admin_web.dart
// ❌  Android: flutter build apk   ← uses lib/main.dart (client app, no admin)
// ❌  iOS:     flutter build ipa   ← uses lib/main.dart (client app, no admin)
//
// Admin code (admin_screen.dart, router_admin.dart) is ONLY reachable from
// this file and is therefore EXCLUDED from all mobile/desktop APK builds by
// Dart's tree shaker. This guard adds an extra runtime safety net.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'router_admin.dart';
import 'theme.dart';

Future<void> main() async {
  // Hard guard: crash immediately if this entry point is somehow run on a
  // non-web platform. Admin functionality must never execute on a mobile build.
  if (!kIsWeb) {
    throw UnsupportedError(
      'Admin panel is web-only. '
      'Build the client app with: flutter build apk --target=lib/main.dart',
    );
  }

  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const recaptchaKey = String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
  if (kIsWeb) {
    if (recaptchaKey.isEmpty) {
      debugPrint('WARNING: RECAPTCHA_SITE_KEY not set in .env - App Check disabled on admin web.');
    } else {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(recaptchaKey),
      );
    }
  }

  runApp(const SarkariSewaAdminApp());
}

class SarkariSewaAdminApp extends StatelessWidget {
  const SarkariSewaAdminApp({super.key});

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
          final router = buildAdminRouter(authProvider);
          return MaterialApp.router(
            title: 'SarkariSewa Admin',
            theme: AppTheme.light,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
