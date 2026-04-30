// lib/widgets/app_card.dart
//
// Reusable card surface with consistent radius/border/shadow.
// Use this instead of hand-rolled `Container(decoration: BoxDecoration(...))`
// blocks so all surfaces share the same elevation language.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

enum AppCardElevation { flat, sm, md, lg }

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final BorderRadiusGeometry? borderRadius;
  final AppCardElevation elevation;
  final BoxBorder? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.x5),
    this.margin,
    this.color,
    this.gradient,
    this.onTap,
    this.borderRadius,
    this.elevation = AppCardElevation.sm,
    this.border,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  List<BoxShadow> _shadowFor(AppCardElevation e) {
    switch (e) {
      case AppCardElevation.flat: return const [];
      case AppCardElevation.sm:   return AppShadows.sm;
      case AppCardElevation.md:   return AppShadows.md;
      case AppCardElevation.lg:   return AppShadows.lg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.lg);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scaleByDouble(_pressed ? 0.98 : 1.0, _pressed ? 0.98 : 1.0, 1.0, 1.0),
      transformAlignment: Alignment.center,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.gradient == null ? (widget.color ?? AppColors.cardBg) : null,
        gradient: widget.gradient,
        borderRadius: radius,
        border: widget.border ??
            (widget.gradient == null
                ? Border.all(color: AppColors.border, width: 1)
                : null),
        boxShadow: _shadowFor(widget.elevation),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: card,
      ),
    );
  }
}
