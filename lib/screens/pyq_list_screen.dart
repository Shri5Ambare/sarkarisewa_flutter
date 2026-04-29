// lib/screens/pyq_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

class PyqListScreen extends StatefulWidget {
  const PyqListScreen({super.key});

  @override
  State<PyqListScreen> createState() => _PyqListScreenState();
}

class _PyqListScreenState extends State<PyqListScreen> {
  final _db = FirestoreService();
  String _exam = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Previous Year Questions')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.listenPyqs(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorState(message: 'Could not load PYQs.\n${snap.error}');
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
          }
          final all = snap.data ?? const <Map<String, dynamic>>[];
          if (all.isEmpty) return const _EmptyState();

          final exams = <String>{
            for (final p in all) (p['exam'] ?? '').toString().trim()
          }..removeWhere((e) => e.isEmpty);
          final examsList = ['All', ...exams.toList()..sort()];

          final filtered = _exam == 'All'
              ? all
              : all.where((p) => (p['exam'] ?? '') == _exam).toList();

          // Group by year (descending).
          final byYear = <int, List<Map<String, dynamic>>>{};
          for (final p in filtered) {
            final y = (p['year'] as num?)?.toInt() ?? 0;
            byYear.putIfAbsent(y, () => []).add(p);
          }
          final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: examsList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final ex = examsList[i];
                        final selected = ex == _exam;
                        return ChoiceChip(
                          label: Text(ex,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : AppColors.textSecondary,
                              )),
                          selected: selected,
                          selectedColor: AppColors.saffron,
                          backgroundColor: AppColors.navyLight,
                          side: BorderSide(color: selected ? AppColors.saffron : AppColors.border),
                          onSelected: (_) => setState(() => _exam = ex),
                        );
                      },
                    ),
                  ),
                ),
              ),
              for (final y in years) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      y == 0 ? 'Year unknown' : '$y',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _PyqCard(paper: byYear[y]![i]),
                      childCount: byYear[y]!.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _PyqCard extends StatelessWidget {
  final Map<String, dynamic> paper;
  const _PyqCard({required this.paper});

  @override
  Widget build(BuildContext context) {
    final id = paper['id']?.toString() ?? '';
    final title = (paper['title'] ?? 'Untitled paper').toString();
    final exam = (paper['exam'] ?? '').toString();
    final subject = (paper['subject'] ?? '').toString();
    final qCount = (paper['questions'] is List) ? (paper['questions'] as List).length : 0;
    final mins = (paper['durationMinutes'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: id.isEmpty ? null : () => context.push('/pyq/$id', extra: paper),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.saffron.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_edu, color: AppColors.saffron),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      children: [
                        if (exam.isNotEmpty) _meta(Icons.school_outlined, exam),
                        if (subject.isNotEmpty) _meta(Icons.menu_book_outlined, subject),
                        if (qCount > 0) _meta(Icons.help_outline, '$qCount Qs'),
                        if (mins > 0) _meta(Icons.timer_outlined, '${mins}m'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🗂', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('No PYQs yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Previous year question papers will appear here once published.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ruby)),
        ),
      );
}
