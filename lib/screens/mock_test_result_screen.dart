import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets/app_button.dart';

class MockTestResultScreen extends StatelessWidget {
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

  String get _fmtTakenTime {
    int m = timeTakenSeconds ~/ 60;
    int s = timeTakenSeconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final questions = testInfo['questions'] as List<dynamic>? ?? [];
    final total = questions.length;
    final double percentage = total == 0 ? 0 : (score / total);
    final bool passed = percentage >= 0.4; // e.g. 40% pass mark

    return Scaffold(
      appBar: AppBar(title: Text(testInfo['title'] ?? 'Test Result'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Hero Result Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: passed 
                      ? [AppColors.emerald.withAlpha(51), AppColors.emerald.withAlpha(12)]
                      : [AppColors.ruby.withAlpha(51), AppColors.ruby.withAlpha(12)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: passed ? AppColors.emerald.withAlpha(128) : AppColors.ruby.withAlpha(128)),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (passed)
                        SizedBox(
                          width: 150, height: 150,
                          child: Lottie.network('https://assets2.lottiefiles.com/packages/lf20_touohxv0.json', repeat: false),
                        )
                      else
                        SizedBox(
                          width: 120, height: 120,
                          child: CircularProgressIndicator(
                            value: percentage,
                            backgroundColor: AppColors.ruby.withAlpha(51),
                            color: AppColors.ruby,
                            strokeWidth: 12,
                          ),
                        ),
                      if (!passed)
                        Text('$score', style: const TextStyle(color: AppColors.ruby, fontSize: 40, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(passed ? 'Congratulations!' : 'Keep Practicing!', style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('You scored $score out of $total marks.', style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatCol(icon: Icons.timer, label: 'Time', value: _fmtTakenTime),
                      _StatCol(icon: Icons.check_circle, label: 'Correct', value: '$score', color: AppColors.emerald),
                      _StatCol(icon: Icons.cancel, label: 'Incorrect', value: '${total - score}', color: AppColors.ruby),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Align(alignment: Alignment.centerLeft, child: Text('Detailed Review', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),

            // Review List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (ctx, i) {
                final q = questions[i];
                final options = List<String>.from(q['options'] ?? []);
                final correctIdx = q['correctOptionIndex'] ?? 0;
                final userIdx = userAnswers[i];
                final isCorrect = userIdx == correctIdx;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? AppColors.emerald : AppColors.ruby, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Q${i+1}. ${q['questionText']}',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(options.length, (optIdx) {
                        bool isUserChoice = userIdx == optIdx;
                        bool isRightChoice = correctIdx == optIdx;

                        Color bg = Colors.transparent;
                        Color textC = AppColors.textMuted;
                        Color borderC = Colors.transparent;
                        IconData? icon;
                        Color iconC = Colors.transparent;

                        if (isRightChoice) {
                          bg = AppColors.emerald.withAlpha(26);
                          textC = AppColors.emerald;
                          borderC = AppColors.emerald;
                          icon = Icons.check;
                          iconC = AppColors.emerald;
                        } else if (isUserChoice && !isRightChoice) {
                          bg = AppColors.ruby.withAlpha(26);
                          textC = AppColors.ruby;
                          borderC = AppColors.ruby;
                          icon = Icons.close;
                          iconC = AppColors.ruby;
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
                              Text('${String.fromCharCode(65 + optIdx)}.', style: TextStyle(color: textC, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Expanded(child: Text(options[optIdx], style: TextStyle(color: textC))),
                              if (icon != null) Icon(icon, size: 16, color: iconC),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            AppButton(
              label: 'Back to Home',
              onPressed: () {
                context.go('/dashboard');
              },
              fullWidth: true,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCol({required this.icon, required this.label, required this.value, this.color = AppColors.saffron});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
