// lib/widgets/confirm_dialog.dart
//
// Reusable confirmation dialog for destructive admin actions. Has two
// modes:
//
//   1. Standard confirm (Cancel / Confirm)
//   2. Typed confirm — user must type a phrase verbatim before the
//      destructive button enables. Used for high-risk actions like
//      "delete course", "bulk award coins", or "reset user role".
import 'package:flutter/material.dart';
import '../theme.dart';
import 'app_button.dart';

class ConfirmDialog {
  /// Standard confirmation. Returns `true` if the user confirmed.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool danger = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmContent(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
        icon: icon,
        requireTyping: null,
      ),
    );
    return result == true;
  }

  /// Typed confirmation — destructive button stays disabled until the
  /// user types the phrase exactly. Use for irreversible bulk actions.
  static Future<bool> showTyped({
    required BuildContext context,
    required String title,
    required String message,
    required String requireTyping,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmContent(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: true,
        icon: Icons.warning_amber_rounded,
        requireTyping: requireTyping,
      ),
    );
    return result == true;
  }
}

class _ConfirmContent extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final IconData? icon;
  final String? requireTyping;

  const _ConfirmContent({
    required this.title,
    this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.danger,
    this.icon,
    this.requireTyping,
  });

  @override
  State<_ConfirmContent> createState() => _ConfirmContentState();
}

class _ConfirmContentState extends State<_ConfirmContent> {
  final _ctrl = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_recheck);
  }

  void _recheck() {
    final m = widget.requireTyping == null
        ? true
        : _ctrl.text == widget.requireTyping;
    if (m != _matches) setState(() => _matches = m);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? AppColors.ruby : AppColors.primary;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.icon != null)
                Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(31),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: accent, size: 28),
                ),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.message!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.requireTyping != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Type "${widget.requireTyping}" to confirm:',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.requireTyping,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.x6),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: widget.cancelLabel,
                      onPressed: () => Navigator.of(context).pop(false),
                      style: AppButtonStyle.secondary,
                      fullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: widget.confirmLabel,
                      onPressed: _matches
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      style: widget.danger
                          ? AppButtonStyle.danger
                          : AppButtonStyle.primary,
                      fullWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
