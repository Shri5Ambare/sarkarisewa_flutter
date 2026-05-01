// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_functions/cloud_functions.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firestore_service.dart';
import '../services/audit_service.dart';
import '../services/google_news_service.dart';
import '../widgets/admin/live_ops_card.dart';
import '../widgets/admin/audit_log_view.dart';
import '../widgets/admin/daily_aggregates_chart.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/paginated_list.dart';
// import '../services/cloudinary_service.dart';
import '../services/r2_storage_service.dart';
import '../services/csv_exporter.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/app_button.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;
  final _db = FirestoreService();
  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: msg.startsWith('✅') ? AppColors.emerald : AppColors.ruby,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static const _baseTabs = [
    (id: 0,  label: 'Dashboard',   icon: Icons.dashboard_outlined),
    (id: 1,  label: 'Payments',    icon: Icons.receipt_outlined),
    (id: 2,  label: 'Orders',      icon: Icons.shopping_bag_outlined),
    (id: 3,  label: 'Users',       icon: Icons.people_outlined),
    (id: 4,  label: 'Courses',     icon: Icons.menu_book_outlined),
    (id: 5,  label: 'Submissions', icon: Icons.assignment_outlined),
    (id: 6,  label: 'News',        icon: Icons.newspaper_outlined),
    (id: 7,  label: 'Ledger',      icon: Icons.receipt_long_outlined),
    (id: 8,  label: 'Settings',    icon: Icons.settings_outlined),
    (id: 9,  label: 'Analytics',   icon: Icons.analytics_outlined),
    (id: 10, label: 'Access',      icon: Icons.shield_outlined),
    (id: 11, label: 'Audit',       icon: Icons.history_outlined),
  ];

  List<({int id, String label, IconData icon})> _visibleTabs(bool isSuperAdmin) =>
      // 'Access' (10) is super-admin only. 'Audit' (11) is available to
      // all admins so they can review their own + peer activity.
      isSuperAdmin ? _baseTabs : _baseTabs.where((t) => t.id != 10).toList();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final isSuperAdmin = auth.isSuperAdmin;
    final visibleTabs  = _visibleTabs(isSuperAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t('admin.title', lang)),
          if (isSuperAdmin) ...[const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.ruby.withAlpha(31), borderRadius: BorderRadius.circular(20)),
              child: const Text('👑 Super Admin', style: TextStyle(color: AppColors.ruby, fontSize: 10, fontWeight: FontWeight.w800))),
          ],
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18, color: AppColors.ruby),
            label: Text(t('common.logout', lang), style: const TextStyle(color: AppColors.ruby, fontSize: 12)),
            onPressed: () async { await auth.signOut(); if (context.mounted) context.go('/login'); },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────
          Container(
            color: AppColors.navyMid,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(visibleTabs.length, (i) => _NavTab(
                  visibleTabs[i].label, visibleTabs[i].icon, i, _tab,
                  (idx) => setState(() => _tab = idx),
                )),
              ),
            ),
          ),



          // ── Tab content ───────────────────────────────────────────
          Expanded(child: _buildTab(lang, isSuperAdmin, visibleTabs)),
        ],
      ),
    );
  }

  Widget _buildTab(String lang, bool isSuperAdmin, List<({int id, String label, IconData icon})> visibleTabs) {
    final id = (_tab < visibleTabs.length) ? visibleTabs[_tab].id : 0;
    return switch (id) {
      0 => _DashboardTab(_db),
      1 => _PaymentsTab(_db, _showToast),
      2 => _OrdersTab(_db, _showToast, lang),
      3 => _UsersTab(_db, _showToast, lang),
      4 => _CoursesTab(_db, _showToast),
      5 => _SubmissionsTab(_db, _showToast),
      6 => _NewsTab(_db, _showToast),
      7 => _TransactionsTab(_db, _showToast),
      8 => _SettingsTab(_db, _showToast),
      9 => _AnalyticsTab(_db),
      10 => _AccessControlTab(_db, _showToast),
      11 => const _AuditTab(),
      _ => const SizedBox(),
    };
  }
}

/// Admin "Audit" tab — full-page paginated audit log. Listed last so it
/// can be linked to from any other tab via "View related audit entries".
class _AuditTab extends StatelessWidget {
  const _AuditTab();
  @override
  Widget build(BuildContext context) => const AuditLogView();
}

/// Analytics → "Trends" sub-tab. Renders the 30-day DAU/Revenue chart
/// from the `daily_aggregates` collection populated by the
/// `computeDailyAggregates` Cloud Function.
class _TrendsSubTab extends StatelessWidget {
  const _TrendsSubTab();
  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: DailyAggregatesChart(),
  );
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
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: active ? AppColors.saffron : Colors.transparent, width: 2))),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? AppColors.saffron : AppColors.textMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: active ? AppColors.saffron : AppColors.textMuted,
            fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. DASHBOARD TAB — stats cards
// ═══════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  final FirestoreService db;
  const _DashboardTab(this.db);

  void _showPushDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.navyMid,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🚀 Send Marketing Push', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Broadcasts a highly visible hook to all subscribers.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              _InputField('Title (e.g. Free Mock Test!)', titleCtrl),
              const SizedBox(height: 12),
              _InputField('Body / Hook', bodyCtrl, maxLines: 2),
              const SizedBox(height: 12),
              _InputField('Image URL (Optional Big Image)', imageCtrl),
              const SizedBox(height: 24),
              sending 
                ? const Center(child: CircularProgressIndicator(color: AppColors.saffron))
                : AppButton(
                    label: 'Blast Notification',
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                      setLocalState(() => sending = true);
                      try {
                        // Securely send push via Cloud Function (no keys in frontend)
                        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
                            .httpsCallable('sendPushNotification');
                        await callable.call({
                          'title': titleCtrl.text.trim(),
                          'body': bodyCtrl.text.trim(),
                          'imageUrl': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
                        });
                        await AuditService().log(
                          action: 'broadcast.push',
                          target: const AuditTarget(kind: 'topic', id: 'all_users'),
                          extra: {
                            'title': titleCtrl.text.trim(),
                            'body':  bodyCtrl.text.trim(),
                            if (imageCtrl.text.trim().isNotEmpty)
                              'imageUrl': imageCtrl.text.trim(),
                          },
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Notification broadcasted!'), behavior: SnackBarBehavior.floating));
                        }
                      } catch (e) {
                         setLocalState(() => sending = false);
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
                         }
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
      bodyCtrl.dispose();
      imageCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, int>>(
    future: db.getStats(),
    builder: (ctx, snap) {
      final stats = snap.data ?? {'users': 0, 'courses': 0, 'pending': 0, 'submissions': 0};
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Real-time pulse of in-flight ops. Refreshes itself every 30s.
          const LiveOpsCard(),
          const SizedBox(height: 20),
          const Text('📊 Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              _StatCard('Total Users', '${stats['users']}', Icons.people, AppColors.violet),
              _StatCard('Courses',     '${stats['courses']}', Icons.menu_book, AppColors.sky),
              _StatCard('Pending Orders', '${stats['pending']}', Icons.hourglass_bottom, AppColors.gold, highlight: true),
              _StatCard('Submissions', '${stats['submissions']}', Icons.assignment, AppColors.emerald),
            ],
          ),
          const SizedBox(height: 24),
          const Text('📈 Recent Activity (Last 7 Days)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          // Chart placeholder
          Container(
            height: 220,
            padding: const EdgeInsets.only(right: 20, left: 4, top: 20, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: _OrdersChart(db),
          ),
          
          const SizedBox(height: 24),
          const Text('⚡ Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _QuickAction(Icons.campaign, 'Broadcast Push Notification', AppColors.saffron, () => _showPushDialog(context)),
          const SizedBox(height: 8),
          _QuickAction(Icons.refresh, 'Refresh Stats', AppColors.sky, () => (ctx as Element).markNeedsBuild()),
        ],
      );
    },
  );
}

class _OrdersChart extends StatelessWidget {
  final FirestoreService db;
  const _OrdersChart(this.db);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.listenOrders(), // Charting orders instead of transactions for admin
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
        
        final txs = snapshot.data!;
        final now = DateTime.now();
        
        // Group by last 7 days
        final List<int> dailyCounts = List.filled(7, 0);
        
        for (var tx in txs) {
          if (tx['createdAt'] == null) continue;
          DateTime? date;
          if (tx['createdAt'] is DateTime) {
             date = tx['createdAt'];
          } else if (tx['createdAt'] is Timestamp) {
             date = (tx['createdAt'] as Timestamp).toDate();
          } else {
             try {
                date = (tx['createdAt'] as dynamic).toDate();
             } catch(e) { continue; }
          }
          if (date == null) continue;
          
          final diff = now.difference(date).inDays;
          if (diff >= 0 && diff < 7) {
            dailyCounts[6 - diff]++; // 6 is today, 0 is 6 days ago
          }
        }

