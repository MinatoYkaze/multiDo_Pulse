import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Shimmering placeholder rows shown while a list loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.height = 56});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.usesGlass ? const Color(0x0AFFFFFF) : p.surface1;
    final hi = p.usesGlass ? const Color(0x1AFFFFFF) : p.surface3;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      period: const Duration(milliseconds: 1400),
      child: Column(children: [
        for (var i = 0; i < count; i++)
          Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 14),
            ),
          ),
      ]),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecor.card(p),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, color: p.warning, size: 30),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: p.textMuted)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 18),
            border: Border.all(color: p.accent.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: p.accent, size: 26),
        ),
        const SizedBox(height: 14),
        Text(title, style: t.titleMedium, textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: t.bodySmall?.copyWith(color: p.textMuted),
              textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}
