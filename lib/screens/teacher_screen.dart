// lib/screens/teacher_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firestore_service.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});
  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  final _db = FirestoreService();
  int _tab = 0;
  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: msg.startsWith('✅') ? AppColors.emerald : AppColors.ruby,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static const _tabs = [
    (label: 'Dashboard', icon: Icons.dashboard_outlined),
    (label: 'Submissions', icon: Icons.assignment_outlined),
    (label: 'Announce', icon: Icons.campaign_outlined),
    (label: 'Groups', icon: Icons.groups_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final uid = auth.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(t('teacher.title', lang)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18, color: AppColors.ruby),
            label: Text(t('common.logout', lang), style: const TextStyle(color: AppColors.ruby, fontSize: 12)),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────
          Container(
            color: AppColors.navyMid,
            child: Row(
              children: List.generate(_tabs.length, (i) => Expanded(
                child: _NavTab(
                  _tabs[i].label, _tabs[i].icon, i, _tab,
                  (idx) => setState(() => _tab = idx),
                ),
              )),
            ),
          ),



          // ── Tab content ───────────────────────────────────────────
          Expanded(child: _buildTab(uid, lang)),
        ],
      ),
    );
  }

  Widget _buildTab(String uid, String lang) {
    switch (_tab) {
      case 0: return _TeacherDashboardTab(_db, uid);
      case 1: return _SubmissionsTab(_db, uid, _showToast, lang);
      case 2: return _AnnouncementsTab(_db, uid, _showToast);
      case 3: return _GroupsTab(_db, uid, _showToast);
      default: return const SizedBox();
    }
  }
}