        final maxY = dailyCounts.reduce((a, b) => a > b ? a : b).toDouble() + 5;

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY / 4).clamp(1, double.infinity),
              getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final daysAgo = 6 - value.toInt();
                    if (daysAgo < 0 || daysAgo > 6) return const SizedBox();
                    if (daysAgo == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Today', style: TextStyle(color: AppColors.textMuted, fontSize: 10)));
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('-$daysAgo d', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (maxY / 4).clamp(1, double.infinity),
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(7, (i) => FlSpot(i.toDouble(), dailyCounts[i].toDouble())),
                isCurved: true,
                color: AppColors.saffron,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.saffron.withAlpha(30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool highlight;
  const _StatCard(this.label, this.value, this.icon, this.color, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: highlight ? color.withAlpha(31) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: highlight ? color.withAlpha(102) : AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 24),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        const Spacer(),
        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW: PAYMENTS TAB — manual bank transfer review
// ═══════════════════════════════════════════════════════════════════════════════
class _PaymentsTab extends StatelessWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _PaymentsTab(this.db, this.toast);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.listenPaymentRequests(),
    builder: (ctx, snap) {
      if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.ruby)));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));

      final all      = snap.data!;
      final pending  = all.where((r) => r['status'] == 'pending').toList();
      final approved = all.where((r) => r['status'] == 'approved').toList();
      final rejected = all.where((r) => r['status'] == 'rejected').toList();

      if (all.isEmpty) {
        return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🏦', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('No payment requests yet.', style: TextStyle(color: AppColors.textMuted)),
        ]));
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('⏳ Pending Verification', pending.length, AppColors.gold),
          ...pending.map((r) => _PaymentCard(r, db, toast, showActions: true)),
          const SizedBox(height: 8),
          _SectionHeader('✅ Approved', approved.length, AppColors.emerald),
          ...approved.map((r) => _PaymentCard(r, db, toast, showActions: false)),
          const SizedBox(height: 8),
          _SectionHeader('❌ Rejected', rejected.length, AppColors.ruby),
          ...rejected.map((r) => _PaymentCard(r, db, toast, showActions: false)),
        ],
      );
    },
  );
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final FirestoreService db;
  final Function(String) toast;
  final bool showActions;
  const _PaymentCard(this.req, this.db, this.toast, {required this.showActions});

  @override
  Widget build(BuildContext context) {
    final status     = req['status'] as String? ?? 'pending';
    final coins      = req['coins'] as int? ?? 0;
    final amount     = req['amount'] as int? ?? 0;
    final screenshotUrl = req['screenshotUrl'] as String? ?? '';

    final statusColor = switch (status) {
      'approved' => AppColors.emerald,
      'rejected' => AppColors.ruby,
      _          => AppColors.gold,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: showActions ? AppColors.gold.withAlpha(80) : AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req['userName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
            Text('${req['packLabel'] ?? ''} Pack • $coins 🪙 • Rs $amount',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withAlpha(31), borderRadius: BorderRadius.circular(20)),
            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ]),

        // Screenshot thumbnail
        if (screenshotUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _viewScreenshot(context, screenshotUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                screenshotUrl, height: 130, width: double.infinity, fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(
                    height: 130,
                    color: AppColors.navyMid,
                    child: const Center(child: CircularProgressIndicator(color: AppColors.saffron, strokeWidth: 2))),
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 60,
                  decoration: BoxDecoration(color: AppColors.navyMid, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('Could not load screenshot', style: TextStyle(color: AppColors.textMuted, fontSize: 11)))),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Tap screenshot to view full size', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],

        // Actions
        if (showActions) ...[
          const SizedBox(height: 10),
          Row(children: [
            _ActionBtn('Approve ✅', AppColors.emerald, Icons.check_circle_outline, () async {
              final uid = req['uid'] as String? ?? '';
              final ok = await ConfirmDialog.show(
                context: context,
                icon: Icons.check_circle_outline,
                title: 'Approve $coins coins for ${req['userName']}?',
                message: 'This credits the user immediately and is logged. '
                         'Make sure the bank transfer of Rs $amount has '
                         'actually arrived.',
                confirmLabel: 'Approve',
              );
              if (!ok) return;
              try {
                await db.approvePaymentRequest(req['id'], uid, coins, amount);
                await AuditService().log(
                  action: 'payment.approve',
                  target: AuditTarget(kind: 'payment_request', id: req['id']),
                  extra: {
                    'uid':       uid,
                    'userName':  req['userName'],
                    'coins':     coins,
                    'amountRs':  amount,
                    'packLabel': req['packLabel'],
                  },
                );
                toast('✅ Approved — $coins coins added to ${req['userName']}');
              } catch (e) { toast('❌ $e'); }
            }),
            const SizedBox(width: 8),
            _ActionBtn('Reject ❌', AppColors.ruby, Icons.cancel_outlined, () async {
              final ok = await ConfirmDialog.show(
                context: context,
                icon: Icons.cancel_outlined,
                title: 'Reject this payment request?',
                message: 'The user will see a rejected status. Make sure '
                         "you've notified them out-of-band first.",
                confirmLabel: 'Reject',
                danger: true,
              );
              if (!ok) return;
              try {
                await db.rejectPaymentRequest(req['id']);
                await AuditService().log(
                  action: 'payment.reject',
                  target: AuditTarget(kind: 'payment_request', id: req['id']),
                  extra: {
                    'uid':       req['uid'],
                    'userName':  req['userName'],
                    'coins':     coins,
                    'amountRs':  amount,
                  },
                );
                toast('Payment request rejected');
              } catch (e) { toast('❌ $e'); }
            }),
          ]),
        ],
      ]),
    );
  }

  void _viewScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) =>
                progress == null ? child :
                const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppColors.saffron)))),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. ORDERS TAB — pending / active / rejected + activate / reject / delete
