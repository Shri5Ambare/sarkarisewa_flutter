// lib/screens/live_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/responsive_scaffold.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();
    return ResponsiveScaffold(
      currentIndex: 3,
      appBar: AppBar(title: const Text('Live Classes')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.listenUpcomingLiveClasses(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load classes.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.ruby)),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
          }
          final classes = snap.data ?? const <Map<String, dynamic>>[];
          if (classes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎥', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('No upcoming classes',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                    SizedBox(height: 6),
                    Text('Check back soon for live sessions with our teachers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (_, i) => _LiveCard(item: classes[i]),
          );
        },
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LiveCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? 'Live class').toString();
    final teacher = (item['teacher'] ?? '').toString();
    final subject = (item['subject'] ?? '').toString();
    final start = (item['startAt'] is Timestamp)
        ? (item['startAt'] as Timestamp).toDate()
        : null;
    final mins = (item['durationMinutes'] as num?)?.toInt() ?? 60;
    final joinUrl = (item['joinUrl'] ?? '').toString();
    final isLive = item['isLive'] == true ||
        (start != null && DateTime.now().isAfter(start) && DateTime.now().isBefore(start.add(Duration(minutes: mins))));

    final dateLabel = start == null
        ? 'Time TBA'
        : DateFormat('EEE, dd MMM • h:mm a').format(start.toLocal());

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
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.ruby.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.live_tv, color: AppColors.ruby),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [if (teacher.isNotEmpty) teacher, if (subject.isNotEmpty) subject].join(' • '),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.ruby,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(dateLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${mins}m', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Spacer(),
              if (joinUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(joinUrl);
                    if (uri == null) return;
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open class link'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(isLive ? 'Join now' : 'Open link',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
