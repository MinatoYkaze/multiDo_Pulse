import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated strike-through: a 1.5px line sweeps across the title
/// (`.strikethrough-text::after` in today_tasks_2). Single line only.
class StrikeText extends StatelessWidget {
  const StrikeText(this.text,
      {super.key,
      required this.struck,
      required this.style,
      required this.lineColor});
  final String text;
  final bool struck;
  final TextStyle style;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        ellipsis: '…',
        textDirection: Directionality.of(context),
      )..layout(maxWidth: c.maxWidth.isFinite ? c.maxWidth : 10000);
      return Stack(children: [
        AnimatedDefaultTextStyle(
          style: style,
          duration: const Duration(milliseconds: 300),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Positioned(
          left: 0,
          top: tp.height * 0.52,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: struck ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 350),
            curve: const Cubic(0.16, 1, 0.3, 1),
            builder: (_, v, __) =>
                Container(width: tp.width * v, height: 1.5, color: lineColor),
          ),
        ),
      ]);
    });
  }
}

/// Staggered fade/slide/scale-in (`taskEntrance`: 14px, .98 → 1, 500ms).
class Entrance extends StatefulWidget {
  const Entrance(
      {super.key,
      required this.index,
      required this.enabled,
      required this.child});
  final int index;
  final bool enabled;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _c.value = 1;
      return;
    }
    final delay = 40 + 50 * math.min(widget.index, 10).toInt();
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = const Cubic(0.16, 1, 0.3, 1).transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
          ),
        );
      },
    );
  }
}

/// Shared-element title. The flight lerps between the list and detail text
/// styles so the title grows smoothly instead of re-wrapping mid-flight.
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    super.key,
    required this.tag,
    required this.text,
    required this.fromStyle,
    required this.toStyle,
    required this.child,
  });
  final Object tag;
  final String text;
  final TextStyle fromStyle; // list
  final TextStyle toStyle; // detail
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (_, anim, __, ___, ____) => AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Material(
          type: MaterialType.transparency,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle.lerp(fromStyle, toStyle, anim.value),
          ),
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