// ═══════════════════════════════════════════════════════════════════════════════
class _OrdersTab extends StatelessWidget {
  final FirestoreService db;
  final Function(String) toast;
  final String lang;
  const _OrdersTab(this.db, this.toast, this.lang);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.listenOrders(),
    builder: (ctx, snap) {
      if (snap.hasError) return _errorView('orders', snap.error);
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
      final pending  = snap.data!.where((o) => o['status'] == 'pending').toList();
      final active   = snap.data!.where((o) => o['status'] == 'active').toList();
      final rejected = snap.data!.where((o) => o['status'] == 'rejected').toList();
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.saffron,
          icon: const Icon(Icons.download, color: AppColors.navy),
          label: const Text('Export CSV', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          onPressed: () async {
            try {
              final snapshot = await db.listenOrders().first;
              await CsvExporter.exportAndShare(snapshot, 'Orders');
              toast('✅ Orders Exported');
            } catch (e) {
              toast('❌ Export failed: $e');
            }
          },
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('⏳ Pending', pending.length, AppColors.gold),
            ...pending.map((o) => _OrderCard(o, db, toast, lang)),
          const SizedBox(height: 8),
          _SectionHeader('✅ Activated', active.length, AppColors.emerald),
          ...active.map((o) => _OrderCard(o, db, toast, lang)),
          const SizedBox(height: 8),
          _SectionHeader('❌ Rejected', rejected.length, AppColors.ruby),
          ...rejected.map((o) => _OrderCard(o, db, toast, lang)),
          ],
        ),
      );
    },
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withAlpha(31), borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final FirestoreService db;
  final Function(String) toast;
  final String lang;
  const _OrderCard(this.order, this.db, this.toast, this.lang);

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order['studentName'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          _StatusBadge(status),
        ]),
        const SizedBox(height: 4),
        Text(order['courseTitle'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        Text('Rs. ${order['amount'] ?? 0}',
          style: const TextStyle(color: AppColors.saffron, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          if (isPending) ...[
            _ActionBtn('Activate', AppColors.emerald, Icons.check_circle_outline, () async {
              try {
                await db.activateOrder(order['id'], order['studentId'] ?? '', order['courseId'] ?? '');
                toast('✅ Activated ${order["studentName"]}');
              } catch (e) { toast('❌ $e'); }
            }),
            const SizedBox(width: 8),
            _ActionBtn('Reject', AppColors.ruby, Icons.cancel_outlined, () async {
              try {
                await db.rejectOrder(order['id']);
                toast('✅ Rejected order');
              } catch (e) { toast('❌ $e'); }
            }),
            const SizedBox(width: 8),
          ],
          _ActionBtn('Delete', AppColors.textMuted, Icons.delete_outline, () async {
            final ok = await _confirm(context, 'Delete this order?');
            if (!ok) return;
            try {
              await db.deleteOrder(order['id']);
              toast('✅ Order deleted');
            } catch (e) { toast('❌ $e'); }
          }),
        ]),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active'   => ('Active', AppColors.emerald),
      'rejected' => ('Rejected', AppColors.ruby),
      _          => ('Pending', AppColors.gold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(31), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  const _ActionBtn(this.label, this.color, this.icon, this.onPressed);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. USERS TAB — search + role + tier + writingAccess toggle
// ═══════════════════════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  final FirestoreService db;
  final Function(String) toast;
  final String lang;
  const _UsersTab(this.db, this.toast, this.lang);
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  // Filters drive a fresh PaginatedList instance via Key. When any
  // filter changes we bump the key, which resets the cursor and reloads
  // the first page server-side (no more in-memory filtering).
  String _search = '';
  String? _role;   // null = all
  String? _tier;   // null = all
  int _filterVer = 0;

  void _setFilter(VoidCallback mutate) {
    setState(() {
      mutate();
      _filterVer++;
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    // ── Search row + CSV export ─────────────────────────────────────
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Email starts with…',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true, fillColor: AppColors.navyMid,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
              ),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              onChanged: (v) => _setFilter(() => _search = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              try {
                final snapshot = await widget.db.listenUsers().first;
                await CsvExporter.exportAndShare(snapshot, 'Users');
                widget.toast('✅ CSV Exported successfully');
              } catch (e) {
                widget.toast('❌ Failed to export: $e');
              }
            },
            icon: const Icon(Icons.download, color: AppColors.primary),
            tooltip: 'Export users to CSV',
          ),
        ],
      ),
    ),
    // ── Filter chip rows (role + tier) ──────────────────────────────
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip('All',     _role == null,        () => _setFilter(() => _role = null)),
          _filterChip('Student', _role == 'student',   () => _setFilter(() => _role = 'student')),
          _filterChip('Teacher', _role == 'teacher',   () => _setFilter(() => _role = 'teacher')),
          _filterChip('Admin',   _role == 'admin',     () => _setFilter(() => _role = 'admin')),
          _filterChip('Super',   _role == 'super_admin', () => _setFilter(() => _role = 'super_admin')),
          const SizedBox(width: 12),
          Container(width: 1, height: 22, color: AppColors.border),
          const SizedBox(width: 12),
          _filterChip('Any tier', _tier == null,     () => _setFilter(() => _tier = null)),
          _filterChip('🆓 Free',  _tier == 'free',   () => _setFilter(() => _tier = 'free')),
          _filterChip('🥈 Silver',_tier == 'silver', () => _setFilter(() => _tier = 'silver')),
          _filterChip('🥇 Gold',  _tier == 'gold',   () => _setFilter(() => _tier = 'gold')),
        ]),
      ),
    ),
    Expanded(
      child: PaginatedList(
        // Bumping the key on filter change forces a re-fetch from page 0.
        key: ValueKey('users-$_filterVer-$_role-$_tier-$_search'),
        pageSize: 25,
        emptyEmoji: '🙋',
        emptyTitle: 'No matching users',
        emptyMessage: 'Try a broader filter or a shorter search prefix.',
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        fetchPage: ({int pageSize = 25, startAfter}) =>
            widget.db.getUsersPage(
              pageSize: pageSize,
              startAfter: startAfter,
              role: _role,
              tier: _tier,
              searchEmail: _search.isEmpty ? null : _search,
            ),
        itemBuilder: (ctx, user, _) =>
            _UserCard(user, widget.db, widget.toast),
      ),
    ),
  ]);

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        )),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.navyLight,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final FirestoreService db;
  final Function(String) toast;
  const _UserCard(this.user, this.db, this.toast);

  @override
  Widget build(BuildContext context) {
    final points = user['points'] as int? ?? 0;
    final writingAccess = user['writingAccess'] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          CircleAvatar(
            radius: 19, backgroundColor: AppColors.saffron.withAlpha(51),
            child: Text((user['name'] ?? 'U').substring(0,1).toUpperCase(),
              style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(user['email'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          // Coin balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(26), borderRadius: BorderRadius.circular(20)),
            child: Text('🪙 ${user['coins'] ?? 0}', style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.violet.withAlpha(31), borderRadius: BorderRadius.circular(20)),
            child: Text('⭐ $points pts', style: const TextStyle(color: AppColors.violet, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          // Award coins button
          GestureDetector(
            onTap: () => _showAwardCoinsDialog(context, user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.emerald.withAlpha(26), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emerald.withAlpha(77))),
              child: const Text('+ Coins', style: TextStyle(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Controls row
        Row(children: [
          // Role
          _DropLabel('Role'),
          const SizedBox(width: 4),
          _AdminDropdown<String>(
            value: user['role'] ?? 'student',
            items: ['student', 'teacher', 'admin'],
            onChanged: (v) async {
              if (v == null) return;
              try { await db.updateUserDoc(user['id'], {'role': v}); toast('✅ Role → $v'); }
              catch (e) { toast('❌ $e'); }
            },
          ),
          const SizedBox(width: 16),
          // Tier
          _DropLabel('Tier'),
          const SizedBox(width: 4),
          _AdminDropdown<String>(
            value: user['tier'] ?? 'free',
            items: ['free', 'silver', 'gold'],
            onChanged: (v) async {
              if (v == null) return;
              try { await db.updateUserDoc(user['id'], {'tier': v}); toast('✅ Tier → $v'); }
              catch (e) { toast('❌ $e'); }
            },
          ),
          const Spacer(),
          // Writing access toggle
          const Text('✍️', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: writingAccess,
              activeTrackColor: AppColors.emerald,
              onChanged: (v) async {
                try { await db.updateUserDoc(user['id'], {'writingAccess': v}); toast('✅ Writing access ${v ? "on" : "off"}'); }
                catch (e) { toast('❌ $e'); }
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.lock_reset, color: AppColors.saffron, size: 22),
            tooltip: 'Send Password Reset Email',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () async {
              try {
                final email = user['email'];
                if (email != null && email.toString().isNotEmpty) {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  toast('✅ Password reset email sent to $email');
                } else {
                  toast('❌ User has no email');
                }
              } catch (e) {
                toast('❌ Failed: $e');
              }
            },
          ),
        ]),
      ]),
    );
  }
}

class _DropLabel extends StatelessWidget {
  final String text;
  const _DropLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 11));
}

class _AdminDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  const _AdminDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.navyMid, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border)),
    child: DropdownButton<T>(
      value: value,
      dropdownColor: AppColors.navyMid,
      isDense: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      underline: const SizedBox(),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
      onChanged: onChanged,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. COURSES TAB — list + add / edit / delete
// ═══════════════════════════════════════════════════════════════════════════════
class _CoursesTab extends StatelessWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _CoursesTab(this.db, this.toast);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.listenCourses(),
    builder: (ctx, snap) {
      if (snap.hasError) return _errorView('courses', snap.error);
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
      final courses = snap.data!;
      return Stack(children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: courses.length,
          itemBuilder: (_, i) => _CourseAdminCard(courses[i], db, toast),
        ),
        Positioned(
          right: 20, bottom: 20,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.saffron,
            icon: const Icon(Icons.add, color: AppColors.navy),
            label: const Text('Add Course', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
            onPressed: () => _showCourseDialog(context, db, toast),
          ),
        ),
      ]);
    },
  );
}

class _CourseAdminCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final FirestoreService db;
  final Function(String) toast;
  const _CourseAdminCard(this.course, this.db, this.toast);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Text(course['image'] ?? '📚', style: const TextStyle(fontSize: 28)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(course['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
        Text(course['subtitle'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          _TierChip(course['tier'] ?? 'free'),
          const SizedBox(width: 6),
          Text('Rs. ${course['price'] ?? 0}', style: const TextStyle(color: AppColors.saffron, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () => _showManageTestsDialog(context, db, toast, course),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sky.withAlpha(26), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sky.withAlpha(77))
                ),
                child: const Text('📝 Manage Tests', style: TextStyle(color: AppColors.sky, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showManageCurriculumDialog(context, db, toast, course),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withAlpha(26), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withAlpha(77))
                ),
                child: const Text('🛠 Curriculum', style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ])),
      Column(children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppColors.emerald, size: 20),
          onPressed: () => _showCourseDialog(context, db, toast, course: course),
        ),
        IconButton(
          tooltip: 'Delete course',
          icon: const Icon(Icons.delete_outline, color: AppColors.ruby, size: 20),
          onPressed: () async {
            // Typed confirmation — irreversible action.
            final title = (course['title'] ?? 'this course').toString();
            final ok = await ConfirmDialog.showTyped(
              context: context,
              title: 'Delete "$title"?',
              message: 'This deletes the course and all its curriculum '
                       'metadata. Enrolled users keep access to past lessons '
                       "in their progress doc, but the course can't be "
                       'enrolled in again.',
              requireTyping: 'DELETE',
              confirmLabel: 'Delete course',
            );
            if (!ok) return;
            try {
              await db.deleteCourse(course['id']);
              await AuditService().log(
                action: 'course.delete',
                target: AuditTarget(kind: 'course', id: course['id']),
                before: {
                  'title': course['title'],
                  'price': course['price'],
                  'category': course['category'],
                },
              );
              toast('✅ Course deleted');
            } catch (e) {
              toast('❌ $e');
            }
          },
        ),
      ]),
    ]),
  );
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip(this.tier);
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'gold'   => ('🥇 Gold', AppColors.gold),
      'silver' => ('🥈 Silver', AppColors.sky),
      _        => ('🆓 Free', AppColors.emerald),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(31), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

Future<void> _pickAndUploadFile(BuildContext context, FirestoreService db, Function(String) toast, Function(String) onUrlCopied, {bool isImage = false}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.custom,
      withData: true,
      allowedExtensions: isImage ? null : ['pdf', 'jpg', 'png', 'jpeg', 'mp4'],
    );
    if (result == null || result.files.isEmpty) return;
    
    final file = result.files.first;
    toast('⏳ Uploading ${file.name} to R2...');
    
    // R2 handles both images and files generically now.
    // For images, we could still use Cloudinary if needed, but the user asked for Hybrid 
    // where course assets go to R2.
    final url = await R2StorageService.uploadFile(file);
    
    if (url != null) {
      onUrlCopied(url);
      toast('✅ Upload successful!');
    } else {
      toast('❌ Upload failed.');
    }
  } catch (e) {
    toast('❌ Error uploading: $e');
  }
}

