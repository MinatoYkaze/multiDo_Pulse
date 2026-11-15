import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Segmented control with a spring-sliding pill (`selectSegmentTab` in
/// projects_lists_with_animated_swipe_shimmer).
class SlidingSegmented extends StatelessWidget {
  const SlidingSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final r = p.isTerminal ? 4.0 : 12.0;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.usesGlass
            ? (p.isDark ? const Color(0xCC1F1F24) : const Color(0xFFE2E6EC))
            : p.surface1,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: p.border),
      ),
      child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth / labels.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.25, 1.25, 0.4, 1),
            left: w * index,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(r - 2),
                border: Border.all(color: p.border),
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: t.labelLarge!.copyWith(
                        color: i == index ? p.textPrimary : p.textMuted,
                        fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
