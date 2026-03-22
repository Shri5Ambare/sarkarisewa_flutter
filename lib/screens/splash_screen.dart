// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _requestNotificationPermissions();
    _maybeNavigate();
  }

  Future<void> _requestNotificationPermissions() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _maybeNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    // Wait for auth to resolve
    while (auth.loading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    final role = auth.role;
    if (!auth.isLoggedIn) {
      context.go('/login');
    } else if (role == 'teacher') {
      context.go('/teacher');
    } else {
      context.go('/dashboard');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: FadeTransition(
        opacity: _fade,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.saffron, AppColors.violet],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: AppColors.saffron.withAlpha(102), blurRadius: 32, spreadRadius: 4)],
                      ),
                      child: const Center(
                        child: Icon(Icons.school_rounded, color: AppColors.primary, size: 56),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [AppColors.saffron, AppColors.violet],
                      ).createShader(b),
                      child: Text(
                        'SarkariSewa',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.primary, fontSize: 38),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Nepal's #1 AI-Powered Exam Prep",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 32, height: 32,
                      child: CircularProgressIndicator(
                        color: AppColors.saffron, strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Made by SSITnexus',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.saffron,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Powered by SSITnexus  •  v1.0',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
