// lib/widgets/course_card.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import 'tier_badge.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool enrolled;
  final VoidCallback onTap;

  const CourseCard({super.key, required this.course, required this.enrolled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(course['color'] ?? '#FF6B35');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Left accent stripe
            Container(
              width: 5,
              height: 110,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Emoji icon (uses course data with fallback)
            Hero(
              tag: 'course_icon_${course['id']}',
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    (course['emoji']?.toString().isNotEmpty ?? false) ? course['emoji'] : '📚',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course['subtitle'] ?? '',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TierBadge(tier: course['tier'] ?? 'free'),
                        const SizedBox(width: 8),
                        if (enrolled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withAlpha(31),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text('✓ Enrolled', style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        const Spacer(),
                        Text(
                          'Rs. ${course['price'] ?? 0}',
                          style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.saffron;
    }
  }
}
