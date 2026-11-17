import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/focus/presentation/focus_controller.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _items = <_NavItem>[
  _NavItem(Icons.task_alt_rounded, 'Today'),
  _NavItem(Icons.timer_outlined, 'Focus'),
  _NavItem(Icons.folder_outlined, 'Projects'),
  _NavItem(Icons.insights_rounded, 'Analytics'),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A finished focus block pops the milestone screen, whichever tab is open.
    ref.listen(focusControllerProvider.select((s) => s.milestone), (prev, next) {
      if (prev == null && next != null) {
        context.go('/focus/milestone');
      }
    });
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: shell,
      bottomNavigationBar: _GlassNavBar(
        index: shell.currentIndex,
        onTap: (i) {
          ref.read(hapticsProvider).selection();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Balanced vertical padding:
    // Respect system safe area when present (e.g. mobile home indicator);
    // When 0 (e.g. web/desktop), provide 12px bottom padding so items aren't pushed against the screen edge.
    final bottomPadding = bottomInset > 0 ? bottomInset + 4.0 : 12.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: p.base.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: p.border.withValues(alpha: 0.6))),
          ),
          padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: _items[i],
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton(
      {required this.item, required this.selected, required this.onTap});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.accent : p.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? p.accent.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 999),
              boxShadow: selected
                  ? [BoxShadow(color: p.accentGlow, blurRadius: 14)]
                  : null,
            ),
            child: AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 220),
              child: Icon(item.icon, size: 22, color: color),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: color,
                  letterSpacing: 0.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
            child: Text(
              item.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
