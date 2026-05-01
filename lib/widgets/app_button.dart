// lib/widgets/app_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

enum AppButtonStyle { primary, secondary, gold, danger, success, outline, ghost }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppButtonSize size;
  final bool fullWidth;
  final bool loading;
  final IconData? icon;
  final IconData? trailingIcon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.size = AppButtonSize.md,
    this.fullWidth = false,
    this.loading = false,
    this.icon,
    this.trailingIcon,
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
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // Design-system recipe:
  //   .primary   { bg:#5624D0; fg:white; shadow:cta; radius:12 }
  //   .secondary { bg:#F7F9FA; fg:#1C1D1F; }
  //   .gold      { bg:#E59819; fg:white; }
  //   .danger    { bg:#EF4444; fg:white; }
  //   .success   { bg:#10B981; fg:white; }
  //   .outline   { bg:transparent; fg:#5624D0; border:1.5 #5624D0 }
  // Primary uses the SOLID brand color (no gradient on the button surface);
  // gradients are reserved for the splash mark and dashboard avatar.
  ({Color bg, Color fg, Border? border, Gradient? gradient}) _stylePack(AppButtonStyle s) {
    switch (s) {
      case AppButtonStyle.primary:
        return (bg: AppColors.primary, fg: Colors.white, border: null, gradient: null);
      case AppButtonStyle.secondary:
        return (bg: AppColors.navyLight, fg: AppColors.textPrimary,
                border: Border.all(color: AppColors.border), gradient: null);
      case AppButtonStyle.gold:
        return (bg: AppColors.gold, fg: Colors.white, border: null, gradient: null);
      case AppButtonStyle.danger:
        return (bg: AppColors.ruby, fg: Colors.white, border: null, gradient: null);
      case AppButtonStyle.success:
        return (bg: AppColors.emerald, fg: Colors.white, border: null, gradient: null);
      case AppButtonStyle.outline:
        return (bg: Colors.transparent, fg: AppColors.primary,
                border: Border.all(color: AppColors.primary, width: 1.5), gradient: null);
      case AppButtonStyle.ghost:
        return (bg: Colors.transparent, fg: AppColors.primary, border: null, gradient: null);
    }
  }

  ({double padH, double padV, double font, double iconSize}) _sizePack(AppButtonSize s) {
    switch (s) {
      case AppButtonSize.sm: return (padH: 16, padV: 10, font: 13, iconSize: 16);
      case AppButtonSize.md: return (padH: 24, padV: 14, font: 15, iconSize: 18);
      case AppButtonSize.lg: return (padH: 28, padV: 18, font: 16, iconSize: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stylePack(widget.style);
    final z = _sizePack(widget.size);
    final isDisabled = widget.loading || widget.onPressed == null;

    Widget child = widget.loading
        ? SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(color: s.fg, strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: z.iconSize, color: s.fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: s.fg,
                  fontWeight: FontWeight.w600,
                  fontSize: z.font,
                  letterSpacing: 0.1,
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(widget.trailingIcon, size: z.iconSize, color: s.fg),
              ],
            ],
          );

    Widget btn = Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: GestureDetector(
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
            // Disabled opacity 0.55 per design-system spec.
            opacity: isDisabled && !widget.loading ? 0.55 : 1.0,
            child: ConstrainedBox(
              // Accessibility: minimum 48dp tap target (Material/iOS spec).
              constraints: const BoxConstraints(minHeight: 48),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: z.padH, vertical: z.padV),
                decoration: BoxDecoration(
                  color: s.bg,
                  gradient: s.gradient,
                  // Buttons use radius 12 (--radius-lg).
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: s.border,
                  // ONLY the primary CTA casts a shadow.
                  boxShadow: (!isDisabled && widget.style == AppButtonStyle.primary)
                      ? AppShadows.brand
                      : const [],
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );

    return widget.fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
