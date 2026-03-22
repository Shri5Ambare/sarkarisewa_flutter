import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';

GoRouter buildAdminRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authProvider,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      final isLoggedIn = authProvider.isLoggedIn;
      final isLoading = authProvider.loading;
      final role = authProvider.role;
      final path = state.uri.path;

      if (isLoading) return null;

      if (!isLoggedIn) {
        return path == '/login' ? null : '/login';
      }

      if (role != 'admin' && role != 'super_admin') {
        return '/unauthorized';
      }

      if (path == '/login' || path == '/' || path == '/unauthorized') {
        return '/admin';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (ctx, _) => const AdminScreen()),
      GoRoute(
        path: '/unauthorized',
        builder: (ctx, _) => Scaffold(
          appBar: AppBar(title: const Text('Access denied')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This app is only for admin accounts.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => authProvider.signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
