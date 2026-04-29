import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../services/firestore_service.dart';

class MockTestResultScreen extends StatefulWidget {
  final Map<String, dynamic> testInfo;
  final int score;
  final Map<int, int> userAnswers;
  final int timeTakenSeconds;

  const MockTestResultScreen({
    super.key,
    required this.testInfo,
    required this.score,
    required this.userAnswers,
    required this.timeTakenSeconds,
  });

  @override
  State<MockTestResultScreen> createState() => _MockTestResultScreenState();
}

class _MockTestResultScreenState extends State<MockTestResultScreen> {
  final _db = FirestoreService();
  final _reviewKey = GlobalKey();

  ({int rank, int total, int percentile})? _rank;
  bool _rankLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRank();
  }

  Future<void> _loadRank() async {
    final id = widget.testInfo['id']?.toString();
    if (id == null) {
      setState(() => _rankLoaded = true);
      return;
    }
    try {
      final r = await _db.getMockTestRank(id, widget.score);
      if (mounted) setState(() { _rank = r; _rankLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _rankLoaded = true);
    }
  }

  String _fmtTime(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m}m ${r.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.testInfo['questions'] as List<dynamic>? ?? [];
    final total = questions.length;
    final score = widget.score;
    final pct = total == 0 ? 0.0 : score / total;
    final passed = pct >= 0.4;
    final wrong = total - score;
    final avgPerQ = total == 0 ? 0 : (widget.timeTakenSeconds / total).round();

    // Build per-question status: 0=correct, 1=wrong, 2=skipped
    final statuses = List<int>.generate(total, (i) {
      final ans = widget.userAnswers[i];
      if (ans == null) return 2;
      final correct = (questions[i] as Map)['correctOptionIndex'];
      return ans == correct ? 0 : 1;
    });

    // Topic breakdown — only if any question has non-empty topic.
    final topicBreakdown = _topicBreakdown(questions, statuses);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testInfo['title'] ?? 'Test Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HeroCard(
              score: score,
              total: total,
              passed: passed,
              percentage: pct,
            ),
            const SizedBox(height: 16),
            _StatsRow(
              timeTaken: _fmtTime(widget.timeTakenSeconds),
              avgPerQ: _fmtTime(avgPerQ),
              correct: score,
              wrong: wrong,
              skipped: statuses.where((s) => s == 2).length,
            ),
            const SizedBox(height: 16),
            _QuestionStrip(
              statuses: statuses,
              onTap: (i) {
                final ctx = _reviewKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    alignment: 0.05,
                  );
                }
              },
            ),
            if (topicBreakdown.isNotEmpty) ...[
              const SizedBox(height: 20),
              _TopicBreakdown(rows: topicBreakdown),
            ],
            if (_rankLoaded && _rank != null) ...[
              const SizedBox(height: 16),
              _RankCard(rank: _rank!),
            ],
            const SizedBox(height: 24),
            Padding(
              key: _reviewKey,
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detailed Review',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (ctx, i) => _QuestionReviewCard(
                index: i,
                question: questions[i] as Map<String, dynamic>,
                userAnswer: widget.userAnswers[i],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Back to Home',
              onPressed: () => context.go('/dashboard'),
              fullWidth: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<_TopicRow> _topicBreakdown(List questions, List<int> statuses) {
    final byTopic = <String, _TopicAccum>{};
    var any = false;
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i] as Map;
      final topic = (q['topic'] ?? '').toString().trim();
      if (topic.isEmpty) continue;
      any = true;
      final acc = byTopic.putIfAbsent(topic, _TopicAccum.new);
      acc.total += 1;
      if (statuses[i] == 0) acc.correct += 1;
    }
    if (!any) return const [];
    final rows = byTopic.entries
        .map((e) => _TopicRow(topic: e.key, correct: e.value.correct, total: e.value.total))
        .toList()
      ..sort((a, b) => (a.correct / a.total).compareTo(b.correct / b.total));
    return rows;
  }
}

class _TopicAccum {
  int correct = 0;
  int total = 0;
}

class _TopicRow {
  final String topic;
  final int correct;
  final int total;
  const _TopicRow({required this.topic, required this.correct, required this.total});
  double get pct => total == 0 ? 0 : correct / total;
}

