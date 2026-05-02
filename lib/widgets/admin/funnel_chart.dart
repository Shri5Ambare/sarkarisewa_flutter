// lib/widgets/admin/funnel_chart.dart
//
// Phase 2.4 — 4-step conversion funnel.
// Steps: Signup → First Course → First Test → First Battle
// Data from `funnel_stats` collection (written by computeDailyFunnel CF).
// Falls back to total user/order/test/battle counts as approximation.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class FunnelChart extends StatelessWidget {
  const FunnelChart({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();
    return FutureBuilder<Map<String, dynamic>>(
      future: db.getFunnelStats(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 240,
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        Map<String, dynamic> data = snap.data ?? {};

        // If no funnel_stats doc, fall back to counts
        if (data.isEmpty) {
          return _FunnelFallback();
        }

        final steps = [
          _FunnelStep(
            label: 'Signup',
            emoji: '🎉',
            count: (data['signups'] as num? ?? 0).toInt(),
            color: AppColors.primary,
          ),
          _FunnelStep(
            label: 'First Course',
            emoji: '📚',
            count: (data['firstCourse'] as num? ?? 0).toInt(),
            color: AppColors.sky,
          ),
          _FunnelStep(
            label: 'First Test',
            emoji: '📝',
            count: (data['firstTest'] as num? ?? 0).toInt(),
            color: AppColors.violet,
          ),
          _FunnelStep(
            label: 'First Battle',
            emoji: '⚔️',
            count: (data['firstBattle'] as num? ?? 0).toInt(),
            color: AppColors.gold,
          ),
        ];

        return _FunnelView(steps: steps);
      },
    );
  }
}

class _FunnelFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return FutureBuilder<List<AggregateQuerySnapshot>>(
      future: Future.wait([
        db.collection('users').count().get(),
        db.collection('orders').where('status', isEqualTo: 'active').count().get(),
        db.collection('mock_test_results').count().get(),
        db.collection('battles').count().get(),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 240,
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final counts = snap.data!.map((r) => r.count ?? 0).toList();
        final steps = [
          _FunnelStep(
              label: 'Signups',
              emoji: '🎉',
              count: counts[0],
              color: AppColors.primary),
          _FunnelStep(
              label: 'Enrollments',
              emoji: '📚',
              count: counts[1],
              color: AppColors.sky),
          _FunnelStep(
              label: 'Tests Taken',
              emoji: '📝',
              count: counts[2],
              color: AppColors.violet),
          _FunnelStep(
              label: 'Battles',
              emoji: '⚔️',
              count: counts[3],
              color: AppColors.gold),
        ];
        return Column(children: [
          _FunnelView(steps: steps),
          const SizedBox(height: 6),
          const Text(
            'Showing all-time totals. For per-cohort funnel, deploy computeDailyFunnel CF.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ]);
      },
    );
  }
}

class _FunnelStep {
  final String label;
  final String emoji;
  final int count;
  final Color color;
  const _FunnelStep(
      {required this.label,
      required this.emoji,
      required this.count,
      required this.color});
}

class _FunnelView extends StatelessWidget {
  final List<_FunnelStep> steps;
  const _FunnelView({required this.steps});

  @override
  Widget build(BuildContext context) {
    final top = steps.isNotEmpty ? steps.first.count : 1;
    final maxWidth = MediaQuery.of(context).size.width - 64;

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        final ratio =
            top > 0 ? (s.count / top).clamp(0.08, 1.0) : 0.08;
        final prevCount = i > 0 ? steps[i - 1].count : s.count;
        final dropPct = prevCount > 0
            ? ((1 - s.count / prevCount) * 100).round()
            : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${s.emoji} ${s.label}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                Text(
                  _fmt(s.count),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: s.color),
                ),
                if (i > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.ruby.withAlpha(20),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '-$dropPct%',
                      style: const TextStyle(
                          color: AppColors.ruby,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Stack(children: [
                Container(
                  height: 20,
                  width: maxWidth,
                  decoration: BoxDecoration(
                    color: AppColors.navyLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 20,
                  width: maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: s.color.withAlpha(200),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