void _showCourseDialog(BuildContext context, FirestoreService db, Function(String) toast,
    {Map<String, dynamic>? course}) {
  final isEdit = course != null;
  final titleCtrl       = TextEditingController(text: course?['title'] ?? '');
  final subtitleCtrl    = TextEditingController(text: course?['subtitle'] ?? '');
  final descriptionCtrl = TextEditingController(text: course?['description'] ?? '');
  final imageCtrl       = TextEditingController(text: course?['image'] ?? '📚');
  final colorCtrl       = TextEditingController(text: course?['color'] ?? '#FF6B35');
  final priceCtrl       = TextEditingController(text: '${course?['price'] ?? 0}');
  final durationCtrl    = TextEditingController(text: course?['duration'] ?? '');
  String selectedTier = course?['tier'] ?? 'free';
  String? selectedTeacherId = course?['teacherId'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyMid,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
          Text(isEdit ? '✏️ Edit Course' : '➕ Add Course',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _InputField('Title', titleCtrl),
          const SizedBox(height: 10),
          _InputField('Subtitle (short tagline)', subtitleCtrl),
          const SizedBox(height: 10),
          _InputField('Description (full details, what students will learn…)', descriptionCtrl, maxLines: 4),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _InputField('Emoji (image link)', imageCtrl)),
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.saffron),
                    tooltip: 'Upload Image',
                    onPressed: () => _pickAndUploadFile(context, db, toast, (url) => setS(() => imageCtrl.text = url), isImage: true),
                  ),
                ]
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _InputField('Color (#hex)', colorCtrl)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _InputField('Duration (e.g. 40 hrs)', durationCtrl)),
            const SizedBox(width: 10),
            Expanded(child: const SizedBox()),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _InputField('Price (Rs)', priceCtrl, keyboard: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tier', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: DropdownButton<String>(
                  value: selectedTier,
                  isExpanded: true,
                  dropdownColor: AppColors.navyMid,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  underline: const SizedBox(),
                  items: ['free','silver','gold'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) { if (v != null) setS(() => selectedTier = v); },
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 10),
          const Text('Assign Teacher (Optional)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: FutureBuilder<List<Map<String,dynamic>>>(
              future: db.getTeachers(),
              builder: (ctx, snap) {
                final teachers = snap.data ?? [];
                final allTeacherIds = teachers.map((e) => e['id']).toList();
                if (selectedTeacherId != null && !allTeacherIds.contains(selectedTeacherId)) {
                  selectedTeacherId = null;
                }
                return DropdownButton<String>(
                  value: selectedTeacherId,
                  hint: const Text('Global (No specific teacher)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: AppColors.navyMid,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Global (No specific teacher)')),
                    ...teachers.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text('${t['name']} (${t['email']})')))
                  ],
                  onChanged: (v) => setS(() => selectedTeacherId = v),
                );
              }
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: isEdit ? '💾 Save Changes' : '➕ Create Course',
            fullWidth: true,
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) { toast('❌ Title is required'); return; }
              final data = {
                'title':       titleCtrl.text.trim(),
                'subtitle':    subtitleCtrl.text.trim(),
                'description': descriptionCtrl.text.trim(),
                'image':       imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : '📚',
                'color':       colorCtrl.text.trim().isNotEmpty ? colorCtrl.text.trim() : '#FF6B35',
                'price':       int.tryParse(priceCtrl.text.trim()) ?? 0,
                'tier':        selectedTier,
                'duration':    durationCtrl.text.trim(),
                'teacherId':   selectedTeacherId,
              };
              try {
                if (isEdit) {
                  await db.updateCourse(course['id'], data);
                  toast('✅ Course updated');
                } else {
                  await db.addCourse(data);
                  toast('✅ Course created');
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) { toast('❌ $e'); }
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    )),
  ).whenComplete(() {
    titleCtrl.dispose();
    subtitleCtrl.dispose();
    descriptionCtrl.dispose();
    imageCtrl.dispose();
    colorCtrl.dispose();
    priceCtrl.dispose();
    durationCtrl.dispose();
  });
}

/// Dialog to manage Udemy-like Curriculum (Sections → Lectures with content URLs)
void _showManageCurriculumDialog(BuildContext context, FirestoreService db, Function(String) toast, Map<String, dynamic> course) {
  List<Map<String, dynamic>> sections = List<Map<String, dynamic>>.from(
    (course['curriculum'] as List? ?? []).map((s) => Map<String, dynamic>.from(s as Map))
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyMid,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('🛠 Course Curriculum',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => setS(() => sections.add({'title': 'New Section', 'lectures': []})),
                  icon: const Icon(Icons.add, color: AppColors.emerald, size: 16),
                  label: const Text('Add Section', style: TextStyle(color: AppColors.emerald)),
                ),
              ]),
              const Text('Add videos, PDFs, live classes or articles to each section.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Divider(color: AppColors.border, height: 20),

              // Sections list
              Expanded(
                child: sections.isEmpty
                  ? const Center(child: Text('No sections yet. Tap "Add Section" to start.',
                      style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      itemCount: sections.length,
                      itemBuilder: (_, sIdx) {
                        final section = sections[sIdx];
                        final lectures = List<Map<String, dynamic>>.from(
                          (section['lectures'] as List? ?? []).map((l) => Map<String, dynamic>.from(l as Map))
                        );
                        section['lectures'] = lectures; // keep ref in sync

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Section header ───────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.navyLight,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.folder_outlined, color: AppColors.saffron, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: section['title']),
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                                      decoration: const InputDecoration(
                                        hintText: 'Section title…', hintStyle: TextStyle(color: AppColors.textMuted),
                                        isDense: true, border: InputBorder.none,
                                      ),
                                      onChanged: (v) => section['title'] = v,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setS(() => sections.removeAt(sIdx)),
                                    child: const Icon(Icons.delete_outline, color: AppColors.ruby, size: 18),
                                  ),
                                ]),
                              ),

                              // ── Lectures ─────────────────────────────
                              ...List.generate(lectures.length, (lIdx) {
                                final lec = lectures[lIdx];
                                String lecType = (lec['type'] ?? 'video') as String;

                                // Per-lecture type icon & colour
                                IconData typeIcon(String t) => switch(t) {
                                  'video'   => Icons.play_circle_fill,
                                  'live'    => Icons.videocam,
                                  'pdf'     => Icons.picture_as_pdf,
                                  'article' => Icons.article_outlined,
                                  'quiz'    => Icons.quiz_outlined,
                                  _         => Icons.link,
                                };
                                Color typeColor(String t) => switch(t) {
                                  'video'   => AppColors.saffron,
                                  'live'    => AppColors.emerald,
                                  'pdf'     => AppColors.ruby,
                                  'article' => AppColors.sky,
                                  'quiz'    => AppColors.violet,
                                  _         => AppColors.textMuted,
                                };
                                String urlHint(String t) => switch(t) {
                                  'video'   => 'YouTube or video URL…',
                                  'live'    => 'Zoom / Google Meet link…',
                                  'pdf'     => 'Google Drive or PDF URL…',
                                  'article' => 'Article / webpage URL…',
                                  'quiz'    => 'Quiz page URL (optional)…',
                                  _         => 'Content URL…',
                                };

                                return StatefulBuilder(builder: (ctx2, setL) => Container(
                                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.navyMid,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: typeColor(lecType).withAlpha(60)),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      // Type dropdown
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: typeColor(lecType).withAlpha(30),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: DropdownButton<String>(
                                          value: lecType,
                                          isDense: true, underline: const SizedBox(),
                                          dropdownColor: AppColors.navyMid,
                                          items: [
                                            for (final t in ['video', 'live', 'pdf', 'article', 'quiz'])
                                              DropdownMenuItem(
                                                value: t,
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                  Icon(typeIcon(t), color: typeColor(t), size: 13),
                                                  const SizedBox(width: 4),
                                                  Text(t[0].toUpperCase() + t.substring(1),
                                                      style: TextStyle(color: typeColor(t), fontSize: 11)),
                                                ]),
                                              ),
                                          ],
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setL(() { lecType = v; lec['type'] = v; });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Title field
                                      Expanded(
                                        child: TextField(
                                          controller: TextEditingController(text: lec['title']),
                                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                          decoration: const InputDecoration(
                                            hintText: 'Lecture title…', hintStyle: TextStyle(color: AppColors.textMuted),
                                            isDense: true, border: InputBorder.none,
                                          ),
                                          onChanged: (v) => lec['title'] = v,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setS(() => lectures.removeAt(lIdx)),
                                        child: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                                      ),
                                    ]),
                                    const SizedBox(height: 6),
                                    // URL / link field
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: TextEditingController(text: lec['url'] ?? ''),
                                            style: const TextStyle(color: AppColors.sky, fontSize: 12),
                                            decoration: InputDecoration(
                                              hintText: urlHint(lecType),
                                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                              prefixIcon: Icon(Icons.link, color: typeColor(lecType), size: 14),
                                              prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
                                              isDense: true,
                                              filled: true, fillColor: AppColors.navy,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: typeColor(lecType).withAlpha(40)),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: typeColor(lecType).withAlpha(40)),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                            ),
                                            onChanged: (v) => lec['url'] = v,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.saffron, size: 20),
                                          tooltip: 'Upload File',
                                          onPressed: () => _pickAndUploadFile(context, db, toast, (url) {
                                            setL(() { lec['url'] = url; });
                                          }),
                                        ),
                                      ],
                                    ),
                                  ]),
                                ));
                              }),

                              // ── Add lecture buttons ───────────────────
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Wrap(spacing: 6, runSpacing: 4, children: [
                                  for (final (type, icon, color, label) in [
                                    ('video',   Icons.play_circle_fill,   AppColors.saffron, '+ Video'),
                                    ('live',    Icons.videocam,           AppColors.emerald, '+ Live'),
                                    ('pdf',     Icons.picture_as_pdf,     AppColors.ruby,    '+ PDF'),
                                    ('article', Icons.article_outlined,   AppColors.sky,     '+ Article'),
                                    ('quiz',    Icons.quiz_outlined,      AppColors.violet,  '+ Quiz'),
                                  ])
                                    GestureDetector(
                                      onTap: () => setS(() {
                                        lectures.add({'title': 'New $label', 'type': type, 'url': ''});
                                        section['lectures'] = lectures;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(20),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: color.withAlpha(70)),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(icon, color: color, size: 12),
                                          const SizedBox(width: 4),
                                          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ]),
                                      ),
                                    ),
                                ]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),

              const SizedBox(height: 12),
              AppButton(
                label: '💾 Save Curriculum',
                fullWidth: true,
                onPressed: () async {
                  try {
                    await db.updateCourse(course['id'], {'curriculum': sections});
                    toast('✅ Curriculum saved!');
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    toast('❌ Failed to save: $e');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType keyboard;
  final int maxLines;
  const _InputField(this.label, this.ctrl, {this.keyboard = TextInputType.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    const SizedBox(height: 4),
    TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5. SUBMISSIONS TAB — all submissions + filter + feedback
// ═══════════════════════════════════════════════════════════════════════════════
class _SubmissionsTab extends StatefulWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _SubmissionsTab(this.db, this.toast);
  @override
  State<_SubmissionsTab> createState() => _SubmissionsTabState();
}

class _SubmissionsTabState extends State<_SubmissionsTab> {
  String _filter = 'all';   // all / pending / reviewed

  @override
  Widget build(BuildContext context) => Column(children: [
    // Filter chips
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        for (final (f, label) in [('all','All'), ('pending','Pending'), ('reviewed','Reviewed')])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label, style: TextStyle(
                color: _filter == f ? AppColors.navy : AppColors.textMuted,
                fontSize: 12, fontWeight: FontWeight.w600)),
              selected: _filter == f,
              selectedColor: AppColors.saffron,
              backgroundColor: AppColors.cardBg,
              side: BorderSide(color: _filter == f ? AppColors.saffron : AppColors.border),
              onSelected: (_) => setState(() => _filter = f),
            ),
          ),
      ]),
    ),
    Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.db.listenAllSubmissions(),
        builder: (ctx, snap) {
          if (snap.hasError) return _errorView('submissions', snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
          final all = snap.data!.where((s) {
            if (_filter == 'all') return true;
            return (s['status'] ?? 'pending') == _filter;
          }).toList();
          if (all.isEmpty) return const Center(child: Text('No submissions yet.', style: TextStyle(color: AppColors.textMuted)));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: all.length,
            itemBuilder: (_, i) => _SubmissionCard(all[i], widget.db, widget.toast),
          );
        },
      ),
    ),
  ]);
}

