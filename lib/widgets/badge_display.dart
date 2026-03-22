import 'package:flutter/material.dart';
import '../theme.dart';

class BadgeDisplay extends StatelessWidget {
  final List<String> badges;
  final double size;

  const BadgeDisplay({super.key, required this.badges, this.size = 36});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const Text('No badges yet. Start learning to earn!', style: TextStyle(color: AppColors.textMuted, fontSize: 13));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: badges.map((b) => _buildBadgeItem(context, b)).toList(),
    );
  }

  Widget _buildBadgeItem(BuildContext context, String badgeId) {
    final (icon, color, tooltip) = switch (badgeId) {
      'scholar' => ('🎓', AppColors.sky, 'Scholar: Enrolled in first course'),
      'novice_tester' => ('📝', AppColors.emerald, 'Novice Tester: Passed first mock test'),
      'warrior' => ('⚔️', AppColors.ruby, 'Warrior: Competed in a Quiz Battle'),
      'supporter' => ('💎', AppColors.violet, 'Supporter: Purchased SS Coins'),
      _ => ('🌟', AppColors.gold, 'Mystery Achievement'),
    };

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(77), width: 1.5),
        ),
        child: Center(
          child: Text(icon, style: TextStyle(fontSize: size * 0.5)),
        ),
      ),
    );
  }
}
