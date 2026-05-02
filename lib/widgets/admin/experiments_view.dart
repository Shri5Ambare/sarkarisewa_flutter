// lib/widgets/admin/experiments_view.dart
//
// Phase 4.5 — A/B test framework admin panel.
// Collections: experiments { key, name, description, variants[], audience, active }
// Lightweight — the client SDK reads experiments and allocates users client-side.
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class ExperimentsView extends StatelessWidget {
  const ExperimentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirestoreService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Experiment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => _showEditDialog(context, db, null),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.listenExperiments(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: AppColors.ruby)));
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final exps = snap.data!;
          if (exps.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🧪', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('No experiments yet.',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'Create an experiment to start A/B testing features.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: exps.length,
            itemBuilder: (_, i) =>
                _ExperimentCard(exp: exps[i], db: db),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, FirestoreService db,
      Map<String, dynamic>? existing) {
    final keyCtrl =
        TextEditingController(text: existing?['key'] ?? '');
    final nameCtrl =
        TextEditingController(text: existing?['name'] ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] ?? '');
    final variantsCtrl = TextEditingController(
        text: (existing?['variants'] as List?)?.join(', ') ?? 'control, treatment');
    bool active = existing?['active'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyMid,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? '🧪 New Experiment' : '✏️ Edit Experiment',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              _field('Key (e.g. new_dashboard)', keyCtrl,
                  enabled: existing == null),
              const SizedBox(height: 10),
              _field('Name', nameCtrl),
              const SizedBox(height: 10),
              _field('Description', descCtrl, maxLines: 2),
              const SizedBox(height: 10),
              _field('Variants (comma-separated)', variantsCtrl),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Active',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: active,
                  activeTrackColor: AppColors.emerald,
                  onChanged: (v) => setLS(() => active = v),
                ),
              ]),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final data = {
                    'key':         keyCtrl.text.trim(),
                    'name':        nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'variants':    variantsCtrl.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(),
                    'active': active,
                  };
                  await db.saveExperiment(existing?['id'], data);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Create' : 'Update'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String hint, TextEditingController ctrl,
      {int maxLines = 1, bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.navyLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _ExperimentCard extends StatelessWidget {
  final Map<String, dynamic> exp;
  final FirestoreService db;
  const _ExperimentCard({required this.exp, required this.db});

  @override
  Widget build(BuildContext context) {
    final active = exp['active'] as bool? ?? false;
    final variants =
        (exp['variants'] as List?)?.map((v) => v.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
            color: active
                ? AppColors.emerald.withAlpha(80)
                : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.emerald : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exp['name'] ?? exp['key'] ?? 'Experiment',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary),
            ),
          ),
          _badge(active ? 'ACTIVE' : 'PAUSED',
              active ? AppColors.emerald : AppColors.textMuted),
        ]),
        const SizedBox(height: 4),
        Text(
          'key: ${exp['key'] ?? '—'}',
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontFamily: 'monospace'),
        ),
        if ((exp['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(exp['description'],
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: variants
              .map((v) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(v,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _ActionBtn(
            label: active ? 'Pause' : 'Activate',
            color: active ? AppColors.gold : AppColors.emerald,
            onTap: () async {
              await db.saveExperiment(exp['id'], {'active': !active});
            },
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            label: 'Edit',
            color: AppColors.sky,
            onTap: () => ExperimentsView()
                ._showEditDialog(context, db, exp),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            label: 'Delete',
            color: AppColors.ruby,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete experiment?'),
                  content: Text(
                      'This will delete "${exp['name'] ?? exp['key']}". '
                      'Clients using this key will fall back to control.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.ruby))),
                  ],
                ),
              );
              if (ok == true) await db.deleteExperiment(exp['id']);
            },
          ),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      );
}