class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> sub;
  final FirestoreService db;
  final Function(String) toast;
  const _SubmissionCard(this.sub, this.db, this.toast);
  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  late final _scoreCtrl = TextEditingController(text: '${widget.sub['score'] ?? ''}');

  @override
  void dispose() { _scoreCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    final status = sub['status'] as String? ?? 'pending';
    final isReviewed = status == 'reviewed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isReviewed ? AppColors.emerald.withAlpha(77) : AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Text(sub['studentName'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          _StatusBadge(status),
        ]),
        const SizedBox(height: 4),
        Text(sub['topic'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        Text(sub['uploadDate'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        if (sub['fileUrl'] != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(sub['fileUrl'] as String), mode: LaunchMode.externalApplication),
            child: const Text('📎 View attachment', style: TextStyle(color: AppColors.sky, fontSize: 11, decoration: TextDecoration.underline)),
          ),
        ],
        const Divider(height: 20, color: AppColors.border),
        // Score + review
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _InputField('Score / Feedback', _scoreCtrl, keyboard: TextInputType.number)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: _ActionBtn(
              isReviewed ? 'Reviewed ✅' : 'Mark Reviewed',
              isReviewed ? AppColors.emerald : AppColors.saffron,
              isReviewed ? Icons.check_circle : Icons.rate_review_outlined,
              () async {
                try {
                  await widget.db.updateSubmission(sub['id'], {
                    'status': 'reviewed',
                    'score': _scoreCtrl.text.trim(),
                    'reviewedAt': DateTime.now().toIso8601String(),
                  });
                  widget.toast('✅ Submission marked reviewed');
                } catch (e) { widget.toast('❌ $e'); }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════
Widget _errorView(String resource, Object? error) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text('Error loading $resource: $error',
      style: const TextStyle(color: AppColors.ruby), textAlign: TextAlign.center),
  ),
);

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.navyMid,
      title: const Text('Confirm', style: TextStyle(color: AppColors.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirm', style: TextStyle(color: AppColors.ruby))),
      ],
    ),
  );
  return result ?? false;
}

/// Admin dialog to award (positive) or deduct (negative) SS Coins from a user.
void _showAwardCoinsDialog(BuildContext context, Map<String, dynamic> user) {
  final amountCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  bool award = true; // true = award, false = deduct
  final db = FirestoreService();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: AppColors.navyMid,
      title: Text('🪙 Coins for ${user['name'] ?? ''}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Award / Deduct toggle
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setS(() => award = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: award ? AppColors.emerald.withAlpha(51) : AppColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: award ? AppColors.emerald : AppColors.border)),
              child: const Center(child: Text('➕ Award', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 13))),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: () => setS(() => award = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: !award ? AppColors.ruby.withAlpha(51) : AppColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: !award ? AppColors.ruby : AppColors.border)),
              child: const Center(child: Text('➖ Deduct', style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.w700, fontSize: 13))),
            ),
          )),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Coin amount (e.g. 100)',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true, fillColor: AppColors.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            prefixText: '🪙 ',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Reason (e.g. Referral bonus)',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true, fillColor: AppColors.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(
          onPressed: () async {
            final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
            if (amount <= 0) return;
            final delta = award ? amount : -amount;
            final reason = reasonCtrl.text.trim().isEmpty ? 'Admin adjustment' : reasonCtrl.text.trim();
            try {
              await db.adminAdjustCoins(user['id'], delta, reason);
              await AuditService().log(
                action: award ? 'user.coin_award' : 'user.coin_deduct',
                target: AuditTarget(kind: 'user', id: user['id']),
                extra: {
                  'userEmail': user['email'],
                  'delta':     delta,
                  'reason':    reason,
                },
              );
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (_) {}
          },
          child: Text(award ? 'Award' : 'Deduct',
            style: TextStyle(color: award ? AppColors.emerald : AppColors.ruby, fontWeight: FontWeight.w700)),
        ),
      ],
    )),
  );
}

