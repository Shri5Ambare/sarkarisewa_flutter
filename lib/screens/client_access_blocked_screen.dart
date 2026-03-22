import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';

class ClientAccessBlockedScreen extends StatelessWidget {
  const ClientAccessBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access limited')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.saffron, AppColors.violet]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.violet.withAlpha(60), blurRadius: 16, spreadRadius: 2)],
                  ),
                  child: const Center(child: Icon(Icons.gps_fixed, color: Colors.white, size: 36)),
                ),
                const SizedBox(height: 12),
                const Text('SarkariSewa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                const Icon(Icons.admin_panel_settings_rounded, size: 48, color: AppColors.saffron),
                const SizedBox(height: 16),
                Text(
                  'Admin accounts are only allowed in the Admin Web App.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please open the dedicated admin web app to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
