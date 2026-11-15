import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Progress track whose filled part has a white highlight sweeping across it
/// (`animate-shimmer` + width transition from the Projects designs).
class ShimmerProgressBar extends StatefulWidget {
  const ShimmerProgressBar(
      {super.key, required this.value, this.height = 6, this.color, this.glow = true});
  final double value; // 0..1
  final double height;
  final Color? color;
  final bool glow;

  @override
  State<ShimmerProgressBar> createState() => _ShimmerProgressBarState();
}

class _ShimmerProgressBarState extends State<ShimmerProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = widget.color ?? p.accent;
    final r = BorderRadius.circular(p.isTerminal ? 2 : 999);
    return LayoutBuilder(builder: (_, c) {
      return Container(
        height: widget.height,
        width: c.maxWidth,
        decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: r),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: widget.value.clamp(0, 1)),
          duration: const Duration(milliseconds: 1000),
          curve: const Cubic(0.16, 1, 0.3, 1),
          builder: (_, v, __) {
            final w = c.maxWidth * v;
            if (w < 1) return const SizedBox.shrink();
            return Container(
              width: w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: r,
                boxShadow: widget.glow
                    ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: r,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => Align(
                    alignment: Alignment(-1.6 + 3.2 * _c.value, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Color(0x66FFFFFF),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
