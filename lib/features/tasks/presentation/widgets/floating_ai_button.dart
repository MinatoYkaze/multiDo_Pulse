import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/theme_controller.dart';

class FloatingAIAssistantButton extends ConsumerStatefulWidget {
  const FloatingAIAssistantButton({
    super.key,
    this.visible = true,
  });

  final bool visible;

  @override
  ConsumerState<FloatingAIAssistantButton> createState() =>
      _FloatingAIAssistantButtonState();
}

class _FloatingAIAssistantButtonState extends ConsumerState<FloatingAIAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 3.0, end: 12.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AnimatedScale(
      scale: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.22),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Material(
              color: p.surface2,
              shape: CircleBorder(
                side: BorderSide(
                  color: p.accent.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.5),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  ref.read(hapticsProvider).selection();
                  context.push(Routes.ai);
                },
                child: Tooltip(
                  message: 'AI Assistant',
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: p.accent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
