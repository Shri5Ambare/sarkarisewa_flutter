// lib/widgets/admin/live_ops_card.dart
//
// Drop-in card for the admin Dashboard that shows live counts of
// in-flight operations (active battles / pending payments / today's
// signups / today's tests). Refreshes every 30 seconds via a
// `Timer.periodic` so admins watching the dashboard see the pulse of
// the system without re-loading.
//
// All queries are .count().get() — Firestore returns just the count,
// not the documents, so this is cheap (1 unit per query per refresh).
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';

class LiveOpsCard extends StatefulWidget {
  const LiveOpsCard({super.key});

  @override
  State<LiveOpsCard> createState() => _LiveOpsCardState();
}

class _LiveOpsCardState extends State<LiveOpsCard> {
  final _db = FirebaseFirestore.instance;
  Timer? _timer;

  int? _activeBattles;
  int? _pendingPayments;
  int? _signupsToday;
  int? _testsToday;
  bool _initialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    final localMidnight = DateTime(now.year, now.month, now.day);
    final ts = Timestamp.fromDate(localMidnight);

    try {
      final results = await Future.wait([
        _db.collection('battles')
            .where('status', isEqualTo: 'active')
            .count().get(),
        _db.collection('payment_requests')
            .where('status', isEqualTo: 'pending')
            .count().get(),
        _db.collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: ts)
            .count().get(),
        _db.collection('mock_test_results')
            .where('completedAt', isGreaterThanOrEqualTo: ts)
            .count().get(),
      ]);
      if (!mounted) return;
      setState(() {
        _activeBattles    = results[0].count ?? 0;
        _pendingPayments  = results[1].count ?? 0;
        _signupsToday     = results[2].count ?? 0;
        _testsToday       = results[3].count ?? 0;
        _initialLoad = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initialLoad = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.x5),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE OPS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh now',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18,
                    color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Failed to load live counts.',
                style: TextStyle(color: AppColors.ruby.withAlpha(220), fontSize: 13),
              ),
            )
          else if (_initialLoad)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2,
              )),
            )
          else
            Wrap(
              spacing: 16, runSpacing: 14,
              children: [
                _LiveStat(
                  emoji: '⚔️',
                  label: 'Active battles',
                  value: _activeBattles!,
                  color: AppColors.violet,
                ),
                _LiveStat(
                  emoji: '💳',
                  label: 'Pending payments',
                  value: _pendingPayments!,
                  color: AppColors.gold,
                  warnAbove: 0,
                ),
                _LiveStat(
                  emoji: '🎉',
                  label: 'Signups today',
                  value: _signupsToday!,
                  color: AppColors.emerald,
                ),
                _LiveStat(
                  emoji: '📝',
                  label: 'Tests today',
                  value: _testsToday!,
                  color: AppColors.sky,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color color;
  final int? warnAbove;
  const _LiveStat({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.warnAbove,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = warnAbove != null && value > warnAbove!;
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? color.withAlpha(31) : AppColors.navyLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: highlight ? color.withAlpha(80) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: highlight ? color : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
