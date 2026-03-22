// lib/screens/order_confirm_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';

class OrderConfirmScreen extends StatelessWidget {
  const OrderConfirmScreen({super.key});

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
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withAlpha(31),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.emerald.withAlpha(77), width: 2),
                  ),
                  child: const Center(child: Text('🎉', style: TextStyle(fontSize: 50))),
                ),
                const SizedBox(height: 24),
                Text(t('order.title', lang), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.emerald.withAlpha(64)),
                  ),
                  child: Text(t('order.message', lang), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: t('order.back', lang),
                  onPressed: () => context.go('/dashboard'),
                  fullWidth: true,
                  icon: Icons.home_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
