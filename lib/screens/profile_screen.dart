// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firestore_service.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/app_button.dart';
import '../widgets/tier_badge.dart';
import '../widgets/badge_display.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _nameCtrl    = TextEditingController();
  final _qualCtrl    = TextEditingController();
  final _oldPwdCtrl  = TextEditingController();
  final _newPwdCtrl  = TextEditingController();
  bool _saving = false;
  bool _changingPwd = false;

  void _showToast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.emerald : AppColors.ruby,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose(); _qualCtrl.dispose();
    _oldPwdCtrl.dispose(); _newPwdCtrl.dispose();
    super.dispose();
  }

  void _initFields(Map<String, dynamic>? profile) {
    if (_nameCtrl.text.isEmpty) _nameCtrl.text = profile?['name'] ?? '';
    if (_qualCtrl.text.isEmpty) _qualCtrl.text = profile?['qualification'] ?? '';
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final uid = auth.user?.uid;
    if (uid == null) { _showToast('❌ Not signed in.', success: false); return; }
    setState(() => _saving = true);
    try {
      await auth.updateProfile(uid, {
        'name': _nameCtrl.text.trim(),
        'qualification': _qualCtrl.text.trim(),
      });
      _showToast('✅ Profile saved!', success: true);
    } catch (_) {
      _showToast('❌ Failed to save.', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPwdCtrl.text.length < 6) {
      _showToast('❌ Password must be ≥ 6 characters.', success: false);
      return;
    }
    setState(() => _changingPwd = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showToast('❌ Not signed in.', success: false);
        return;
      }
      final cred = EmailAuthProvider.credential(email: user.email!, password: _oldPwdCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPwdCtrl.text);
      _oldPwdCtrl.clear(); _newPwdCtrl.clear();
      _showToast('✅ Password updated!', success: true);
    } on FirebaseAuthException catch (e) {
      _showToast('❌ ${e.message}', success: false);
    } finally {
      if (mounted) setState(() => _changingPwd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    _initFields(auth.profile);

    final enrolled = List<String>.from(auth.profile?['enrolledCourses'] ?? []);

    return ResponsiveScaffold(
      currentIndex: 4,
      appBar: AppBar(
        title: Text(t('nav.profile', lang)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18, color: AppColors.ruby),
            label: Text(t('common.logout', lang), style: const TextStyle(color: AppColors.ruby, fontSize: 13)),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.navyMid,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.saffron.withAlpha(51),
                  child: Text(
                    (auth.profile?['name'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.saffron),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.profile?['name'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(auth.user?.email ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(children: [
                        TierBadge(tier: auth.tier),
                        const SizedBox(width: 8),
                        StreamBuilder<int>(
                          stream: FirestoreService().listenWallet(auth.user?.uid ?? ''),
                        // Note: FirestoreService is a lightweight proxy; no persistent state is held per-instance.
                          builder: (ctx, snap) {
                            if (snap.hasError) return const Text('SS Coins: Error', style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.bold));
                            final bal = snap.data ?? 0;
                            return GestureDetector(
                              onTap: () => context.push('/wallet'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withAlpha(31),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.gold.withAlpha(77))),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('🪙', style: TextStyle(fontSize: 11)),
                                  const SizedBox(width: 3),
                                  Text('$bal', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.saffron),
                  tooltip: 'My Wallet',
                  onPressed: () => context.push('/wallet'),
                ),
              ],
            ),
          ),
          // ── Badges Section (outside Row, inside Column — gets bounded width) ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏆 My Badges', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                BadgeDisplay(badges: List<String>.from(auth.profile?['badges'] ?? [])),
              ],
            ),
          ),

          TabBar(
            controller: _tabs,
            labelColor: AppColors.saffron,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.saffron,
            tabs: [
              Tab(text: 'Edit Profile'),
              Tab(text: t('profile.changePwd', lang)),
              Tab(text: t('profile.enrolled', lang)),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // ── Edit Profile ──
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outlined, color: AppColors.textMuted)),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _qualCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Qualification', prefixIcon: Icon(Icons.school_outlined, color: AppColors.textMuted)),
                      ),
                      const SizedBox(height: 20),
                      AppButton(label: t('profile.save', lang), onPressed: () => _saveProfile(auth), fullWidth: true, loading: _saving),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Column(
                          children: [
                            _InfoRow('Member Since', auth.profile?['joinDate'] ?? '—'),
                            const SizedBox(height: 8),
                            _InfoRow('Role', auth.role),
                            const SizedBox(height: 8),
                            _InfoRow('Courses Enrolled', '${enrolled.length}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Change Password ──
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _oldPwdCtrl,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outlined, color: AppColors.textMuted)),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _newPwdCtrl,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'New Password (min 6 chars)', prefixIcon: Icon(Icons.lock_open_outlined, color: AppColors.textMuted)),
                      ),
                      const SizedBox(height: 20),
                      AppButton(label: t('profile.changePwd', lang), onPressed: _changePassword, fullWidth: true, loading: _changingPwd),
                    ],
                  ),
                ),

                // ── Enrolled Courses ──
                enrolled.isEmpty
                  ? const Center(child: Text('No enrolled courses yet.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: enrolled.length,
                      itemBuilder: (_, i) {
                        final courseId = enrolled[i];
                        return FutureBuilder<Map<String, dynamic>?>(
                          future: FirestoreService().getCourseById(courseId),
                          builder: (ctx, snap) {
                            if (snap.hasError) {
                              return ListTile(
                                leading: const CircleAvatar(backgroundColor: AppColors.navyLight, child: Icon(Icons.error_outline, color: AppColors.ruby, size: 20)),
                                title: Text(courseId, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                              );
                            }
                            final title = snap.data?['title'] as String? ?? courseId;
                            return ListTile(
                              leading: const CircleAvatar(backgroundColor: AppColors.navyLight, child: Icon(Icons.menu_book_outlined, color: AppColors.saffron, size: 20)),
                              title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                              subtitle: snap.connectionState == ConnectionState.waiting
                                ? const Text('Loading…', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
                                : null,
                              onTap: () => context.push('/course/$courseId'),
                            );
                          },
                        );
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}
