// lib/widgets/empty_state.dart
//
// Friendly empty / error state widget. Use for "no results", network errors,
// permission-blocked screens, etc. — gives every empty surface a consistent
// look instead of one-off Center+Text blocks.
import 'package:flutter/material.dart';
import '../theme.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    this.emoji = '📭',
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(32),
  });

  /// Pre-baked variant for network / load errors.
  const EmptyState.error({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please check your connection and try again.',
    this.actionLabel = 'Retry',
    required this.onAction,
    this.padding = const EdgeInsets.all(32),
  }) : emoji = '⚠️';

  /// Pre-baked variant for "no items yet".
  const EmptyState.noResults({
    super.key,
    this.title = 'Nothing here yet',
    this.message,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(32),
  }) : emoji = '🔍';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft, width: 1),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: AppSpace.x5),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpace.x2),
              Text(
                message!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.x6),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                style: AppButtonStyle.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
