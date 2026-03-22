// lib/widgets/tier_badge.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class TierBadge extends StatelessWidget {
  final String tier;
  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'gold'   => ('🥇 Gold', AppColors.gold),
      'silver' => ('🥈 Silver', AppColors.sky),
      _        => ('🆓 Free', AppColors.emerald),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
