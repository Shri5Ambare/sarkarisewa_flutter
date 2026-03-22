// lib/widgets/app_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

enum AppButtonStyle { primary, secondary, gold, danger, success, outline }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool fullWidth;
  final bool loading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.fullWidth = false,
    this.loading = false,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (widget.style) {
      AppButtonStyle.primary   => (AppColors.saffron, Colors.white),
      AppButtonStyle.secondary => (AppColors.navyLight, AppColors.textPrimary),
      AppButtonStyle.gold      => (AppColors.gold, AppColors.navy),
      AppButtonStyle.danger    => (AppColors.ruby, Colors.white),
      AppButtonStyle.success   => (AppColors.emerald, Colors.white),
      AppButtonStyle.outline   => (Colors.transparent, AppColors.saffron),
    };

    final isDisabled = widget.loading || widget.onPressed == null;

    Widget child = widget.loading
        ? SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(color: fg, strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: 8)],
              Text(widget.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          );

    Widget btn = GestureDetector(
      onTapDown: isDisabled ? null : (_) => _ctrl.forward(),
      onTapUp: isDisabled ? null : (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled && !widget.loading ? 0.55 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: widget.style == AppButtonStyle.outline
                  ? Border.all(color: AppColors.saffron, width: 1.5)
                  : null,
              boxShadow: (!isDisabled && widget.style == AppButtonStyle.primary)
                  ? [BoxShadow(color: AppColors.saffron.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );

    return widget.fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
