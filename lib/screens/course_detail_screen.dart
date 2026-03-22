// lib/screens/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/tier_badge.dart';
import '../widgets/badge_dialog.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});
  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _db = FirestoreService();
  Map<String, dynamic>? _course;
  bool _loading = true;
  String? _error;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final c = await _db.getCourseById(widget.courseId);
      if (mounted) setState(() { _course = c; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load course properties. Please test your connection.'; _loading = false; });
    }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _buyWithCoins(AuthProvider auth, int coinCost) async {
    if (_buying) return;
    final uid = auth.user?.uid;
    if (uid == null) return;
    setState(() => _buying = true);
    try {
      await _db.spendCoins(
        uid,
        coinCost,
        widget.courseId,
        _course?['title'] ?? '',
      );
      
      await FirebaseAnalytics.instance.logEvent(
        name: 'course_purchased',
        parameters: {
          'course_id': widget.courseId,
          'course_title': _course?['title'] ?? '',
          'price_coins': coinCost,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Enrolled! Enjoy your course.'), backgroundColor: AppColors.emerald, behavior: SnackBarBehavior.floating),
        );
        
        final newBadge = await _db.checkAndAwardBadge(uid, 'first_course');
        if (newBadge != null && mounted) {
           BadgeUnlockDialog.show(context, newBadge);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: AppColors.ruby, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final enrolled = List<String>.from(auth.profile?['enrolled'] ?? []).contains(widget.courseId);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.saffron)));
    if (_error != null) {
      return Scaffold(
        body: Center(
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
        ),
      );
    }
    if (_course == null) return const Scaffold(body: Center(child: Text('Course not found', style: TextStyle(color: AppColors.textMuted))));

    final color = _parseColor(_course!['color'] ?? '#FF6B35');
    final curriculum = List<Map<String, dynamic>>.from(_course!['curriculum'] ?? []);

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final buyBox = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: enrolled
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emerald.withAlpha(77)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, color: AppColors.emerald, size: 16),
                        SizedBox(width: 6),
                         Text('You are enrolled in this course',
                           style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   )
                : StreamBuilder<int>(
                    stream: _db.listenWallet(auth.user?.uid ?? ''),
                    builder: (ctx, walletSnap) {
                      if (walletSnap.hasError) return const Text('Failed to load SS coins.', style: TextStyle(color: AppColors.ruby, fontSize: 13));
                      final bal = walletSnap.data ?? 0;
                      final cost = (_course?['price'] ?? 0) as int;
                      final canAfford = bal >= cost;
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Coin balance row
                        Row(children: [
                          const Text('🪙', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$bal SS Coins available',
                            style: TextStyle(color: canAfford ? AppColors.emerald : AppColors.ruby, fontSize: 12, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('Cost: $cost 🪙',
                            style: const TextStyle(color: AppColors.saffron, fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        AppButton(
                          label: canAfford ? 'Buy with $cost SS Coins' : 'Insufficient Coins — Top Up',
                          onPressed: canAfford
                            ? () => _buyWithCoins(auth, cost)
                            : () => context.push('/wallet'),
                          fullWidth: true, loading: _buying,
                          icon: canAfford ? Icons.toll_outlined : Icons.add_circle_outline,
                          style: canAfford ? AppButtonStyle.primary : AppButtonStyle.outline,
                        ),
                      ]);
                    },
                  ),
            );

    final infoCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop) ...[
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [color.withAlpha(77), AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Hero(
                tag: 'course_icon_${widget.courseId}',
                child: Text(
                  (_course!['emoji']?.toString().isNotEmpty ?? false)
                      ? _course!['emoji']
                      : '📚',
                  style: const TextStyle(fontSize: 72),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(_course!['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              TierBadge(tier: _course!['tier'] ?? 'free'),
              const Spacer(),
              Text('Rs. ${_course!['price'] ?? 0}',
                  style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(_course!['subtitle'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        // Duration badge (if set)
        if ((_course!['duration'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(children: [
              const Icon(Icons.schedule_outlined, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(_course!['duration'].toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
        // Full description (if set)
        if ((_course!['description'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navyMid,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_course!['description'].toString(),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.55)),
            ),
          ),
        buyBox,
      ],
    );

    final tabsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabs,
          labelColor: AppColors.saffron,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.saffron,
          tabs: [
            Tab(text: 'Curriculum'),
            Tab(text: 'Mock Tests'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // Curriculum (Udemy Style)
              curriculum.isEmpty
                  ? const Center(child: Text('Curriculum coming soon.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: curriculum.length,
                      itemBuilder: (ctx, i) {
                        final section = curriculum[i];
                        final lectures = List<Map<String, dynamic>>.from(section['lectures'] ?? []);
                        return Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: i == 0,
                            title: Text(
                              section['title'] ?? 'Section ${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${lectures.length} lectures',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            iconColor: AppColors.saffron,
                            collapsedIconColor: AppColors.textMuted,
                            children: lectures.map((lec) {
                              final type = lec['type'] ?? 'video';
                              final isVideo = type == 'video';
                              final isLive = type == 'live';

                              IconData icon = Icons.article_outlined;
                              Color iconColor = AppColors.textPrimary;
                              
                              if (isVideo) { icon = Icons.play_circle_fill; iconColor = AppColors.saffron; }
                              if (isLive) { icon = Icons.videocam; iconColor = AppColors.emerald; }

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                                leading: Icon(icon, color: iconColor, size: 20),
                                title: Text(lec['title'] ?? 'Lecture', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                trailing: isLive && enrolled
                                    ? TextButton(
                                        onPressed: () async {
                                          final url = lec['url'];
                                          if (url != null && url.toString().isNotEmpty) {
                                            try { await launchUrl(Uri.parse(url)); } catch (_) {}
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No link provided.'), backgroundColor: AppColors.ruby, behavior: SnackBarBehavior.floating));
                                          }
                                        },
                                        child: const Text('Join Live', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold, fontSize: 11)),
                                      )
                                    : (!enrolled ? const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted) : null),
                                onTap: enrolled ? () async {
                                  final url = lec['url'];
                                  if (url != null && url.toString().isNotEmpty) {
                                    try { await launchUrl(Uri.parse(url)); } catch (_) {}
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No link provided.'), backgroundColor: AppColors.ruby, behavior: SnackBarBehavior.floating));
                                  }
                                } : null,
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

              // Mock Tests
              enrolled
                  ? StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _db.listenMockTestsForCourse(widget.courseId),
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return Center(child: Text('Error loading tests.', style: const TextStyle(color: AppColors.ruby)));
                        }
                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
                        final tests = snap.data ?? [];
                        if (tests.isEmpty) return const Center(child: Text('No mock tests available.', style: TextStyle(color: AppColors.textMuted)));
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: tests.length,
                          itemBuilder: (_, i) {
                            final test = tests[i];
                            return ListTile(
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: AppColors.navyLight, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.assignment, color: AppColors.saffron),
                              ),
                              title: Text(test['title'] ?? 'Mock Test ${i + 1}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text('${test['questions']?.length ?? 0} Questions • ${test['durationMinutes'] ?? 30} mins', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              trailing: TextButton(
                                onPressed: () => context.push('/mock-test/${test['id']}', extra: {'testInfo': test, 'battleId': null}),
                                child: const Text('Start', style: TextStyle(color: AppColors.saffron, fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : _lockedContent('Purchase course to unlock Mock Tests.'),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(_course!['title'] ?? 'Course Details')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: SingleChildScrollView(child: infoCol)),
              const SizedBox(width: 32),
              Expanded(flex: 6, child: tabsContent),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [color.withAlpha(77), AppColors.navy],
                  ),
                ),
                child: Center(child: Icon(Icons.menu_book_outlined, color: AppColors.saffron, size: 72)),
              ),
              title: Text(_course!['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        body: Column(
          children: [
            infoCol,
            const SizedBox(height: 8),
            Expanded(child: tabsContent),
          ],
        ),
      ),
    );
  }

  Widget _lockedContent(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 48),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
      ],
    ),
  );

  Color _parseColor(String hex) {
    try { return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return AppColors.saffron; }
  }
}