// ── Nav Tab ───────────────────────────────────────────────────────────────────
class _NavTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index, current;
  final Function(int) onTap;
  const _NavTab(this.label, this.icon, this.index, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: active ? AppColors.saffron : Colors.transparent, width: 2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? AppColors.saffron : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              color: active ? AppColors.saffron : AppColors.textMuted,
              fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. DASHBOARD TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _TeacherDashboardTab extends StatelessWidget {
  final FirestoreService db;
  final String uid;
  const _TeacherDashboardTab(this.db, this.uid);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📊 My Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        // Listen to submissions assigned to this teacher
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.listenTeacherSubmissions(uid),
          builder: (ctx, snap) {
            if (snap.hasError) return const Center(child: Text('Error loading submissions.', style: TextStyle(color: AppColors.ruby)));
            final subs = snap.data ?? [];
            final pending = subs.where((s) => (s['status'] ?? 'pending') == 'pending').length;
            final reviewed = subs.length - pending;

            return GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
              children: [
                _StatCard('Pending Work', '$pending', Icons.hourglass_bottom, AppColors.ruby, highlight: pending > 0),
                _StatCard('Reviewed', '$reviewed', Icons.check_circle_outline, AppColors.emerald),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('📚 My Courses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.listenTeacherCourses(uid),
          builder: (ctx, snap) {
            if (snap.hasError) return const Text('Error loading courses.', style: TextStyle(color: AppColors.ruby));
            final courses = snap.data ?? [];
            if (courses.isEmpty) return const Text('No courses assigned to you yet.', style: TextStyle(color: AppColors.textMuted));
            
            return Column(
              children: courses.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Text(c['image'] ?? '📘', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(c['subtitle'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final bool highlight;
  const _StatCard(this.title, this.value, this.icon, this.color, {this.highlight=false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: highlight ? color.withAlpha(26) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: highlight ? color.withAlpha(128) : AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
      const Spacer(),
      Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. SUBMISSIONS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _SubmissionsTab extends StatefulWidget {
  final FirestoreService db;
  final String uid;
  final Function(String) toast;
  final String lang;
  const _SubmissionsTab(this.db, this.uid, this.toast, this.lang);
  @override
  State<_SubmissionsTab> createState() => _SubmissionsTabState();
}

class _SubmissionsTabState extends State<_SubmissionsTab> {
  String _filter = 'pending';
  final Map<String, TextEditingController> _remarkCtrl = {};

  @override
  void dispose() {
    for (var c in _remarkCtrl.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            for (final (f, label) in [('pending', 'Pending'), ('reviewed', 'Reviewed'), ('all', 'All')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label, style: TextStyle(
                    color: _filter == f ? AppColors.navy : AppColors.textMuted,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: _filter == f,
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.cardBg,
                  side: BorderSide(color: _filter == f ? AppColors.gold : AppColors.border),
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.db.listenTeacherSubmissions(widget.uid),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Failed to load submissions.', style: TextStyle(color: AppColors.ruby)));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
              final all = snap.data!.where((s) {
                if (_filter == 'all') return true;
                return (s['status'] ?? 'pending') == _filter;
              }).toList();
              if (all.isEmpty) {
                return const Center(child: Text('No submissions found.', style: TextStyle(color: AppColors.textMuted)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: all.length,
                itemBuilder: (_, i) {
                  final s = all[i];
                  _remarkCtrl.putIfAbsent(s['id'], () => TextEditingController(text: s['remark'] ?? ''));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('By: ${s['studentName'] ?? ''} • ${s['uploadDate'] ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            _StatusBadge(s['status'] ?? 'pending'),
                          ],
                        ),
                        if ((s['notes'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(s['notes'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                        const Divider(color: AppColors.border, height: 20),
                        TextField(
                          controller: _remarkCtrl[s['id']],
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: t('teacher.remark', widget.lang),
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Approve',
                                style: AppButtonStyle.success,
                                onPressed: () async {
                                  await widget.db.updateSubmission(s['id'], {
                                    'status': 'reviewed',
                                    'remark': _remarkCtrl[s['id']]?.text.trim() ?? '',
                                  });
                                  widget.toast('✅ Submission reviewed.');
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                label: 'Needs Work',
                                style: AppButtonStyle.danger,
                                onPressed: () async {
                                  await widget.db.updateSubmission(s['id'], {
                                    'status': 'needs_revision',
                                    'remark': _remarkCtrl[s['id']]?.text.trim() ?? '',
                                  });
                                  widget.toast('📝 Marked as needs revision.');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'reviewed'       => ('✅ Reviewed', AppColors.emerald),
      'needs_revision' => ('📝 Revision', AppColors.gold),
      _                => ('⌛ Pending', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. ANNOUNCEMENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _AnnouncementsTab extends StatelessWidget {
  final FirestoreService db;
  final String uid;
  final Function(String) toast;
  const _AnnouncementsTab(this.db, this.uid, this.toast);

  void _addAnnouncementDialog(BuildContext context, List<Map<String, dynamic>> myCourses) {
    if (myCourses.isEmpty) {
      toast('❌ You need to be assigned to a course first to send announcements.');
      return;
    }
    final titleCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    String selectedCourseId = myCourses.first['id'];
    String targetGroupId = 'all'; // 'all' means everyone in the course

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.navyMid,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📣 Broadcast Announcement', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('This will appear in the news feed of enrolled students.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              
              const Text('Target Course', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: DropdownButton<String>(
                  value: selectedCourseId,
                  isExpanded: true,
                  dropdownColor: AppColors.navyMid,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  underline: const SizedBox(),
                  items: myCourses.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['title'] ?? ''))).toList(),
                  onChanged: (v) => setS(() { selectedCourseId = v!; targetGroupId = 'all'; }),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Target Group', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.listenTeacherGroups(uid),
                builder: (ctx, groupSnap) {
                  if (groupSnap.hasError) return const Text('Error loading groups.', style: TextStyle(color: AppColors.ruby));
                  final groups = (groupSnap.data ?? []).where((g) => g['courseId'] == selectedCourseId).toList();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: DropdownButton<String>(
                      value: targetGroupId,
                      isExpanded: true,
                      dropdownColor: AppColors.navyMid,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Enrolled Students')),
                        ...groups.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['name'] ?? 'Group'))),
                      ],
                      onChanged: (v) => setS(() => targetGroupId = v!),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              
              _InputField('Headline', titleCtrl),
              const SizedBox(height: 12),
              _InputField('Announcement Details', summaryCtrl, maxLines: 3),
              const SizedBox(height: 24),
              
              AppButton(
                label: 'Publish to Feed',
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || summaryCtrl.text.trim().isEmpty) return;
                  try {
                    await db.addNews({
                      'title': titleCtrl.text,
                      'summary': summaryCtrl.text,
                      'teacherId': uid,
                      // If targeted to a group, send specifically to that group ID
                      'courseId': targetGroupId == 'all' ? selectedCourseId : targetGroupId,
                      'source': '',
                      'imageUrl': '',
                      'views': 0,
                    });
                    toast('✅ Announcement broadcasted!');
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    toast('Error: $e');
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      summaryCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Need my courses to show in the dropdown and track announcements
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.listenTeacherCourses(uid),
      builder: (ctx, courseSnap) {
        if (courseSnap.hasError) return Center(child: Text('Error loading courses.', style: TextStyle(color: AppColors.ruby)));
        final myCourses = courseSnap.data ?? [];
        
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.sky,
            onPressed: () => _addAnnouncementDialog(context, myCourses),
            icon: const Icon(Icons.campaign, color: AppColors.navy),
            label: const Text('New Post', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.listenTeacherNews(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Error loading announcements.', style: TextStyle(color: AppColors.ruby)));
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
              final posts = snap.data ?? [];
              if (posts.isEmpty) return const Center(child: Text('No announcements posted yet.', style: TextStyle(color: AppColors.textMuted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                itemCount: posts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(post['title'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.ruby, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await db.deleteNews(post['id']);
                                toast('✅ Deleted');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(post['summary'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper
// ═══════════════════════════════════════════════════════════════════════════════
class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  const _InputField(this.label, this.ctrl, {this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    const SizedBox(height: 4),
    TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.navyLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. GROUPS TAB (Manage Student Groups)
// ═══════════════════════════════════════════════════════════════════════════════
class _GroupsTab extends StatelessWidget {
  final FirestoreService db;
  final String uid;
  final Function(String) toast;
  const _GroupsTab(this.db, this.uid, this.toast);

  void _addGroupDialog(BuildContext context, List<Map<String, dynamic>> myCourses) {
    if (myCourses.isEmpty) { toast('❌ You need to be assigned to a course first'); return; }
    
    final nameCtrl = TextEditingController();
    String selectedCourseId = myCourses.first['id'];
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.navyMid,
          title: const Text('Create Student Group', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Target Course', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: DropdownButton<String>(
                  value: selectedCourseId,
                  isExpanded: true,
                  dropdownColor: AppColors.navyMid,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  underline: const SizedBox(),
                  items: myCourses.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['title'] ?? ''))).toList(),
                  onChanged: (v) => setS(() => selectedCourseId = v!),
                ),
              ),
              const SizedBox(height: 16),
              _InputField('Group Name', nameCtrl),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  await db.createStudentGroup(selectedCourseId, uid, nameCtrl.text.trim(), []);
                  toast('✅ Group created!');
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  toast('Error: $e');
                }
              },
              child: const Text('Create', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _manageGroupStudentsDialog(BuildContext context, Map<String, dynamic> group) {
    final emailCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        title: Text('Manage Students in ${group['name']}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Student by Email', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            _InputField('Student Email', emailCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () async {
              if (emailCtrl.text.trim().isEmpty) return;
              try {
                final user = await db.getUserByEmail(emailCtrl.text.trim());
                if (user == null) {
                  toast('❌ User not found with that email.');
                  return;
                }
                final studentIds = List<String>.from(group['studentIds'] ?? []);
                if (studentIds.contains(user['id'])) {
                  toast('⚠️ Student already in group.');
                  return;
                }
                await db.addStudentToGroup(group['id'], user['id']);
                toast('✅ Student added to group!');
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                toast('Error: $e');
              }
            },
            child: const Text('Add Student', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.listenTeacherCourses(uid),
      builder: (ctx, courseSnap) {
        if (courseSnap.hasError) return Center(child: Text('Error loading courses.', style: TextStyle(color: AppColors.ruby)));
        final myCourses = courseSnap.data ?? [];
        
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.violet,
            onPressed: () => _addGroupDialog(context, myCourses),
            icon: const Icon(Icons.group_add, color: AppColors.primary),
            label: const Text('Create Group', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.listenTeacherGroups(uid),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Error loading groups.', style: TextStyle(color: AppColors.ruby)));
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
              final groups = snap.data ?? [];
              if (groups.isEmpty) return const Center(child: Text('No student groups created yet.', style: TextStyle(color: AppColors.textMuted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                itemCount: groups.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final students = List<String>.from(group['studentIds'] ?? []);
                  // Find course name for this group's courseId
                  final courseMap = myCourses.firstWhere((c) => c['id'] == group['courseId'], orElse: () => {'title': 'Unknown Course'});
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(group['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person_add, color: AppColors.emerald, size: 20),
                                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  onPressed: () => _manageGroupStudentsDialog(context, group),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.ruby, size: 20),
                                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    await db.deleteStudentGroup(group['id']);
                                    toast('✅ Deleted Group');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Course: ${courseMap['title']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, color: AppColors.textMuted, size: 16),
                            const SizedBox(width: 8),
                            Text('${students.length} Students Assigned', style: const TextStyle(color: AppColors.saffron, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
