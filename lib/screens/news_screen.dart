// lib/screens/news_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/shimmer_loader.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _db = FirestoreService();

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final date = timestamp.toDate();
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final enrolled = List<String>.from(auth.profile?['enrolled'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latest News & Current Affairs'),
        backgroundColor: AppColors.navy,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.listenStudentNews(enrolled, auth.groupIds),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Failed to load news.', style: TextStyle(color: AppColors.ruby)));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     ShimmerBox(height: 180, radius: 12),
                     SizedBox(height: 16),
                     ShimmerBox(height: 14, width: 80),
                     SizedBox(height: 12),
                     ShimmerBox(height: 20),
                     SizedBox(height: 16),
                     ShimmerBox(height: 60),
                  ]
                )
              ),
            );
          }
          final newsList = snapshot.data ?? [];
          if (newsList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📭', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 16),
                  Text('No updates available at the moment.', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: newsList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final news = newsList[index];
              final hasImage = news['imageUrl'] != null && news['imageUrl'].toString().isNotEmpty;
              final hasSource = news['source'] != null && news['source'].toString().isNotEmpty;

              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasImage)
                      Image.network(
                        news['imageUrl'],
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(news['createdAt']),
                            style: const TextStyle(color: AppColors.saffron, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            news['title'] ?? 'Headline',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            news['summary'] ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                          ),
                          if (hasSource) ...[
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () => _launchUrl(news['source']),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link, color: AppColors.sky, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Read full article', style: const TextStyle(color: AppColors.sky, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
