import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme.dart';

class BadgeUnlockDialog extends StatefulWidget {
  final String badgeId;
  const BadgeUnlockDialog({super.key, required this.badgeId});

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();

  static Future<void> show(BuildContext context, String badgeId) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BadgeUnlockDialog(badgeId: badgeId),
    );
  }
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 4 seconds — runs once, not on every rebuild
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.badgeId) {
      'scholar' => 'Scholar Badge',
      'novice_tester' => 'Novice Tester',
      'warrior' => 'Quiz Warrior',
      'supporter' => 'Top Supporter',
      _ => 'New Badge',
    };

    final message = switch (widget.badgeId) {
      'scholar' => 'You enrolled in your first course!',
      'novice_tester' => 'You completed your first Mock Test!',
      'warrior' => 'You joined your first Quiz Battle!',
      'supporter' => 'You purchased your first coin pack!',
      _ => 'You unlocked a new achievement.',
    };

    final icon = switch (widget.badgeId) {
      'scholar' => '🎓',
      'novice_tester' => '📝',
      'warrior' => '⚔️',
      'supporter' => '💎',
      _ => '🌟',
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.gold.withAlpha(51), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Use a network lottie or fallback icon if we don't carry the asset yet
              SizedBox(
                width: 150, height: 150,
                // Using a reliable public lottie for celebration
                child: Lottie.network(
                  'https://lottie.host/85a69022-b51f-4d98-b80c-07409c953a79/2L6q7sN2Cg.json', // generic trophy/confetti
                  repeat: false,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(icon, style: const TextStyle(fontSize: 80))),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Achievement Unlocked!', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
