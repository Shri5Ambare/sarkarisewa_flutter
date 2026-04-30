// lib/widgets/stat_pill.dart
//
// Compact icon + value + label pill used on hero cards and stat strips.
import 'package:flutter/material.dart';
import '../theme.dart';

class StatPill extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String value;
  final String label;
  final Color? color;
  final bool inverted; // true = light text on dark/colored bg

  const StatPill({
    super.key,
    this.icon,
    this.emoji,
    required this.value,
    required this.label,
    this.color,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = inverted ? Colors.white : (color ?? AppColors.textPrimary);
    final fgMuted = inverted ? Colors.white.withAlpha(180) : AppColors.textMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emoji != null)
          Text(emoji!, style: const TextStyle(fontSize: 20))
        else if (icon != null)
          Icon(icon, size: 20, color: fg),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: fg,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(color: fgMuted, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
