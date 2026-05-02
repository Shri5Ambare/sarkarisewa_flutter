// lib/widgets/admin/cohort_chart.dart
//
// Phase 2.3 — Cohort retention heatmap.
// Reads `cohort_retention` docs (keyed YYYY-Wnn).
// Each doc: { cohortSize, retentionW1…W8 }
// Renders a scrollable table with heatmap cell coloring.
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class CohortRetentionChart extends StatefulWidget {
  const CohortRetentionChart({super.key});

  @override
  State<CohortRetentionChart> createState() => _CohortRetentionChartState();
}

class _CohortRetentionChartState extends State<CohortRetentionChart> {
  final _db = FirestoreService();
  int _weeks = 8;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
            child: Text(
              '🔄 Cohort Retention',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 4, label: Text('4w')),
              ButtonSegment(value: 8, label: Text('8w')),
              ButtonSegment(value: 12, label: Text('12w')),
            ],
            selected: {_weeks},
            onSelectionChanged: (s) => setState(() => _weeks = s.first),
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
          '% of cohort still active in week N after joining',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _db.getCohortRetention(weeks: _weeks),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (snap.hasError) {
              return _err(snap.error.toString());
            }
            final cohorts = snap.data ?? [];
            if (cohorts.isEmpty) return const _EmptyState();

            final maxRetentionWeeks =
                cohorts.fold<int>(0, (m, c) {
              for (var i = 1; i <= 12; i++) {
                if (c['retentionW$i'] != null) m = m < i ? i : m;
              }
              return m;
            });
            final cols = maxRetentionWeeks.clamp(1, 8);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderRow(cols: cols),
                  ...cohorts.map((c) => _CohortRow(cohort: c, cols: cols)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _Legend(),
      ],
    );
  }

  Widget _err(String e) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ruby.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.ruby.withAlpha(60)),
        ),
        child: Text('Failed to load: $e',
            style: const TextStyle(color: AppColors.ruby, fontSize: 12)),
      );
}

class _HeaderRow extends StatelessWidget {
  final int cols;
  const _HeaderRow({required this.cols});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Cell('Cohort', isHeader: true, width: 80),
      _Cell('Size', isHeader: true, width: 52),
      for (var i = 1; i <= cols; i++) _Cell('W$i', isHeader: true),
    ]);
  }
}

class _CohortRow extends StatelessWidget {
  final Map<String, dynamic> cohort;
  final int cols;
  const _CohortRow({required this.cohort, required this.cols});

  @override
  Widget build(BuildContext context) {
    final size = (cohort['cohortSize'] as num? ?? 0).toInt();
    return Row(children: [
      _Cell(cohort['id'] as String? ?? '', width: 80,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      _Cell('$size', width: 52,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      for (var i = 1; i <= cols; i++) () {
        final raw = cohort['retentionW$i'];
        if (raw == null) return const _Cell('—');
        final pct = (raw as num).toDouble();
        return _HeatCell(pct: pct);
      }(),
    ]);
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final double width;
  final TextStyle? style;
  const _Cell(this.text,
      {this.isHeader = false, this.width = 48, this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
        color: isHeader ? AppColors.navyLight : null,
      ),
      child: Text(
        text,
        style: style ??
            TextStyle(
              fontSize: 11,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
              color: isHeader ? AppColors.textSecondary : AppColors.textPrimary,
            ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final double pct;
  const _HeatCell({required this.pct});

  Color _color() {
    if (pct >= 80) return AppColors.emerald;
    if (pct >= 60) return const Color(0xFF34D399);
    if (pct >= 40) return AppColors.gold;
    if (pct >= 20) return const Color(0xFFFB923C);
    return AppColors.ruby;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      width: 48,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withAlpha(50),
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}%',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, children: const [
      _LegendDot(color: AppColors.emerald, label: '≥80%'),
      _LegendDot(color: Color(0xFF34D399), label: '60–79%'),
      _LegendDot(color: AppColors.gold, label: '40–59%'),
      _LegendDot(color: Color(0xFFFB923C), label: '20–39%'),
      _LegendDot(color: AppColors.ruby, label: '<20%'),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔄', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text(
                'No cohort data yet',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Populated by the computeCohortRetention Cloud Function.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