/// Dialog to add a Mock Test (MCQ test) to a specific course
void _showManageTestsDialog(BuildContext context, FirestoreService db, Function(String) toast, Map<String, dynamic> course) {
  final titleCtrl = TextEditingController();
  final durationCtrl = TextEditingController(text: '30'); // Default 30 mins
  
  // List to hold the dynamically added questions
  List<Map<String, dynamic>> questions = [];
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyMid,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24
        ),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📝 Add Mock Test for ${course['title']}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(flex: 3, child: _InputField('Test Title', titleCtrl)),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: _InputField('Mins', durationCtrl, keyboard: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Questions (${questions.length})', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16, color: AppColors.emerald),
                    label: const Text('Add Q', style: TextStyle(color: AppColors.emerald)),
                    onPressed: () {
                      setS(() {
                        questions.add({
                          'textCtrl': TextEditingController(),
                          'opts': [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()],
                          'correctIdx': 0,
                        });
                      });
                    },
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (_, i) {
                    final q = questions[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Q${i+1}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.ruby, size: 18),
                                onPressed: () => setS(() => questions.removeAt(i)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _InputField('Question Text', q['textCtrl'], maxLines: 2),
                          const SizedBox(height: 12),
                          ...List.generate(4, (optIdx) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                RadioMenuButton<int>(
                                  value: optIdx,
                                  groupValue: q['correctIdx'],
                                  onChanged: (val) => setS(() => q['correctIdx'] = val),
                                  child: Expanded(child: _InputField('Option ${String.fromCharCode(65 + optIdx)}', q['opts'][optIdx])),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Save Mock Test',
                fullWidth: true,
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || questions.isEmpty) {
                    toast('❌ Title and at least 1 question required');
                    return;
                  }
                  
                  // Serialize
                  List<Map<String, dynamic>> serializedQs = [];
                  for (var q in questions) {
                    List<String> opts = (q['opts'] as List<TextEditingController>).map((c) => c.text.trim()).toList();
                    serializedQs.add({
                      'questionText': q['textCtrl'].text.trim(),
                      'options': opts,
                      'correctOptionIndex': q['correctIdx'],
                    });
                  }

                  final data = {
                    'title': titleCtrl.text.trim(),
                    'durationMinutes': int.tryParse(durationCtrl.text) ?? 30,
                    'questions': serializedQs,
                  };

                  try {
                    await db.createMockTest(course['id'], data);
                    toast('✅ Mock test created successfully');
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    toast('❌ Failed to save test: $e');
                  }
                },
              )
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    titleCtrl.dispose();
    durationCtrl.dispose();
    for (final q in questions) {
      (q['textCtrl'] as TextEditingController).dispose();
      for (final c in (q['opts'] as List<dynamic>).cast<TextEditingController>()) {
        c.dispose();
      }
    }
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6. NEWS TAB — Post and Manage Daily Current Affairs bites
// ═══════════════════════════════════════════════════════════════════════════════
class _NewsTab extends StatefulWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _NewsTab(this.db, this.toast);
  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  bool _fetching = false;

  void _addNewsDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.navyMid,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Post Summarized News', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _InputField('Headline / Title', titleCtrl),
            const SizedBox(height: 12),
            _InputField('Short Summary / Bite', summaryCtrl, maxLines: 3),
            const SizedBox(height: 12),
            _InputField('Source URL (Optional)', sourceCtrl),
            const SizedBox(height: 12),
            _InputField('Cover Image URL (Optional)', imageUrlCtrl),
            const SizedBox(height: 24),
            AppButton(
              label: 'Publish',
              onPressed: () async {
                final title = titleCtrl.text;
                final summary = summaryCtrl.text;
                final source = sourceCtrl.text;
                final imageUrl = imageUrlCtrl.text;
                if (title.trim().isEmpty || summary.trim().isEmpty) return;
                try {
                  await widget.db.addNews({
                    'title': title, 'summary': summary,
                    'source': source, 'imageUrl': imageUrl, 'views': 0,
                  });
                  widget.toast('✅ News Published');
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) { widget.toast('Error: $e'); }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ).whenComplete(() {
      titleCtrl.dispose(); summaryCtrl.dispose();
      sourceCtrl.dispose(); imageUrlCtrl.dispose();
    });
  }

  Future<void> _fetchFromGoogleNews() async {
    setState(() => _fetching = true);
    try {
      final service = GoogleNewsService(db: widget.db);
      final count = await service.fetchAndSave();
      widget.toast(count > 0 ? '✅ $count new article${count == 1 ? '' : 's'} imported!' : 'ℹ️ No new articles found');
    } catch (e) {
      widget.toast('❌ Fetch failed: $e');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.saffron,
      onPressed: () => _addNewsDialog(context),
      icon: const Icon(Icons.add, color: AppColors.navy),
      label: const Text('Post News', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
    ),
    body: Column(
      children: [
        // Auto-fetch banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.rss_feed, color: AppColors.sky, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Google News Auto-Import', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Fetches Nepal Lok Sewa & exam news from Google News RSS', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 10),
            _fetching
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky))
              : GestureDetector(
                  onTap: _fetchFromGoogleNews,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.sky.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.sky.withAlpha(80)),
                    ),
                    child: const Text('🔄 Fetch Now', style: TextStyle(color: AppColors.sky, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
          ]),
        ),
        const SizedBox(height: 8),

        // News list
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.db.listenAllNews(),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Error loading news.', style: TextStyle(color: AppColors.ruby)));
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
              final newsList = snap.data ?? [];
              if (newsList.isEmpty) return const Center(child: Text('No news posted yet.', style: TextStyle(color: AppColors.textMuted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                itemCount: newsList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final news = newsList[i];
                  final isAutoFetched = news['autoFetched'] == true;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isAutoFetched ? AppColors.sky.withAlpha(60) : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (isAutoFetched) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.sky.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                              child: const Text('🔗 Google News', style: TextStyle(color: AppColors.sky, fontSize: 9, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(news['title'] ?? '',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.ruby),
                            onPressed: () async {
                              await widget.db.deleteNews(news['id']);
                              widget.toast('✅ News Deleted');
                            },
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(news['summary'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (news['imageUrl'] != null && news['imageUrl'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(news['imageUrl'], height: 120, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox()),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}




// ═══════════════════════════════════════════════════════════════════════════════
// 7. TRANSACTIONS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _TransactionsTab extends StatelessWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _TransactionsTab(this.db, this.toast);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.navyMid,
          child: const Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.emerald),
              SizedBox(width: 8),
              Text('Global Platform Ledger', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.listenAllTransactions(),
            builder: (ctx, snap) {
              if (snap.hasError) return const Center(child: Text('Error loading transactions.', style: TextStyle(color: AppColors.ruby)));
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
              final txs = snap.data ?? [];
              if (txs.isEmpty) return const Center(child: Text('No transactions logs yet.', style: TextStyle(color: AppColors.textMuted)));
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: txs.length,
                itemBuilder: (_, i) {
                  final t = txs[i];
                  final coins = t['coins'] as int? ?? 0;
                  final isPositive = coins > 0;
                  final type = t['type'] ?? 'unknown';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isPositive ? AppColors.emerald.withAlpha(51) : AppColors.ruby.withAlpha(51),
                          child: Icon(
                            isPositive ? Icons.add : Icons.remove,
                            color: isPositive ? AppColors.emerald : AppColors.ruby,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['description'] ?? 'Transaction', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('User ID: ${t['uid']} • Type: $type', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                            ],
                          ),
                        ),
                        Text(
                          '${isPositive ? "+" : ""}$coins 🪙',
                          style: TextStyle(
                            color: isPositive ? AppColors.emerald : AppColors.ruby,
                            fontWeight: FontWeight.bold,
                          ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// 8. SETTINGS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _SettingsTab extends StatefulWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _SettingsTab(this.db, this.toast);

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _showBulkAwardDialog(BuildContext context) {
    bool awarding = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        title: const Text('🎁 Bulk Promo Award', style: TextStyle(color: AppColors.saffron, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send SS Coins to EVERY registered user!', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            _InputField('Amount of Coins per user', _amountCtrl, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _InputField('Reason (e.g. Dashain Bonus)', _reasonCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          awarding 
            ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: CircularProgressIndicator(strokeWidth: 2))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.saffron, foregroundColor: AppColors.navy),
                onPressed: () async {
                   final amount = int.tryParse(_amountCtrl.text.trim());
                   final reason = _reasonCtrl.text.trim();
                   if (amount == null || amount <= 0 || reason.isEmpty) {
                     widget.toast('❌ Valid amount and reason required');
                     return;
                   }
                   setS(() => awarding = true);
                   try {
                     await widget.db.bulkAwardCoins(amount, reason);
                     widget.toast('✅ Promo coins awarded to everyone!');
                     if (ctx.mounted) Navigator.pop(ctx);
                   } catch (e) {
                     widget.toast('❌ Failed: $e');
                   } finally {
                     _amountCtrl.clear();
                     _reasonCtrl.clear();
                     if (ctx.mounted) setS(() => awarding = false);
                   }
                },
                child: const Text('Blast Promo 🚀'),
              ),
        ],
      )),
    );
  }


  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('⚙️ Platform Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Global Actions', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Divider(height: 24, color: AppColors.border),
              
              // Bulk Award Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(backgroundColor: AppColors.navyLight, child: Icon(Icons.card_giftcard, color: AppColors.saffron)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Bulk Promo Coins', style: TextStyle(color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Send promotional coins to all users', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100, // Fixed width prevents squashing text
                    child: AppButton(
                      label: 'Gift All',
                      onPressed: () => _showBulkAwardDialog(context),
                      style: AppButtonStyle.gold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, color: AppColors.border),
              
              // Maintenance Mode Stream
              StreamBuilder<Map<String, dynamic>>(
                stream: widget.db.listenGlobalSettings(),
                builder: (ctx, snap) {
                  if (snap.hasError) return const Text('Error loading settings.', style: TextStyle(color: AppColors.ruby));
                  final data = snap.data ?? {};
                  final isMaint = data['maintenance'] == true;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const CircleAvatar(backgroundColor: AppColors.navyLight, child: Icon(Icons.build_circle_outlined, color: AppColors.ruby)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Maintenance Mode', style: TextStyle(color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('Prevents user logins and displays a maintenance message.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Switch(
                        value: isMaint,
                        activeTrackColor: AppColors.ruby,
                        onChanged: (v) async {
                          try {
                            await widget.db.updateGlobalSettings({'maintenance': v});
                            widget.toast(v ? 'App is in maintenance mode' : 'App is back online');
                          } catch (e) {
                            widget.toast('❌ $e');
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.saffron.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.account_balance, color: AppColors.saffron, size: 18),
                SizedBox(width: 8),
                Text('Bank Payment Settings', style: TextStyle(color: AppColors.saffron, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              const Text('These details are shown to users when they buy coins.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Divider(height: 24, color: AppColors.border),
              StreamBuilder<Map<String, dynamic>>(
                stream: widget.db.listenGlobalSettings(),
                builder: (ctx, snap) {
                  if (snap.hasError) return const Text('Error loading settings.', style: TextStyle(color: AppColors.ruby));
                  final data = snap.data ?? {};
                  return Column(children: [
                    _SettingField(
                      label: 'Bank Name',
                      value: data['bankName'] ?? '',
                      hint: 'e.g. Nepal Investment Bank',
                      onSave: (v) => widget.db.updateGlobalSettings({'bankName': v.trim()}).then((_) => widget.toast('✅ Bank Name saved')),
                    ),
                    const SizedBox(height: 14),
                    _SettingField(
                      label: 'Account Number',
                      value: data['accountNo'] ?? '',
                      hint: 'e.g. 0012345678901',
                      onSave: (v) => widget.db.updateGlobalSettings({'accountNo': v.trim()}).then((_) => widget.toast('✅ Account Number saved')),
                    ),
                    const SizedBox(height: 14),
                    _SettingField(
                      label: 'Account Name',
                      value: data['accountName'] ?? '',
                      hint: 'e.g. SarkariSewa Pvt. Ltd.',
                      onSave: (v) => widget.db.updateGlobalSettings({'accountName': v.trim()}).then((_) => widget.toast('✅ Account Name saved')),
                    ),
                    const SizedBox(height: 14),
                    _SettingField(
                      label: 'QR Code URL',
                      value: data['bankQrUrl'] ?? '',
                      hint: 'Paste Cloudinary image URL of QR code',
                      onSave: (v) => widget.db.updateGlobalSettings({'bankQrUrl': v.trim()}).then((_) => widget.toast('✅ QR Code URL saved')),
                    ),
                  ]);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cloudinary Integration', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Required for in-app image uploading (Course covers, emojis, etc.)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Divider(height: 24, color: AppColors.border),
              
              StreamBuilder<Map<String, dynamic>>(
                stream: widget.db.listenGlobalSettings(),
                builder: (ctx, snap) {
                  if (snap.hasError) return const Text('Error loading settings.', style: TextStyle(color: AppColors.ruby));
                  final data = snap.data ?? {};
                  final cName = data['cloudinaryName'] ?? '';
                  final cPreset = data['cloudinaryPreset'] ?? '';
                  
                  return Column(
                    children: [
                      _SettingField(
                        label: 'Cloud Name',
                        value: cName,
                        hint: 'e.g. dfxy9qwer',
                        onSave: (val) => widget.db.updateGlobalSettings({'cloudinaryName': val.trim()}).then((_) => widget.toast('✅ Cloud Name saved')),
                      ),
                      const SizedBox(height: 16),
                      _SettingField(
                        label: 'Unsigned Upload Preset',
                        value: cPreset,
                        hint: 'e.g. my_unsigned_preset',
                        onSave: (val) => widget.db.updateGlobalSettings({'cloudinaryPreset': val.trim()}).then((_) => widget.toast('✅ Upload Preset saved')),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingField extends StatefulWidget {
  final String label;
  final String value;
  final String hint;
  final Function(String) onSave;

  const _SettingField({required this.label, required this.value, required this.hint, required this.onSave});

  @override
  State<_SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<_SettingField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SettingField oldWidget) {
    if (oldWidget.value != widget.value) {
      _ctrl.text = widget.value;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(widget.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled: true, fillColor: AppColors.navy,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.save_outlined, color: AppColors.emerald, size: 20),
          tooltip: 'Save setting',
          onPressed: () => widget.onSave(_ctrl.text),
        )
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 9. ANALYTICS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _AnalyticsTab extends StatefulWidget {
  final FirestoreService db;
  const _AnalyticsTab(this.db);
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> with SingleTickerProviderStateMixin {
  late final TabController _innerTabs;

  @override
  void initState() {
    super.initState();
    _innerTabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _innerTabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: AppColors.navyMid,
      child: TabBar(
        controller: _innerTabs,
        isScrollable: true,
        tabs: const [
          Tab(text: '📊 Overview'),
          Tab(text: '📈 Trends'),
          Tab(text: '🏆 Frequent'),
          Tab(text: '🔍 Per-User'),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    ),
    Expanded(child: TabBarView(
      controller: _innerTabs,
      children: [
        _OverviewSubTab(widget.db),
        const _TrendsSubTab(),
        _FrequentUsersSubTab(widget.db),
        _PerUserSubTab(widget.db),
      ],
    )),
  ]);
}

// ── Overview sub-tab ──────────────────────────────────────────────────────────
class _OverviewSubTab extends StatelessWidget {
  final FirestoreService db;
  const _OverviewSubTab(this.db);

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: db.getAnalyticsOverview(),
    builder: (ctx, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
      final s = snap.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('📊 Platform Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
          children: [
            _StatCard('Total Users',    '${s['users']}',        Icons.people,      AppColors.violet),
            _StatCard('Courses',        '${s['courses']}',      Icons.menu_book,   AppColors.sky),
            _StatCard('Tests Taken',    '${s['testsTaken']}',   Icons.quiz,        AppColors.saffron),
            _StatCard('Enrollments',    '${s['activeOrders']}', Icons.school,      AppColors.emerald),
            _StatCard('Transactions',   '${s['transactions']}', Icons.receipt,     AppColors.gold),
          ],
        ),
        const SizedBox(height: 22),
        const Text('📈 User Signups — Last 30 Days', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(4, 16, 20, 4),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: _SignupChart(db),
        ),
        const SizedBox(height: 22),
        const Text('👥 User Distribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        _RoleDistributionWidget(db),
      ]);
    },
  );
}

class _SignupChart extends StatelessWidget {
  final FirestoreService db;
  const _SignupChart(this.db);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: db.getRecentSignups(30),
    builder: (ctx, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron, strokeWidth: 2));
      final users = snap.data!;
      final now = DateTime.now();
      final dailyCounts = List.filled(30, 0);
      for (final u in users) {
        final created = u['createdAt'];
        DateTime? date;
        if (created is Timestamp) { date = created.toDate(); }
        else if (created is DateTime) { date = created; }
        if (date == null) continue;
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 30) { dailyCounts[29 - diff]++; }
      }
      final maxY = (dailyCounts.reduce((a, b) => a > b ? a : b).toDouble() + 2).clamp(3.0, double.infinity);
      return LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 28, interval: 5,
            getTitlesWidget: (v, _) {
              if (v.toInt() % 5 != 0) return const SizedBox();
              final daysAgo = 29 - v.toInt();
              return Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(daysAgo == 0 ? 'Today' : '-${daysAgo}d',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9)));
            })),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)))),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: 29, minY: 0, maxY: maxY,
        lineBarsData: [LineChartBarData(
          spots: List.generate(30, (i) => FlSpot(i.toDouble(), dailyCounts[i].toDouble())),
          isCurved: true, color: AppColors.emerald, barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.emerald.withAlpha(30)),
        )],
      ));
    },
  );
}

class _RoleDistributionWidget extends StatelessWidget {
  final FirestoreService db;
  const _RoleDistributionWidget(this.db);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: db.listenUsers(),
    builder: (ctx, snap) {
      if (!snap.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.saffron, strokeWidth: 2)));
      final users = snap.data!;
      final roleCounts = <String, int>{};
      final tierCounts = <String, int>{};
      for (final u in users) {
        final r = u['role'] as String? ?? 'student';
        final ti = u['tier'] as String? ?? 'free';
        roleCounts[r]  = (roleCounts[r]  ?? 0) + 1;
        tierCounts[ti] = (tierCounts[ti] ?? 0) + 1;
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [
          if ((roleCounts['super_admin'] ?? 0) > 0)
            _DistChip('👑 Super Admin', roleCounts['super_admin']!, AppColors.ruby),
          _DistChip('🔑 Admin',   roleCounts['admin']    ?? 0, AppColors.violet),
          _DistChip('👩‍🏫 Teacher', roleCounts['teacher']  ?? 0, AppColors.sky),
          _DistChip('🎓 Student', roleCounts['student']  ?? 0, AppColors.emerald),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          _DistChip('🥇 Gold',   tierCounts['gold']   ?? 0, AppColors.gold),
          _DistChip('🥈 Silver', tierCounts['silver'] ?? 0, AppColors.sky),
          _DistChip('🆓 Free',   tierCounts['free']   ?? 0, AppColors.textMuted),
        ]),
      ]);
    },
  );
}

class _DistChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _DistChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(77))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(label,    style: TextStyle(color: color, fontSize: 10)),
    ]),
  );
}

