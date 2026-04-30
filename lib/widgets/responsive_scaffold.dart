import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/strings.dart';
import '../theme.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.appBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().lang;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final navItems = [
      (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: t('nav.home', lang), path: '/dashboard'),
      (icon: Icons.history_edu_outlined, active: Icons.history_edu, label: t('nav.pyq', lang), path: '/pyq'),
      (icon: Icons.assignment_outlined, active: Icons.assignment, label: t('nav.mock', lang), path: '/mock'),
      (icon: Icons.live_tv_outlined, active: Icons.live_tv, label: t('nav.live', lang), path: '/live'),
      (icon: Icons.person_outlined, active: Icons.person, label: t('nav.profile', lang), path: '/profile'),
    ];

    if (isDesktop) {
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.navy,
              selectedIndex: currentIndex,
              onDestinationSelected: (idx) {
                HapticFeedback.selectionClick();
                context.go(navItems[idx].path);
              },
              selectedIconTheme: const IconThemeData(color: AppColors.saffron),
              unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
              selectedLabelTextStyle: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: AppColors.textMuted),
              labelType: NavigationRailLabelType.all,
              destinations: navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.active),
                  label: Text(item.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: AppBottomNav(currentIndex: currentIndex),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().lang;

    final items = [
      (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: t('nav.home', lang), path: '/dashboard'),
      (icon: Icons.history_edu_outlined, active: Icons.history_edu, label: t('nav.pyq', lang), path: '/pyq'),
      (icon: Icons.assignment_outlined, active: Icons.assignment, label: t('nav.mock', lang), path: '/mock'),
      (icon: Icons.live_tv_outlined, active: Icons.live_tv, label: t('nav.live', lang), path: '/live'),
      (icon: Icons.person_outlined, active: Icons.person, label: t('nav.profile', lang), path: '/profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyMid,
        border: const Border(top: BorderSide(color: AppColors.borderSoft, width: 1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: _NavItem(
                  icon: item.icon,
                  activeIcon: item.active,
                  label: item.label,
                  isActive: isActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go(item.path);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            gradient: widget.isActive
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withAlpha(22),
                      AppColors.violet.withAlpha(18),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  widget.isActive ? widget.activeIcon : widget.icon,
                  key: ValueKey(widget.isActive),
                  color: widget.isActive
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isActive
                      ? AppColors.primary
                      : AppColors.textMuted,
                  letterSpacing: 0.1,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
