// lib/screens/social_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firestore_service.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/app_button.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  Color _tierColor(String tier) => switch (tier) {
    'gold'   => AppColors.gold,
    'silver' => AppColors.sky,
    _        => AppColors.emerald,
  };

  String _rankBadge(int rank) => switch (rank) {
    1 => '🥇', 2 => '🥈', 3 => '🥉',
    _ => '#$rank',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final db   = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text(t('social.title', lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Battle card (teaser)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.violet.withAlpha(51), AppColors.saffron.withAlpha(26)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.violet.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text('Quiz Battle Arena', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('Challenge friends and compete in live quiz battles.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                AppButton(
                  label: t('social.challenge', lang),
                  onPressed: () => context.push('/battle_lobby'),
                  style: AppButtonStyle.secondary,
                  icon: Icons.bolt,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(t('social.leaderboard', lang), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Firestore-backed leaderboard
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.listenLeaderboard(),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Failed to load leaderboard.', style: TextStyle(color: AppColors.ruby)));
              if (!snap.hasData) {
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => const ShimmerBox(height: 70, radius: 12),
                );
              }
              final users = snap.data!;
              if (users.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No leaderboard data yet.', style: TextStyle(color: AppColors.textMuted))),
                );
              }

              // Podium for top 3
              final hasThree = users.length >= 3;
              return Column(
                children: [
                  if (hasThree)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PodiumCard(users[1], 80, AppColors.textSecondary),
                        _PodiumCard(users[0], 100, AppColors.gold),
                        _PodiumCard(users[2], 65, AppColors.saffron),
                      ],
                    ),
                  if (hasThree) const SizedBox(height: 20),

                  ...users.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final u = entry.value;
                    final tColor = _tierColor(u['tier'] as String? ?? 'free');
                    final isSelf = auth.user?.uid == u['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelf ? AppColors.saffron.withAlpha(20) : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelf ? AppColors.saffron.withAlpha(77) : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(_rankBadge(rank), style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u['name'] as String? ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(u['tier'] as String? ?? 'free', style: TextStyle(color: tColor, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text('${u['points'] ?? 0} ${t("social.battlePts", lang)}', style: TextStyle(color: tColor, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final double height;
  final Color color;
  const _PodiumCard(this.user, this.height, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        (user['name'] as String? ?? 'U').split(' ').first.substring(0, 1),
        style: const TextStyle(fontSize: 24),
      ),
      const SizedBox(height: 6),
      Text(
        (user['name'] as String? ?? 'Student').split(' ').first,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 4),
      Container(
        width: 70,
        height: height,
        decoration: BoxDecoration(
          color: color.withAlpha(51),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          border: Border.all(color: color.withAlpha(102)),
        ),
        child: Center(
          child: Text('${user['points'] ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    ],
  );
}
