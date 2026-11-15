import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/sliding_segmented.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/presentation/groups_providers.dart';
import '../../tasks/presentation/tasks_controller.dart';
import 'analytics_providers.dart';

const _sliceColors = [
  Color(0xFF39FF94),
  Color(0xFF7DD3FC),
  Color(0xFFFFD166),
  Color(0xFFC4B5FD),
];

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsRange _range = AnalyticsRange.week;

  Future<void> _refresh() async {
    await ref.read(tasksControllerProvider.notifier).refresh();
    await ref.read(groupsControllerProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final data = ref.watch(analyticsProvider(_range));
    final user = ref.watch(currentUserProvider);
    final navPad = MediaQuery.paddingOf(context).bottom;
    final label = switch (_range) {
      AnalyticsRange.week => 'last week',
      AnalyticsRange.month => 'last month',
      AnalyticsRange.year => 'last year',
    };
    final periodDays = switch (_range) {
      AnalyticsRange.week => 7,
      AnalyticsRange.month => 30,
      AnalyticsRange.year => 365,
    };
    final avgPerDay = data.tasksDone / periodDays;
    final focusH = data.focusSeconds / 3600;
    final goalH = data.goalSeconds / 3600;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(title: 'Pulse', subtitle: 'Analytics'),
          Expanded(
            child: RefreshIndicator(
              color: p.accent,
              backgroundColor: p.surface2,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 4, 16, navPad + 96),
                children: [
                  // profile + streak
                  Row(children: [
                    UserAvatar(user: user, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.displayName ?? 'You', style: t.titleMedium),
                        Text('${data.completedTotal} of ${data.totalTasks} tasks complete',
                            style: t.bodySmall),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.local_fire_department_rounded, size: 16, color: p.accent),
                        const SizedBox(width: 4),
                        Text('${data.streak.current}d streak',
                            style: t.labelMedium?.copyWith(
                                color: p.accent, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SlidingSegmented(
                    labels: const ['This Week', 'Month', 'Year'],
                    index: _range.index,
                    onChanged: (i) {
                      ref.read(hapticsProvider).selection();
                      setState(() => _range = AnalyticsRange.values[i]);
                    },
                  ),
                  const SizedBox(height: 14),

                  // throughput chart
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Throughput Volume', style: t.titleMedium),
                            const SizedBox(height: 2),
                            Text('Average: ${avgPerDay.toStringAsFixed(1)} tasks/day', style: t.bodySmall),
                          ]),
                        ),
                        Icon(Icons.trending_up_rounded, color: p.accent),
                      ]),
                      const SizedBox(height: 18),
                      SizedBox(height: 170, child: _ThroughputChart(data: data, range: _range)),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // stats grid
                  Row(children: [
                    Expanded(
                      child: _Metric(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Tasks Done',
                        value: '${data.tasksDone}',
                        note: data.deltaPercent == null
                            ? 'No baseline yet'
                            : '${data.deltaPercent! >= 0 ? '+' : ''}${data.deltaPercent}% vs $label',
                        good: (data.deltaPercent ?? 0) >= 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        icon: Icons.timer_outlined,
                        label: 'Deep Focus',
                        value: focusH.toStringAsFixed(1),
                        unit: 'h',
                        note: focusH >= goalH ? 'Goal: ${goalH.round()}h hit' : 'Goal: ${goalH.round()}h',
                        good: focusH >= goalH,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _Metric(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Current Streak',
                        value: '${data.streak.current}',
                        unit: 'Days',
                        note: 'Best record: ${data.streak.best}d',
                        good: data.streak.current > 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        icon: Icons.speed_rounded,
                        label: 'Daily Velocity',
                        value: data.velocity.toStringAsFixed(1),
                        unit: 'tasks/d',
                        note: data.velocity >= 3 ? 'Optimal pace' : 'Room to grow',
                        good: data.velocity >= 3,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // gauge + heatmap
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _Gauge(score: data.score),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Productivity Score', style: t.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Blends your overall completion rate with progress toward your focus goal.',
                              style: t.bodySmall,
                            ),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        Text('ACTIVITY · LAST 12 WEEKS',
                            style: t.labelSmall?.copyWith(
                                color: p.textMuted, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      _Heatmap(heat: data.heat),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // focus distribution
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Focus Distribution', style: t.titleMedium),
                      const SizedBox(height: 2),
                      Text('${focusH.toStringAsFixed(1)}h tracked across tasks', style: t.bodySmall),
                      const SizedBox(height: 14),
                      if (data.slices.isEmpty)
                        Text('Run a focus session to see where your time goes.',
                            style: t.bodyMedium?.copyWith(color: p.textMuted))
                      else
                        _Distribution(slices: data.slices),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppDecor.card(context.palette),
        child: child,
      );
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.icon,
      required this.label,
      required this.value,
      required this.note,
      this.unit,
      this.good = true});
  final IconData icon;
  final String label, value, note;
  final String? unit;
  final bool good;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecor.card(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.1)),
          ),
          Icon(icon, size: 16, color: p.accent),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: double.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              value.contains('.') ? v.toStringAsFixed(1) : v.round().toString(),
              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit!, style: t.bodySmall)),
          ],
        ]),
        const SizedBox(height: 4),
        Text(note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelSmall?.copyWith(color: good ? p.accent : p.textMuted)),
      ]),
    );
  }
}

