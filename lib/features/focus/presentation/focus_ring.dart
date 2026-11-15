import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Progress ring with a soft glow under the arc and a glowing pointer dot
/// (`timerProgressRing` + `pointerGlowGroup` in the pulsing-timer design).
class FocusRingPainter extends CustomPainter {
  FocusRingPainter({
    required this.progress,
    required this.pulse,
    required this.accent,
    required this.track,
    required this.active,
  });
  final double progress; // 0..1 elapsed
  final double pulse; // 0..1 breathing value
  final Color accent;
  final Color track;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: c, radius: r);

    // outer breathing halo
    if (active) {
      canvas.drawCircle(
        c,
        r + 6,
        Paint()
          ..color = accent.withValues(alpha: 0.05 + 0.07 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18 + 10 * pulse
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 + 10 * pulse),
      );
    }

    // track
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0.001) return;

    // glow under the arc
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = accent.withValues(alpha: 0.35 + 0.15 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * pulse));

    // arc
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            colors: [accent.withValues(alpha: 0.35), accent],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);

    // pointer
    final a = -math.pi / 2 + sweep;
    final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    canvas.drawCircle(
        p,
        9 + 4 * pulse,
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(p, 5, Paint()..color = Colors.white);
    canvas.drawCircle(p, 3, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(FocusRingPainter o) =>
      o.progress != progress || o.pulse != pulse || o.active != active || o.accent != accent;
}
