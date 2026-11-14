import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';

extension PriorityUi on Priority {
  Color color(BuildContext context) {
    final p = context.palette;
    switch (this) {
      case Priority.high:
        return Theme.of(context).colorScheme.error;
      case Priority.medium:
        return p.isTerminal ? p.warning : const Color(0xFFFFD166);
      case Priority.low:
        return p.accent;
    }
  }

  /// "P1 · HIGH" style tag from the detail screen's priority pill.
  String get tag {
    switch (this) {
      case Priority.high:
        return 'P1 · HIGH';
      case Priority.medium:
        return 'P2 · MEDIUM';
      case Priority.low:
        return 'P3 · LOW';
    }
  }
}

class PriorityDot extends StatelessWidget {
  const PriorityDot(this.priority, {super.key, this.size = 6});
  final Priority priority;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: priority.color(context), shape: BoxShape.circle),
      );
}

/// Pill with a status dot; the dot pulses for High (like the "P1 Critical"
/// badge). Tap to change priority.
class PriorityBadge extends StatefulWidget {
  const PriorityBadge({super.key, required this.priority, this.onTap});
  final Priority priority;
  final VoidCallback? onTap;
  @override
  State<PriorityBadge> createState() => _PriorityBadgeState();
}

class _PriorityBadgeState extends State<PriorityBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PriorityBadge old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.priority == Priority.high) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = widget.priority.color(context);
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 1 - 0.55 * _c.value),
                shape: BoxShape.circle,
                boxShadow: widget.priority == Priority.high
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.6 * _c.value),
                            blurRadius: 6)
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(widget.priority.tag,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          if (widget.onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 14, color: color),
          ],
        ]),
      ),
    );
  }
}
