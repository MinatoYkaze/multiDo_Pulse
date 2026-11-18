import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

class _Particle {
  const _Particle(this.angle, this.distance, this.size, this.color);
  final double angle;
  final double distance;
  final double size;
  final Color color;
}

/// Checkbox from `today_tasks_2`: spring "pop", stroke-drawn checkmark and an
/// emerald particle burst. Circle in Apple Precision, 2px square in Pulse.
/// With [rich] = false it only cross-fades (the plain `today_tasks_1` look).
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
    this.rich = true,
  });
  final bool value;
  final VoidCallback onChanged;
  final double size;
  final bool rich;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with TickerProviderStateMixin {
  static const _burstColors = [
    Color(0xFF39FF94),
    Color(0xFF00E37E),
    Color(0xFFA5FFBD),
    Color(0xFF78FFD6),
    Color(0xFFFFFFFF),
  ];

  late final AnimationController _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.value ? 1 : 0);
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620));

  // 0.82 → 1.18 → 1.0 (the CSS `checkboxPop` keyframes)
  final _popTween = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween<double>(begin: 0.82, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55),
    TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45),
  ]);

  List<_Particle> _particles = const [];
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant AnimatedCheck old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    if (widget.value) {
      _draw.forward(from: 0);
      if (widget.rich) {
        _pop.forward(from: 0);
        _spawn();
      }
    } else {
      _draw.reverse();
    }
  }

  void _spawn() {
    final r = math.Random();
    _particles = List.generate(8, (i) {
      final angle = (i * 45 + r.nextDouble() * 24 - 12) * math.pi / 180;
      return _Particle(
        angle,
        r.nextDouble() * 28 + 22,
        r.nextDouble() * 3.5 + 3,
        _burstColors[r.nextInt(_burstColors.length)],
      );
    });
    _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    _pop.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onChanged,
      child: Container(
        width: 48,
        height: 48,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.rich)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (_, __) => CustomPaint(
                        painter: _BurstPainter(_particles, _burst.value)),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: Listenable.merge([_pop, _draw]),
              builder: (_, __) {
                final pop = _pop.isDismissed ? 1.0 : _popTween.evaluate(_pop);
                return Transform.scale(
                  scale: pop,
                  child: AnimatedScale(
                    scale: _pressed ? 0.84 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: _box(p),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(AppPalette p) {
    final done = widget.value;
    final s = widget.size;
    final idle = p.usesGlass
        ? (p.isDark
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.25))
        : p.textMuted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: done ? p.accent : Colors.transparent,
        borderRadius:
            BorderRadius.circular(p.checkboxIsCircle ? s / 2 : p.checkboxRadius),
        border: Border.all(color: done ? p.accent : idle, width: 1.2),
        boxShadow: done
            ? [BoxShadow(color: p.accent.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
      child: CustomPaint(painter: _CheckPainter(_draw.value, p.onAccent)),
    );
  }
}

/// The `20 6 9 17 4 12` polyline from the SVG, drawn progressively.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final k = size.width * 0.62 / 16;
    Offset pt(double x, double y) => Offset(
        size.width / 2 + (x - 12) * k, size.height / 2 + (y - 11.5) * k);
    final a = pt(4, 12), b = pt(9, 17), c = pt(20, 6);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * Curves.easeInOutCubic.transform(progress)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter o) =>
      o.progress != progress || o.color != color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1 || particles.isEmpty) return;
    final c = size.center(Offset.zero);
    final dist = t < 0.4
        ? 0.6 * Curves.easeOutCubic.transform(t / 0.4)
        : 0.6 + 0.4 * ((t - 0.4) / 0.6);
    final scale =
        t < 0.4 ? 0.6 + 0.55 * (t / 0.4) : 1.15 * (1 - (t - 0.4) / 0.6);
    final opacity =
        t < 0.4 ? 1 - 0.1 * (t / 0.4) : 0.9 * (1 - (t - 0.4) / 0.6);
    for (final q in particles) {
      final o = c +
          Offset(math.cos(q.angle), math.sin(q.angle)) * (q.distance * dist);
      final r = q.size / 2 * scale;
      if (r <= 0) continue;
      canvas.drawCircle(
          o,
          r * 2,
          Paint()
            ..color = q.color.withValues(alpha: 0.35 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(o, r,
          Paint()..color = q.color.withValues(alpha: opacity.clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}
