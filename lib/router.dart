// lib/router.dart
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/ai_viva_screen.dart';
import 'screens/writing_screen.dart';
import 'screens/social_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/order_confirm_screen.dart';
import 'screens/teacher_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/news_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/battle_lobby_screen.dart';
import 'screens/client_access_blocked_screen.dart';
import 'screens/mock_test_screen.dart';
import 'screens/mock_test_result_screen.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      final isLoggedIn = authProvider.isLoggedIn;
      final isLoading  = authProvider.loading;
      final path       = state.uri.path;
      final role       = authProvider.role;

      // Wait during loading
      if (isLoading) return null;
      final isAdminLevel = role == 'admin' || role == 'super_admin';

      final publicRoutes = ['/', '/login', '/signup', '/forgot-password'];
      final isPublic = publicRoutes.contains(path);

      if (!isLoggedIn && !isPublic) return '/login';

      // Admins must use the dedicated admin web app — block them here.
      if (isLoggedIn && isAdminLevel) {
        return path == '/client-access-blocked' ? null : '/client-access-blocked';
      }

      if (isLoggedIn && isPublic && path != '/') {
        return switch (role) {
          'teacher' => '/teacher',
          _         => '/dashboard',
        };
      }

      // Role-based guards
      if (path.startsWith('/teacher') && role != 'teacher') {
        return '/dashboard';
      }

      return null;
    },
    errorBuilder: (ctx, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/', builder: (ctx, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (ctx, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardScreen()),
      GoRoute(path: '/course/:id', builder: (ctx, s) => CourseDetailScreen(courseId: s.pathParameters['id']!)),
      GoRoute(path: '/ai-viva', builder: (ctx, _) => const AIVivaScreen()),
      GoRoute(path: '/writing', builder: (ctx, _) => const WritingScreen()),
      GoRoute(path: '/social', builder: (ctx, _) => const SocialScreen()),
      GoRoute(path: '/profile', builder: (ctx, _) => const ProfileScreen()),
      GoRoute(path: '/order-confirm', builder: (ctx, _) => const OrderConfirmScreen()),
      GoRoute(path: '/teacher', builder: (ctx, _) => const TeacherScreen()),
      GoRoute(path: '/wallet', builder: (ctx, _) => const WalletScreen()),
      GoRoute(path: '/news', builder: (ctx, _) => const NewsScreen()),
      GoRoute(path: '/friends', builder: (ctx, _) => const FriendsScreen()),
      GoRoute(
        path: '/battle_lobby',
        builder: (ctx, s) => BattleLobbyScreen(opponent: s.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: '/mock-test/:id',
        builder: (ctx, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return MockTestScreen(
            testId: s.pathParameters['id']!,
            testInfo: extra?['testInfo'] as Map<String, dynamic>?,
            battleId: extra?['battleId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/mock-test-result',
        builder: (ctx, s) {
          final extra = s.extra as Map<String, dynamic>?;
          if (extra == null) return const DashboardScreen(); // Fallback for refresh for now
          return MockTestResultScreen(
            testInfo: extra['testInfo'] as Map<String, dynamic>,
            score: extra['score'] as int,
            userAnswers: extra['userAnswers'] as Map<int, int>,
            timeTakenSeconds: extra['timeTakenSeconds'] as int,
          );
        },
      ),
      GoRoute(path: '/client-access-blocked', builder: (ctx, _) => const ClientAccessBlockedScreen()),
    ],
  );
}
