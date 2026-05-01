// lib/widgets/admin/audit_log_view.dart
//
// Paginated viewer for the `admin_audit_logs` collection. Embed in any
// admin tab. Renders a compact, scannable feed of recent admin actions
// with adminEmail / action / target / time. Tapping an entry opens a
// detail sheet with the before/after JSON snapshots so reviewers can
// answer "what changed?" without leaving the panel.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/audit_service.dart';
import '../../theme.dart';
import '../paginated_list.dart';

class AuditLogView extends StatelessWidget {
  const AuditLogView({super.key, this.padding});

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final svc = AuditService();
    return PaginatedList(
      fetchPage: ({int pageSize = 25, startAfter}) =>
          svc.getPage(pageSize: pageSize, startAfter: startAfter),
      pageSize: 25,
      padding: padding ?? const EdgeInsets.all(AppSpace.x4),
      emptyEmoji: '📜',
      emptyTitle: 'No audit entries yet',
      emptyMessage:
          'Privileged admin actions will appear here as they happen.',
      itemBuilder: (ctx, item, _) => _AuditTile(item: item),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AuditTile({required this.item});

  static const _actionColors = <String, Color>{
    'course.delete':       AppColors.ruby,
    'course.create':       AppColors.emerald,
    'course.update':       AppColors.gold,
    'payment.approve':     AppColors.emerald,
    'payment.reject':      AppColors.ruby,
    'user.role_change':    AppColors.violet,
    'user.coin_adjust':    AppColors.gold,
    'broadcast.push':      AppColors.sky,
    'news.delete':         AppColors.ruby,
  };

  @override
  Widget build(BuildContext context) {
    final action     = (item['action'] ?? 'unknown').toString();
    final adminEmail = (item['adminEmail'] ?? '—').toString();
    final target     = item['target'] as Map<String, dynamic>? ?? const {};
    final ts         = item['createdAt'];
    final color = _actionColors[action] ?? AppColors.primary;

    String when = 'just now';
    try {
      // ts is a Timestamp (from Firestore) — convert defensively.
      final dt = (ts?.toDate() as DateTime?);
      if (dt != null) when = DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(31),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(_iconFor(action), size: 18, color: color),
          ),
        ),
        title: Text(
          action,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${target['kind'] ?? '?'}/${target['id'] ?? '?'}  •  $adminEmail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        trailing: Text(
          when,
          style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11,
          ),
        ),
        onTap: () => _showDetail(context, item),
      ),
    );
  }

  IconData _iconFor(String action) {
    if (action.contains('.delete'))   { return Icons.delete_outline; }
    if (action.contains('.approve'))  { return Icons.check_circle_outline; }
    if (action.contains('.reject'))   { return Icons.cancel_outlined; }
    if (action.contains('role'))      { return Icons.shield_outlined; }
    if (action.contains('coin'))      { return Icons.monetization_on_outlined; }
    if (action.contains('broadcast')) { return Icons.campaign_outlined; }
    if (action.contains('.create'))   { return Icons.add_circle_outline; }
    if (action.contains('.update'))   { return Icons.edit_outlined; }
    return Icons.history;
  }

  void _showDetail(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxxl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(AppSpace.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(item['action'] ?? '',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(item['adminEmail'] ?? '—',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              if (item['before'] != null) _JsonBlock(label: 'Before', data: item['before']),
              if (item['after']  != null) _JsonBlock(label: 'After',  data: item['after']),
              if (item['extra']  != null) _JsonBlock(label: 'Extra',  data: item['extra']),
            ],
          ),
        ),
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  final String label;
  final dynamic data;
  const _JsonBlock({required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      pretty = data.toString();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4,
              )),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
