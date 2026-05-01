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
    final enrolled = List<String>.from(auth.profile?['enrolledCourses'] ?? []);

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
            tooltip: 'Friends',
            icon: const Icon(Icons.group, color: AppColors.textSecondary),
            onPressed: () => context.push('/friends'),
          ),
          IconButton(
            tooltip: 'Profile',
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
                        // ── Hero greeting ─────────────────────────────
                        _HeroHeader(
                          name: (auth.profile?['name'] ?? 'Student').toString(),
                          tier: auth.tier,
                          streak: (auth.profile?['streak'] ?? 0) as int,
                          coins: (auth.profile?['coins'] ?? 0) as int,
                          enrolledCount: enrolled.length,
                        ),
                        const SizedBox(height: 18),

                        // ── Quick actions (Ambition Guru style) ───────
                        _QuickActionsRow(
                          actions: [
                            _QuickAction(
                              icon: Icons.article_outlined,
                              label: 'News',
                              color: AppColors.saffron,
                              onTap: () => context.push('/news'),
                            ),
                            _QuickAction(
                              icon: Icons.history_edu_outlined,
                              label: 'PYQ',
                              color: AppColors.emerald,
                              onTap: () => context.push('/pyq'),
                            ),
                            _QuickAction(
                              icon: Icons.edit_note,
                              label: 'Writing',
                              color: AppColors.sky,
                              onTap: () => context.push('/writing'),
                            ),
                            _QuickAction(
                              icon: Icons.local_fire_department,
                              label: 'Battle',
                              color: AppColors.ruby,
                              onTap: () => context.push('/battle_lobby'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ── Continue Learning ─────────────────────────
                        if (enrolled.isNotEmpty) ...[
                          _ContinueLearningCard(
                            course: _courses.firstWhere(
                              (c) => enrolled.contains(c['id']),
                              orElse: () => const <String, dynamic>{},
                            ),
                            onTap: (course) {
                              if (course.isNotEmpty) {
                                context.push('/course/${course['id']}', extra: course);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

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

// ── Hero header (greeting + stats) ──────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final String name;
  final String tier;
  final int streak;
  final int coins;
  final int enrolledCount;

  const _HeroHeader({
    required this.name,
    required this.tier,
    required this.streak,
    required this.coins,
    required this.enrolledCount,
  });

  @override
  Widget build(BuildContext context) {
    // Design system: greeting card uses the **soft** brand gradient
    // (`saffron @ 15% → violet @ 8%` over white) with a hairline tinted
    // border. Text is dark — this is NOT the saturated brand surface.
    return Container(
      padding: const EdgeInsets.all(AppSpace.x5),
      decoration: BoxDecoration(
        gradient: AppGradients.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.primary.withAlpha(26), width: 1),
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
                    const Text(
                      'Namaste 🙏',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Avatar circle: solid brand gradient, white initial.
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppGradients.brand,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (name.isEmpty ? 'U' : name.substring(0, 1)).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stat chips — white pills with hairline border (design system
          // "stat" component). Tier rendered separately as a tinted pill.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(emoji: '🔥', label: '$streak-day streak'),
              _StatChip(emoji: '🪙', label: '$coins coins'),
              _StatChip(emoji: '📚', label: '$enrolledCount courses'),
              _TierChip(tier: tier),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _StatChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, tint) = switch (tier) {
      'gold'   => ('🥇', 'Gold',   AppColors.gold),
      'silver' => ('🥈', 'Silver', AppColors.sky),
      _        => ('🆓', 'Free',   AppColors.emerald),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // Tier badges use tinted bg + same-color border at ~30% alpha.
        color: tint.withAlpha(31), // ~12%
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tint.withAlpha(77)), // ~30%
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions strip ─────────────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class _QuickActionsRow extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(child: _QuickActionTile(action: actions[i])),
          if (i != actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    // Design-system QuickTile: left-aligned, tinted icon block (12% alpha),
    // 14-radius card, hairline border, 600/14 label.
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        action.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.x4),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withAlpha(31), // ~12% tint
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Continue learning band ──────────────────────────────────────────────────
//
// Canonical CourseCard recipe from the design system:
//   - white surface, hairline border, radius 14
//   - 5px left-edge accent stripe in the course color
//   - 48×48 emoji block in `accent @ 12%` tint
//   - title + subtitle + thin progress bar
class _ContinueLearningCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final ValueChanged<Map<String, dynamic>> onTap;
  const _ContinueLearningCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (course.isEmpty) return const SizedBox.shrink();
    final title    = (course['title'] ?? 'Continue Learning').toString();
    final category = (course['category'] ?? '').toString();
    final emoji    = (course['emoji'] as String?) ?? '📚';
    final accentHex = course['color'] as String?;
    final accent   = _parseHex(accentHex) ?? AppColors.primary;

    return GestureDetector(
      onTap: () => onTap(course),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            children: [
              // 5-px accent stripe.
              Container(width: 5, height: 64, color: accent),
              const SizedBox(width: 12),
              // Emoji block.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withAlpha(31), // ~12%
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Learning',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          category,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var s = hex.replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
  }
}