// ── Frequent Users sub-tab ────────────────────────────────────────────────────
class _FrequentUsersSubTab extends StatelessWidget {
  final FirestoreService db;
  const _FrequentUsersSubTab(this.db);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: db.getTopActiveUsers(20),
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
      if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.ruby)));
      final users = snap.data ?? [];
      if (users.isEmpty) return const Center(child: Text('No test activity yet.', style: TextStyle(color: AppColors.textMuted)));
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (_, i) {
          final u = users[i];
          final testCount = u['testCount'] as int? ?? 0;
          final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}.';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i < 3 ? AppColors.gold.withAlpha(80) : AppColors.border)),
            child: Row(children: [
              Text(medal, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 16, backgroundColor: AppColors.primary.withAlpha(51),
                child: Text((u['name'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                Text(u['email'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$testCount', style: const TextStyle(color: AppColors.saffron, fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('tests', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ]),
            ]),
          );
        },
      );
    },
  );
}

// ── Per-User sub-tab ──────────────────────────────────────────────────────────
class _PerUserSubTab extends StatefulWidget {
  final FirestoreService db;
  const _PerUserSubTab(this.db);
  @override
  State<_PerUserSubTab> createState() => _PerUserSubTabState();
}

class _PerUserSubTabState extends State<_PerUserSubTab> {
  String _search = '';
  Map<String, dynamic>? _selectedUser;
  Map<String, dynamic>? _activity;
  bool _loadingActivity = false;

