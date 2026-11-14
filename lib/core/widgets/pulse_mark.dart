import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Brand glyph from the zip's header: gradient tile + ECG line + live dot.
class PulseMark extends StatefulWidget {
  const PulseMark({super.key, this.size = 36, this.animate = false});
  final double size;
  final bool animate;
  @override
  State<PulseMark> createState() => _PulseMarkState();
}

class _PulseMarkState extends State<PulseMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(p.isTerminal ? 4 : s * 0.28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C2E22), Color(0xFF121C16), Color(0xFF0A0F0C)],
            ),
            border: Border.all(color: p.accent.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                  color: p.accent.withValues(alpha: 0.10 + 0.28 * t),
                  blurRadius: 10 + 26 * t),
            ],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(Icons.show_chart_rounded, size: s * 0.56, color: p.accent),
            Positioned(
              top: s * 0.06,
              right: s * 0.06,
              child: Container(
                width: s * 0.17,
                height: s * 0.17,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: p.accent, blurRadius: 6)],
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