// ── Hero card with accuracy ring ────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final int score;
  final int total;
  final bool passed;
  final double percentage;

  const _HeroCard({
    required this.score,
    required this.total,
    required this.passed,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final accent = passed ? AppColors.emerald : AppColors.ruby;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: passed
              ? [AppColors.saffronDark, AppColors.violet]
              : [AppColors.ruby, AppColors.saffronDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: accent.withAlpha(50), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _AccuracyRingPainter(percentage: percentage),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(percentage * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$score / $total',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            passed ? 'Great job!' : 'Keep practicing',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            passed
                ? 'You cleared the pass mark.'
                : 'A 40% pass mark gets you across the line.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRingPainter extends CustomPainter {
  final double percentage;
  _AccuracyRingPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = Colors.white.withAlpha(60);
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    canvas.drawCircle(center, radius, track);
    final sweep = (percentage.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter old) => old.percentage != percentage;
}

// ── Stats row (5 metrics) ───────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String timeTaken;
  final String avgPerQ;
  final int correct;
  final int wrong;
  final int skipped;

  const _StatsRow({
    required this.timeTaken,
    required this.avgPerQ,
    required this.correct,
    required this.wrong,
    required this.skipped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(icon: Icons.timer_outlined, label: 'Total time', value: timeTaken, color: AppColors.saffron)),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(icon: Icons.av_timer, label: 'Avg / Q', value: avgPerQ, color: AppColors.violet)),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(icon: Icons.check_circle_outline, label: 'Correct', value: '$correct', color: AppColors.emerald)),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(icon: Icons.cancel_outlined, label: 'Wrong', value: '$wrong', color: AppColors.ruby)),
        if (skipped > 0) ...[
          const SizedBox(width: 8),
          Expanded(child: _StatTile(icon: Icons.remove_circle_outline, label: 'Skipped', value: '$skipped', color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Question status strip ───────────────────────────────────────────────────
class _QuestionStrip extends StatelessWidget {
  final List<int> statuses;
  final ValueChanged<int> onTap;
  const _QuestionStrip({required this.statuses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Question map',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = statuses[i];
                final color = s == 0
                    ? AppColors.emerald
                    : s == 1
                        ? AppColors.ruby
                        : AppColors.textMuted;
                return GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    width: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withAlpha(28),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color),
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _LegendDot(color: AppColors.emerald, label: 'Correct'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.ruby, label: 'Wrong'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.textMuted, label: 'Skipped'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Topic breakdown bars ────────────────────────────────────────────────────
class _TopicBreakdown extends StatelessWidget {
  final List<_TopicRow> rows;
  const _TopicBreakdown({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weak topics first',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            _TopicBar(row: r),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TopicBar extends StatelessWidget {
  final _TopicRow row;
  const _TopicBar({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = row.pct;
    final barColor = pct < 0.4
        ? AppColors.ruby
        : pct < 0.7
            ? AppColors.gold
            : AppColors.emerald;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(row.topic,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text('${row.correct}/${row.total}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.navyLight,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ── Rank/percentile card ────────────────────────────────────────────────────
class _RankCard extends StatelessWidget {
  final ({int rank, int total, int percentile}) rank;
  const _RankCard({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gold, AppColors.saffron]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top ${100 - rank.percentile}% of test takers',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Rank ${rank.rank} of ${rank.total}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-question review card ────────────────────────────────────────────────
class _QuestionReviewCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> question;
  final int? userAnswer;

  const _QuestionReviewCard({
    required this.index,
    required this.question,
    required this.userAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(question['options'] ?? []);
    final correctIdx = (question['correctOptionIndex'] ?? 0) as int;
    final isCorrect = userAnswer == correctIdx;
    final isSkipped = userAnswer == null;
    final headerColor = isSkipped
        ? AppColors.textMuted
        : isCorrect
            ? AppColors.emerald
            : AppColors.ruby;
    final headerIcon = isSkipped
        ? Icons.remove_circle_outline
        : isCorrect
            ? Icons.check_circle
            : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(headerIcon, color: headerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q${index + 1}. ${question['questionText'] ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++)
            _ReviewOption(
              letter: String.fromCharCode(65 + i),
              text: options[i],
              isCorrect: i == correctIdx,
              isUserPick: userAnswer == i,
            ),
        ],
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final bool isUserPick;

  const _ReviewOption({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isUserPick,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color textC = AppColors.textSecondary;
    Color borderC = AppColors.border;
    IconData? trailing;

    if (isCorrect) {
      bg = AppColors.emerald.withAlpha(26);
      textC = AppColors.emerald;
      borderC = AppColors.emerald;
      trailing = Icons.check;
    } else if (isUserPick) {
      bg = AppColors.ruby.withAlpha(26);
      textC = AppColors.ruby;
      borderC = AppColors.ruby;
      trailing = Icons.close;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderC),
      ),
      child: Row(
        children: [
          Text('$letter.', style: TextStyle(color: textC, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: textC))),
          if (trailing != null) Icon(trailing, size: 16, color: textC),
        ],
      ),
    );
  }
}
