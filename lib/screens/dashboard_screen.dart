import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firestore_service.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/course_card.dart';
import '../widgets/tier_badge.dart';
import '../widgets/responsive_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/shimmer_loader.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirestoreService();
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _category = 'All';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final courses = await _db.getCourses();
      if (mounted) setState(() { _courses = courses; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load dashboard data. Please check connection.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _courses;
    if (_category != 'All') list = list.where((c) => (c['category'] ?? '') == _category).toList();
    if (_search.isNotEmpty) {
      list = list.where((c) => (c['title'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList();
    }
    return list;
  }

  List<String> get _categories {
    final cats = _courses.map((c) => c['category']?.toString() ?? '').toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  void _showArticlePreview(BuildContext context, Map<String, dynamic> news) {
    final hasSource = (news['source'] ?? '').toString().isNotEmpty;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                news['title'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3),
              ),
              const SizedBox(height: 14),
              Text(
                news['summary'] ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              ),
              if (hasSource) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Read Full Article'),
                    onPressed: () async {
                      final uri = Uri.parse(news['source'].toString());
                      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not open link'), behavior: SnackBarBehavior.floating));
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () { Navigator.of(ctx).pop(); context.push('/news'); },
                icon: const Icon(Icons.list, size: 16),
                label: const Text('See All News'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final enrolled = List<String>.from(auth.profile?['enrolled'] ?? []);

    return ResponsiveScaffold(
      currentIndex: 0,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [AppColors.saffron, AppColors.violet]).createShader(b),
          child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.gps_fixed, color: AppColors.primary, size: 20), const SizedBox(width: 6), Text('SarkariSewa', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary))]),
        ),
        actions: [
          TierBadge(tier: auth.tier),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.group, color: AppColors.textSecondary),
            onPressed: () => context.push('/friends'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outlined, color: AppColors.textSecondary),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: _error != null 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📡', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.ruby)),
                  const SizedBox(height: 16),
                  AppButton(label: 'Retry', onPressed: _load, style: AppButtonStyle.outline),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.saffron,
              onRefresh: _load,
              child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.saffron.withAlpha(38), AppColors.violet.withAlpha(20)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.saffron.withAlpha(51)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Namaste, ${auth.profile?['name'] ?? 'Student'}! 🙏',
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t('dashboard.courses', lang),
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.menu_book_outlined, color: AppColors.textMuted, size: 38),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Stats mini-row
                              Row(
                                children: [
                                  _StatChip(icon: '🪙', label: '${auth.profile?['coins'] ?? 0}', tooltip: 'Coins'),
                                  const SizedBox(width: 10),
                                  _StatChip(icon: '📚', label: '${enrolled.length}', tooltip: 'Enrolled'),
                                  const SizedBox(width: 10),
                                  _StatChip(icon: '🔥', label: auth.tier.toUpperCase(), tooltip: 'Plan'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => context.push('/battle_lobby'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.violet, AppColors.saffron]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('1v1 Battleground', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text('Challenge your friends!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search
                        TextField(
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: t('dashboard.search', lang),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                          ),
                          onChanged: (v) => setState(() => _search = v),
                        ),
                        const SizedBox(height: 12),

                        // Category chips
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final cat = _categories[i];
                              final selected = cat == _category;
                              return ChoiceChip(
                                label: Text(cat, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary)),
                                selected: selected,
                                selectedColor: AppColors.saffron,
                                backgroundColor: AppColors.navyLight,
                                side: BorderSide(color: selected ? AppColors.saffron : AppColors.border),
                                onSelected: (_) => setState(() => _category = cat),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // ── News Bite Stream ──────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('🗞 Latest Updates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            TextButton(
                              onPressed: () => context.push('/news'),
                              child: const Text('See All', style: TextStyle(color: AppColors.saffron, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _db.listenStudentNews(enrolled, auth.groupIds),
                          builder: (ctx, snap) {
                            if (snap.hasError) {
                              return const SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Error loading news.', style: TextStyle(color: AppColors.ruby, fontSize: 13)),
                                ),
                              );
                            }
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.saffron),
                                  ),
                                ),
                              );
                            }
                            final newsList = snap.data ?? [];
                            if (newsList.isEmpty) {
                              return const Text('No recent news.', style: TextStyle(color: AppColors.textMuted, fontSize: 13));
                            }

                            // Only show top 5 on dashboard
                            final displayList = newsList.take(5).toList();

                            return SizedBox(
                              height: 130,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: displayList.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 12),
                                itemBuilder: (_, i) {
                                  final news = displayList[i];
                                  return GestureDetector(
                                    onTap: () => _showArticlePreview(context, news),
                                    child: SizedBox(
                                      width: 260,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.navyLight,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              news['title'] ?? '',
                                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Flexible(
                                              child: Text(
                                                news['summary'] ?? '',
                                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Read more...',
                                              style: TextStyle(color: AppColors.saffron.withAlpha(200), fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        Text(t('dashboard.courses', lang), style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(const [
                        CourseCardShimmer(),
                        SizedBox(height: 12),
                        CourseCardShimmer(),
                        SizedBox(height: 12),
                        CourseCardShimmer(),
                      ]),
                    ),
                  )
                else if (_filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Text('📭', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(t('dashboard.noResults', lang), style: const TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => CourseCard(
                          course: _filtered[i],
                          enrolled: enrolled.contains(_filtered[i]['id']),
                          onTap: () => context.push('/course/${_filtered[i]['id']}', extra: _filtered[i]),
                        ),
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String tooltip;

  const _StatChip({required this.icon, required this.label, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
