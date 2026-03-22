// lib/screens/not_found_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().lang;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(colors: [AppColors.saffron, AppColors.violet]).createShader(b),
                  child: const Text('404', style: TextStyle(fontSize: 96, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 12),
                Text(t('notfound.title', lang), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('The page you are looking for does not exist.', style: TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                AppButton(
                  label: t('notfound.btn', lang),
                  onPressed: () => context.go('/dashboard'),
                  fullWidth: true,
                  icon: Icons.home_outlined,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('← Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
