// lib/widgets/lang_toggle.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';

/// Shared language toggle button used across all auth screens.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    return Center(
      child: TextButton.icon(
        onPressed: lp.toggle,
        icon: Text(lp.lang == 'en' ? '🇳🇵' : '🇬🇧'),
        label: Text(
          lp.lang == 'en' ? 'नेपालीमा हेर्नुहोस्' : 'Switch to English',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
