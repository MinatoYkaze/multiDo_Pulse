import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Glass confirmation modal from `projects_lists_with_delete_confirmation_modal`
/// (red icon tile, title, message, destructive button, Cancel). Reused by
/// tasks (Phase 3) and groups (Phase 4). Resolves `true` only on confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required InlineSpan message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.delete_forever_rounded,
  IconData confirmIcon = Icons.delete_outline_rounded,
}) async {
  final res = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      confirmIcon: confirmIcon,
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(
          parent: anim,
          curve: const Cubic(0.16, 1, 0.3, 1),
          reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(curved),
          child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
              child: child),
        ),
      );
    },
  );
  return res ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.confirmIcon,
  });
  final String title;
  final InlineSpan message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final IconData confirmIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final danger = p.isTerminal ? scheme.error : const Color(0xFFEF4444);
    final dangerBtn = p.isTerminal ? scheme.errorContainer : const Color(0xFFDC2626);
    final dangerFg = p.isTerminal ? scheme.onErrorContainer : Colors.white;
    final radius = BorderRadius.circular(p.isTerminal ? 8 : 28);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: p.usesGlass ? 24 : 0, sigmaY: p.usesGlass ? 24 : 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: p.usesGlass
                        ? (p.isDark
                            ? const Color(0xE616181F)
                            : const Color(0xF5FFFFFF))
                        : p.surface2,
                    borderRadius: radius,
                    border: Border.all(
                        color: p.usesGlass
                            ? (p.isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x1A000000))
                            : p.border),
                    boxShadow: [
                      BoxShadow(
                          color: p.isDark
                              ? const Color(0xA6000000)
                              : const Color(0x26000000),
                          blurRadius: 54,
                          offset: const Offset(0, 24)),
                    ],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 16),
                        border: Border.all(color: danger.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                              color: danger.withValues(alpha: 0.18),
                              blurRadius: 20)
                        ],
                      ),
                      child: Icon(icon, size: 26, color: danger),
                    ),
                    const SizedBox(height: 12),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(
                            fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text.rich(
                        message,
                        textAlign: TextAlign.center,
                        style: t.bodySmall
                            ?.copyWith(color: p.textMuted, height: 18 / 13),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: Icon(confirmIcon, size: 19),
                        label: Text(confirmLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: dangerBtn,
                          foregroundColor: dangerFg,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(p.isTerminal ? 4 : 16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: p.usesGlass
                              ? (p.isDark
                                  ? const Color(0xCC232731)
                                  : const Color(0xFFF1F3F6))
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(p.isTerminal ? 4 : 16)),
                        ),
                        child: Text(cancelLabel),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