  Future<void> _loadUser(Map<String, dynamic> user) async {
    setState(() { _selectedUser = user; _loadingActivity = true; });
    try {
      final data = await widget.db.getUserActivityData(user['id']);
      if (mounted) setState(() { _activity = data; _loadingActivity = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingActivity = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedUser != null) return _buildDetail();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(
            hintText: '🔍 Search user by name or email…',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true, fillColor: AppColors.navyMid,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
        ),
      ),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.db.listenUsers(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
          if (_search.isEmpty) return const Center(child: Text('Type to search users', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
          final users = snap.data!.where((u) =>
            (u['name'] ?? '').toString().toLowerCase().contains(_search) ||
            (u['email'] ?? '').toString().toLowerCase().contains(_search)).toList();
          if (users.isEmpty) return const Center(child: Text('No matching users.', style: TextStyle(color: AppColors.textMuted)));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              return GestureDetector(
                onTap: () => _loadUser(u),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 17, backgroundColor: AppColors.primary.withAlpha(51),
                      child: Text((u['name'] ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(u['email'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ])),
                    Text(u['role'] ?? 'student', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                  ]),
                ),
              );
            },
          );
        },
      )),
    ]);
  }

  Widget _buildDetail() {
    final u = _selectedUser!;
    final tests = (_activity?['tests'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final txns  = (_activity?['transactions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(children: [
      Container(
        color: AppColors.navyMid,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMuted, size: 20),
            onPressed: () => setState(() { _selectedUser = null; _activity = null; }),
            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 8),
          Expanded(child: Text(u['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(31), borderRadius: BorderRadius.circular(20)),
            child: Text(u['role'] ?? 'student', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
      ),
      Expanded(child: _loadingActivity
        ? const Center(child: CircularProgressIndicator(color: AppColors.saffron))
        : ListView(padding: const EdgeInsets.all(16), children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              Row(children: [
                CircleAvatar(
                  radius: 22, backgroundColor: AppColors.saffron.withAlpha(51),
                  child: Text((u['name'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppColors.saffron, fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(u['email'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                _InfoChip('🪙 ${u['coins'] ?? 0}', AppColors.gold),
                _InfoChip('⭐ ${u['points'] ?? 0} pts', AppColors.violet),
                _InfoChip(_tierLabel(u['tier'] ?? 'free'), AppColors.sky),
                _InfoChip('📚 ${(u['enrolledCourses'] as List?)?.length ?? 0} courses', AppColors.emerald),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          // Badges
          if ((u['badges'] as List?)?.isNotEmpty == true) ...[
            _SectionLabel('🎖 Badges', (u['badges'] as List).length),
            Wrap(spacing: 6, runSpacing: 4,
              children: (u['badges'] as List).map((b) => Chip(
                label: Text('$b', style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.gold.withAlpha(26),
                side: BorderSide(color: AppColors.gold.withAlpha(77)))).toList()),
            const SizedBox(height: 12),
          ],
          // Test results
          _SectionLabel('📝 Recent Test Results', tests.length),
          if (tests.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No test data.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
          else
            ...tests.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.navyMid, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(child: Text('Test · ${(t['testId'] ?? '?').toString().substring(0, 6)}…', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
                Text('${t['score']} / ${t['totalQuestions']}', style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            )),
          const SizedBox(height: 12),
          // Transactions
          _SectionLabel('💰 Recent Transactions', txns.length),
          if (txns.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No transactions.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
          else
            ...txns.map((tx) {
              final coins = tx['coins'] as int? ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.navyMid, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Expanded(child: Text(tx['description'] ?? '',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${coins >= 0 ? "+" : ""}$coins',
                    style: TextStyle(color: coins >= 0 ? AppColors.emerald : AppColors.ruby, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              );
            }),
        ])),
    ]);
  }

  String _tierLabel(String tier) => switch (tier) {
    'gold'   => '🥇 Gold',
    'silver' => '🥈 Silver',
    _        => '🆓 Free',
  };
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  const _SectionLabel(this.title, this.count);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: AppColors.saffron.withAlpha(31), borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: const TextStyle(color: AppColors.saffron, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 10. ACCESS CONTROL TAB (Super Admin only)
// ═══════════════════════════════════════════════════════════════════════════════
class _AccessControlTab extends StatefulWidget {
  final FirestoreService db;
  final Function(String) toast;
  const _AccessControlTab(this.db, this.toast);
  @override
  State<_AccessControlTab> createState() => _AccessControlTabState();
}

class _AccessControlTabState extends State<_AccessControlTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) => Column(children: [
    // Header banner
    Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.ruby.withAlpha(18),
        border: Border(bottom: BorderSide(color: AppColors.ruby.withAlpha(50)))),
      child: Row(children: [
        const Icon(Icons.shield_outlined, color: AppColors.ruby, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('👑 Access Control', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ruby)),
          Text('Assign roles, tiers and feature flags for every user.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
      ]),
    ),
    // Search
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: '🔍 Search users…',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          filled: true, fillColor: AppColors.navyMid,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
        ),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.db.listenUsers(),
      builder: (ctx, snap) {
        if (snap.hasError) return _errorView('users', snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.saffron));
        final users = snap.data!.where((u) {
          if (_search.isEmpty) return true;
          return (u['name'] ?? '').toString().toLowerCase().contains(_search) ||
                 (u['email'] ?? '').toString().toLowerCase().contains(_search);
        }).toList()
          ..sort((a, b) {
            const order = ['super_admin', 'admin', 'teacher', 'student'];
            final ai = order.indexOf(a['role'] ?? 'student');
            final bi = order.indexOf(b['role'] ?? 'student');
            return ai.compareTo(bi);
          });
        if (users.isEmpty) return const Center(child: Text('No matching users.', style: TextStyle(color: AppColors.textMuted)));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: users.length,
          itemBuilder: (_, i) => _AccessControlCard(users[i], widget.db, widget.toast),
        );
      },
    )),
  ]);
}

class _AccessControlCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final FirestoreService db;
  final Function(String) toast;
  const _AccessControlCard(this.user, this.db, this.toast);

  static const _roles = ['student', 'teacher', 'admin', 'super_admin'];
  static const _tiers = ['free', 'silver', 'gold'];

  Color _roleColor(String role) => switch (role) {
    'super_admin' => AppColors.ruby,
    'admin'       => AppColors.violet,
    'teacher'     => AppColors.sky,
    _             => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final role          = user['role']          as String? ?? 'student';
    final tier          = user['tier']          as String? ?? 'free';
    final writingAccess = user['writingAccess'] as bool?   ?? false;
    final groupAccess   = user['groupAccess']   as bool?   ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: role == 'super_admin'
          ? AppColors.ruby.withAlpha(100)
          : role == 'admin' ? AppColors.violet.withAlpha(60) : AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // User header
        Row(children: [
          CircleAvatar(
            radius: 17, backgroundColor: _roleColor(role).withAlpha(51),
            child: Text((user['name'] ?? 'U').substring(0, 1).toUpperCase(),
              style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.w700, fontSize: 13))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
            Text(user['email'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _roleColor(role).withAlpha(31), borderRadius: BorderRadius.circular(20)),
            child: Text(
              role == 'super_admin' ? '👑 Super Admin' : role.toUpperCase(),
              style: TextStyle(color: _roleColor(role), fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ]),
        const Divider(color: AppColors.border, height: 16),
        // Role + Tier controls
        Row(children: [
          _DropLabel('Role'),
          const SizedBox(width: 4),
          _AdminDropdown<String>(
            value: role,
            items: _roles,
            onChanged: (v) async {
              if (v == null) return;
              final ok = await _confirm(context, 'Set ${user['name']}\'s role to "$v"?\n\n${v == 'super_admin' ? '⚠ This grants full platform control.' : ''}');
              if (!ok) return;
              try { await db.updateUserDoc(user['id'], {'role': v}); toast('✅ Role → $v'); }
              catch (e) { toast('❌ $e'); }
            },
          ),
          const SizedBox(width: 16),
          _DropLabel('Tier'),
          const SizedBox(width: 4),
          _AdminDropdown<String>(
            value: tier,
            items: _tiers,
            onChanged: (v) async {
              if (v == null) return;
              try { await db.updateUserDoc(user['id'], {'tier': v}); toast('✅ Tier → $v'); }
              catch (e) { toast('❌ $e'); }
            },
          ),
        ]),
        const SizedBox(height: 10),
        // Feature flags row
        Row(children: [
          const Icon(Icons.edit_note, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          const Text('Writing', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Transform.scale(scale: 0.75, child: Switch(
            value: writingAccess, activeTrackColor: AppColors.emerald,
            onChanged: (v) async {
              try { await db.updateUserDoc(user['id'], {'writingAccess': v}); toast('✅ Writing ${v ? "on" : "off"}'); }
              catch (e) { toast('❌ $e'); }
            },
          )),
          const SizedBox(width: 8),
          const Icon(Icons.group_outlined, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          const Text('Groups', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Transform.scale(scale: 0.75, child: Switch(
            value: groupAccess, activeTrackColor: AppColors.sky,
            onChanged: (v) async {
              try { await db.updateUserDoc(user['id'], {'groupAccess': v}); toast('✅ Group access ${v ? "on" : "off"}'); }
              catch (e) { toast('❌ $e'); }
            },
          )),
          const Spacer(),
          Text('🪙 ${user['coins'] ?? 0}', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('⭐ ${user['points'] ?? 0}', style: const TextStyle(color: AppColors.violet, fontSize: 11)),
        ]),
      ]),
    );
  }
}

