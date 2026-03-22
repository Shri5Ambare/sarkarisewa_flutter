// lib/screens/mock_test_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/badge_dialog.dart';
import '../widgets/app_button.dart';
import '../services/location_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class MockTestScreen extends StatefulWidget {
  final Map<String, dynamic>? testInfo;
  final String testId;
  final String? battleId;
  const MockTestScreen({super.key, this.testInfo, required this.testId, this.battleId});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  final _db = FirestoreService();
  Map<String, dynamic>? _testData;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _timeRemaining = 0; // in seconds
  Timer? _timer;
  final Map<int, int> _selectedAnswers = {}; // questionIndex -> selectedOptionIndex

  bool _loading = true;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.testInfo != null) {
        _testData = widget.testInfo;
      } else {
        _testData = await _db.getMockTestById(widget.testId);
      }

      if (_testData == null) {
        if (mounted) setState(() { _error = 'Test not found.'; _loading = false; });
        return;
      }

      _questions = _testData!['questions'] ?? [];
      int durationMins = _testData!['durationMinutes'] ?? 30;
      _timeRemaining = durationMins * 60;
      
      if (mounted) {
        setState(() => _loading = false);
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load test. Please check connection.'; _loading = false; });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeRemaining > 0) {
        setState(() => _timeRemaining--);
        // Haptic pulse when under 1 minute
        if (_timeRemaining == 60) HapticFeedback.mediumImpact();
        if (_timeRemaining <= 10 && _timeRemaining > 0) HapticFeedback.lightImpact();
      } else {
        _timer?.cancel();
        _submitTest();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submitTest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      int correctIndex = _questions[i]['correctOptionIndex'] ?? 0;
      if (_selectedAnswers[i] == correctIndex) {
        score++;
      }
    }

    try {
      final uiUid = context.read<AuthProvider>().user?.uid;
      if (uiUid != null && _testData != null) {
        final db = FirestoreService();
        if (widget.battleId != null) {
          await db.submitBattleScore(widget.battleId!, uiUid, score);
        } else {
          final loc = await LocationService.getCurrentLocation();
          await db.submitTestResult(uiUid, _testData!['id'], _testData!['courseId'], score, _questions.length, location: loc);
        }
      }
      
      if (_testData != null) {
        await FirebaseAnalytics.instance.logEvent(
          name: 'test_completed',
          parameters: {
            'test_id': _testData!['id'],
            'course_id': _testData!['courseId'],
            'score': score,
            'total_questions': _questions.length,
            'time_taken_seconds': (_testData!['durationMinutes']! * 60) - _timeRemaining,
          },
        );
      }
      
      if (mounted && _testData != null) {
        // Award badge BEFORE navigating so dialog context is still valid
        final bUid = context.read<AuthProvider>().user?.uid ?? '';
        final db = FirestoreService();
        final newBadge = await db.checkAndAwardBadge(bUid, 'first_test');
        if (newBadge != null && mounted) {
           BadgeUnlockDialog.show(context, newBadge);
        }
        if (!mounted) return;
        context.pushReplacement('/mock-test-result', extra: {
          'testInfo': _testData!,
          'score': score,
          'userAnswers': _selectedAnswers,
          'timeTakenSeconds': (_testData!['durationMinutes']! * 60) - _timeRemaining,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving result: $e'), behavior: SnackBarBehavior.floating));
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _confirmSubmit() {
    final unanswered = _questions.length - _selectedAnswers.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        title: const Text('Submit Test?', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to finish and submit your answers?', style: TextStyle(color: AppColors.textMuted)),
            if (unanswered > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(31),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$unanswered question${unanswered > 1 ? 's' : ''} unanswered',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          AppButton(label: 'Submit', onPressed: () { Navigator.pop(ctx); _submitTest(); }),
        ],
      )
    );
  }

  String get _fmtTime {
    int m = _timeRemaining ~/ 60;
    int s = _timeRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.saffron)));
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mock Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❌', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.ruby)),
              const SizedBox(height: 20),
              AppButton(label: 'Back to Dashboard', onPressed: () => context.go('/dashboard'), style: AppButtonStyle.outline),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_testData?['title'] ?? 'Mock Test')),
        body: const Center(child: Text('No questions found for this test.')),
      );
    }

    final currentQ = _questions[_currentIndex];
    final options = List<String>.from(currentQ['options'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(_testData?['title'] ?? 'Mock Test'),
        automaticallyImplyLeading: false, // Prevent accidental back navigation
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _timeRemaining < 60 ? AppColors.ruby.withAlpha(51) : AppColors.emerald.withAlpha(51),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _timeRemaining < 60 ? AppColors.ruby : AppColors.emerald),
              ),
              child: Text(
                '⏱ $_fmtTime',
                style: TextStyle(
                  color: _timeRemaining < 60 ? AppColors.ruby : AppColors.emerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          )
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: AppColors.saffron))
          : Column(
              children: [
                // Progress Bar
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  backgroundColor: AppColors.cardBg,
                  color: AppColors.saffron,
                  minHeight: 4,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      ),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(_currentIndex),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question dot indicators
                          SizedBox(
                            height: 22,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _questions.length,
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () => setState(() => _currentIndex = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 5),
                                  width: i == _currentIndex ? 22 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _selectedAnswers.containsKey(i)
                                        ? AppColors.emerald
                                        : (i == _currentIndex ? AppColors.saffron : AppColors.border),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Question ${_currentIndex + 1} of ${_questions.length}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentQ['questionText'] ?? '',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, height: 1.4, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 32),
                          ...List.generate(options.length, (optIdx) {
                            bool isSelected = _selectedAnswers[_currentIndex] == optIdx;
                            return _OptionTile(
                              text: options[optIdx],
                              isSelected: isSelected,
                              optIndex: optIdx,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedAnswers[_currentIndex] = optIdx);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bottom Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.navyMid,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        if (_currentIndex > 0)
                          Expanded(
                            child: AppButton(
                              label: 'Previous',
                              onPressed: () => setState(() => _currentIndex--),
                              style: AppButtonStyle.outline,
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 16),
                        if (_currentIndex < _questions.length - 1)
                          Expanded(
                            child: AppButton(
                              label: 'Next',
                              onPressed: () => setState(() => _currentIndex++),
                            ),
                          )
                        else
                          Expanded(
                            child: AppButton(
                              label: 'Submit',
                              onPressed: _confirmSubmit,
                              style: AppButtonStyle.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Animated answer option ────────────────────────────────────────────────────
class _OptionTile extends StatefulWidget {
  final String text;
  final bool isSelected;
  final int optIndex;
  final VoidCallback onTap;
  const _OptionTile({required this.text, required this.isSelected, required this.optIndex, required this.onTap});
  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  static const _letters = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.saffron.withAlpha(28) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected ? AppColors.saffron : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: AppColors.saffron.withAlpha(40), blurRadius: 10, offset: const Offset(0, 3))]
                : [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected ? AppColors.saffron : AppColors.navyLight,
                  border: Border.all(color: widget.isSelected ? AppColors.saffron : AppColors.border),
                ),
                child: Center(
                  child: widget.isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          widget.optIndex < _letters.length ? _letters[widget.optIndex] : '${widget.optIndex + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
