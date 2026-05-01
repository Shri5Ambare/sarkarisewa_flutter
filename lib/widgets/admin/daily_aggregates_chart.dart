// lib/widgets/admin/daily_aggregates_chart.dart
//
// 30-day analytics chart card for the admin Trends tab. Reads from the
// `daily_aggregates` collection (populated by the
// `computeDailyAggregates` Cloud Function). All chart data for a 30-day
// window costs <=30 doc reads — no scanning the transactions or users
// collections at view time.
//
// Two visualizations:
//   1. DAU + signups — twin-line chart
//   2. Revenue (Rs) — bar chart
//
// User can switch the time window: 7d / 30d / 90d.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';

enum _Window { d7, d30, d90 }

class DailyAggregatesChart extends StatefulWidget {
  const DailyAggregatesChart({super.key});

  @override
  State<DailyAggregatesChart> createState() => _DailyAggregatesChartState();
}

class _DailyAggregatesChartState extends State<DailyAggregatesChart> {
  _Window _window = _Window.d30;
  final _db = FirebaseFirestore.instance;

  int get _days => switch (_window) {
        _Window.d7 => 7,
        _Window.d30 => 30,
        _Window.d90 => 90,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Window switcher ────────────────────────────────────────
        SegmentedButton<_Window>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: _Window.d7,  label: Text('7 days')),
            ButtonSegment(value: _Window.d30, label: Text('30 days')),
            ButtonSegment(value: _Window.d90, label: Text('90 days')),
          ],
          selected: {_window},
          onSelectionChanged: (s) => setState(() => _window = s.first),
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchAggregates(_days),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 240,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (snap.hasError) {
              return _ErrorBlock(error: snap.error.toString());
            }
            final aggs = snap.data ?? const [];
            if (aggs.isEmpty) {
              return const _EmptyBlock();
            }

            return Column(
              children: [
                _SummaryStrip(aggs: aggs),
                const SizedBox(height: 18),
                _ChartCard(
                  title: 'Activity — DAU & signups',
                  child: SizedBox(
                    height: 220,
                    child: _DauChart(aggs: aggs),
                  ),
                ),
                const SizedBox(height: 14),
                _ChartCard(
                  title: 'Revenue (Rs)',
                  child: SizedBox(
                    height: 200,
                    child: _RevenueChart(aggs: aggs),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Pull the last `days` aggregates. The doc id is `YYYY-MM-DD` so a
  /// reverse-orderBy + limit is the cheapest way; we sort ascending in
  /// memory before charting.
  Future<List<Map<String, dynamic>>> _fetchAggregates(int days) async {
    final snap = await _db.collection('daily_aggregates')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return list;
  }
}

// ── Summary strip — totals across the window ────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final List<Map<String, dynamic>> aggs;
  const _SummaryStrip({required this.aggs});

  int _sumInt(String key) =>
      aggs.fold(0, (acc, d) => acc + (d[key] as num? ?? 0).toInt());

  @override
  Widget build(BuildContext context) {
    final dauAvg = aggs.isEmpty ? 0 : _sumInt('dau') ~/ aggs.length;
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        _Tile('Avg DAU',       '$dauAvg',                  AppColors.violet),
        _Tile('New signups',   '${_sumInt('signups')}',    AppColors.emerald),
        _Tile('Revenue (Rs)',  '${_sumInt('coinTopupRs')}', AppColors.gold),
        _Tile('Tests taken',   '${_sumInt('testsTaken')}',  AppColors.sky),
        _Tile('Battles',       '${_sumInt('battlesPlayed')}', AppColors.primary),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Tile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              )),
        ],
      ),
    );
  }
}

// ── Card frame ─────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── DAU + Signups (twin-line) ──────────────────────────────────────────
class _DauChart extends StatelessWidget {
  final List<Map<String, dynamic>> aggs;
  const _DauChart({required this.aggs});

  @override
  Widget build(BuildContext context) {
    final dauSpots = <FlSpot>[];
    final signupSpots = <FlSpot>[];
    for (var i = 0; i < aggs.length; i++) {
      dauSpots.add(FlSpot(i.toDouble(), (aggs[i]['dau']     as num? ?? 0).toDouble()));
      signupSpots.add(FlSpot(i.toDouble(), (aggs[i]['signups'] as num? ?? 0).toDouble()));
    }

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.border, strokeWidth: 1, dashArray: [4, 4],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 32,
          getTitlesWidget: (v, _) => Text(
            v.toInt().toString(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          interval: (aggs.length / 6).ceilToDouble().clamp(1, double.infinity),
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= aggs.length) return const SizedBox();
            final id = aggs[i]['id'] as String? ?? '';
            // show MM-DD only.
            final mmdd = id.length >= 10 ? id.substring(5) : id;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(mmdd,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            );
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: dauSpots,
          isCurved: true, barWidth: 2.5,
          color: AppColors.violet,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.violet.withAlpha(31),
          ),
        ),
        LineChartBarData(
          spots: signupSpots,
          isCurved: true, barWidth: 2.5,
          color: AppColors.emerald,
          dotData: const FlDotData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.textPrimary,
          getTooltipItems: (spots) => spots.map((s) {
            final isDau = s.barIndex == 0;
            return LineTooltipItem(
              '${isDau ? 'DAU' : 'Signups'}: ${s.y.toInt()}',
              const TextStyle(color: Colors.white, fontSize: 12),
            );
          }).toList(),
        ),
      ),
    ));
  }
}

// ── Revenue (bar) ──────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> aggs;
  const _RevenueChart({required this.aggs});

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[];
    double maxY = 0;
    for (var i = 0; i < aggs.length; i++) {
      final rs = (aggs[i]['coinTopupRs'] as num? ?? 0).toDouble();
      if (rs > maxY) maxY = rs;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: rs,
          color: AppColors.gold,
          width: 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ]));
    }

    return BarChart(BarChartData(
      maxY: (maxY * 1.15).clamp(10, double.infinity),
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.border, strokeWidth: 1, dashArray: [4, 4],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 40,
          getTitlesWidget: (v, _) => Text(
            v.toInt().toString(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          interval: (aggs.length / 6).ceilToDouble().clamp(1, double.infinity),
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= aggs.length) return const SizedBox();
            final id = aggs[i]['id'] as String? ?? '';
            final mmdd = id.length >= 10 ? id.substring(5) : id;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(mmdd,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            );
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      barGroups: groups,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.textPrimary,
          getTooltipItem: (g, _, r, _) => BarTooltipItem(
            'Rs ${r.toY.toInt()}',
            const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    ));
  }
}

// ── States ─────────────────────────────────────────────────────────────
class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();
  @override
  Widget build(BuildContext context) => Container(
    height: 200,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      border: Border.all(color: AppColors.border),
    ),
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📊', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text(
            "No aggregate data yet — the daily job hasn't run.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            'Stats appear after the first 00:30 NPT run.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBlock extends StatelessWidget {
  final String error;
  const _ErrorBlock({required this.error});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.ruby.withAlpha(20),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.ruby.withAlpha(80)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.ruby, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Failed to load aggregates: $error',
        style: const TextStyle(color: AppColors.ruby, fontSize: 13),
      )),
    ]),
  );
}