// ───────────────────────── bar chart (fl_chart) ─────────────────────────

class _ThroughputChart extends StatelessWidget {
  const _ThroughputChart({required this.data, required this.range});
  final AnalyticsData data;
  final AnalyticsRange range;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final b = data.buckets;
    final maxV = math.max(4, b.fold<int>(0, (a, x) => math.max(a, x.tasks))).toDouble();
    final peak = b.fold<int>(0, (a, x) => math.max(a, x.tasks));
    final dense = b.length > 12;

    return TweenAnimationBuilder<double>(
      key: ValueKey(range),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, anim, __) => BarChart(
        BarChartData(
          maxY: maxV * 1.1,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= b.length) return const SizedBox.shrink();
                  if (dense && (i + 1) % 5 != 0 && i != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Text(b[i].label, style: t.labelSmall?.copyWith(color: p.textMuted)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => p.surface3,
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${b[group.x].tasks} task${b[group.x].tasks == 1 ? '' : 's'}',
                (t.labelMedium ?? const TextStyle()).copyWith(
                    color: p.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < b.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: b[i].tasks * anim,
                  width: dense ? 5 : (b.length > 7 ? 14 : 22),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(p.isTerminal ? 2 : 6)),
                  color: peak > 0 && b[i].tasks == peak
                      ? p.accent
                      : p.accent.withValues(alpha: 0.28),
                  backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxV,
                      color: p.isDark
                          ? const Color(0x0AFFFFFF)
                          : const Color(0x0A000000)),
                ),
              ]),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }
}

// ───────────────────────── gauge ─────────────────────────

class _Gauge extends StatelessWidget {
  const _Gauge({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 1200),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (_, v, __) => SizedBox(
        width: 96,
        height: 96,
        child: CustomPaint(
          painter: _GaugePainter(
              v,
              p.accent,
              p.isDark
                  ? const Color(0x14FFFFFF)
                  : const Color(0x14000000)),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(v * 100).round()}',
                  style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text('SCORE',
                  style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.v, this.color, this.trackColor);
  final double v;
  final Color color;
  final Color trackColor;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = 3 * math.pi / 4; // 135°
    const sweep = 3 * math.pi / 2; // 270°
    canvas.drawArc(rect, start, sweep, false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
    if (v <= 0) return;
    canvas.drawArc(rect, start, sweep * v, false,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawArc(rect, start, sweep * v, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GaugePainter o) =>
      o.v != v || o.color != color || o.trackColor != trackColor;
}

// ───────────────────────── heatmap ─────────────────────────

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.heat});
  final Map<DateTime, int> heat;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final first = todayD.subtract(Duration(days: todayD.weekday - 1 + 77));

    Color color(int n, bool future) {
      if (future) return Colors.transparent;
      if (n == 0) {
        return p.isDark
            ? const Color(0x0DFFFFFF)
            : const Color(0x0F000000);
      }
      if (n == 1) return p.accent.withValues(alpha: 0.28);
      if (n <= 3) return p.accent.withValues(alpha: 0.55);
      if (n <= 5) return p.accent.withValues(alpha: 0.8);
      return p.accent;
    }

    return LayoutBuilder(builder: (_, c) {
      final gap = 3.0;
      final cell = ((c.maxWidth - gap * 11) / 12).clamp(8.0, 24.0);
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var w = 0; w < 12; w++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + w * 45),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Column(children: [
              for (var d = 0; d < 7; d++)
                () {
                  final day = first.add(Duration(days: w * 7 + d));
                  final future = day.isAfter(todayD);
                  return Container(
                    width: cell,
                    height: cell,
                    margin: EdgeInsets.only(bottom: d == 6 ? 0 : gap),
                    decoration: BoxDecoration(
                      color: color(heat[day] ?? 0, future),
                      borderRadius: BorderRadius.circular(p.isTerminal ? 1.5 : 4),
                      border: day == todayD ? Border.all(color: p.accent, width: 1) : null,
                    ),
                  );
                }(),
            ]),
          ),
      ]);
    });
  }
}

// ───────────────────────── distribution ─────────────────────────

class _Distribution extends StatelessWidget {
  const _Distribution({required this.slices});
  final List<FocusSlice> slices;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final total = slices.fold<int>(0, (a, s) => a + s.seconds);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 10,
          child: Row(children: [
            for (var i = 0; i < slices.length; i++)
              Expanded(
                flex: math.max(1, (slices[i].seconds * 1000 / total).round()),
                child: Container(
                    margin: EdgeInsets.only(right: i == slices.length - 1 ? 0 : 2),
                    color: _sliceColors[i % _sliceColors.length]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < slices.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: _sliceColors[i % _sliceColors.length], shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(slices[i].label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium)),
            Text('${(slices[i].seconds / 3600).toStringAsFixed(1)} hrs',
                style: t.bodySmall?.copyWith(color: p.textMuted)),
            const SizedBox(width: 10),
            SizedBox(
              width: 38,
              child: Text('${(slices[i].seconds * 100 / total).round()}%',
                  textAlign: TextAlign.right,
                  style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
    ]);
  }
}
