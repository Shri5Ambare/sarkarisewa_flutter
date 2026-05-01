// lib/screens/mock_index_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/responsive_scaffold.dart';

class MockIndexScreen extends StatelessWidget {
  const MockIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();
    return ResponsiveScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('Mock Tests')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.listenAllMockTests(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load tests.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.ruby)),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
          }
          final tests = snap.data ?? const <Map<String, dynamic>>[];
          if (tests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📝', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('No mock tests yet',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tests.length,
            itemBuilder: (_, i) {
              final t = tests[i];
              final qCount = (t['questions'] is List) ? (t['questions'] as List).length : 0;
              final mins = (t['durationMinutes'] as num?)?.toInt() ?? 30;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withAlpha(28),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: AppColors.emerald),
                  ),
                  title: Text(
                    (t['title'] ?? 'Mock Test ${i + 1}').toString(),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '$qCount Questions • ${mins}m',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => context.push(
                      '/mock-test/${t['id']}',
                      extra: {'testInfo': t, 'battleId': null},
                    ),
                    child: const Text('Start',
                        style: TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w800)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
