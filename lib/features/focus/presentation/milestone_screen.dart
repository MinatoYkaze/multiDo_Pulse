import 'dart:ui' show FontFeature;
import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../analytics/data/activity_log.dart';
import '../../analytics/data/streaks.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../data/focus_history.dart';
import 'focus_controller.dart';
import 'focus_screen.dart' show fmtClock, fmtHm;

const _phases = [
  ('Inhale deeply (4s)', 'Oxygenate your focus', 1.5, 1.0),
  ('Hold breath (4s)', 'Let it settle', 1.25, 0.8),
  ('Exhale slowly (4s)', 'Release the tension', 0.75, 0.4),
  ('Rest empty (4s)', 'Stay soft and still', 1.0, 0.6),
];

/// `focus_session_milestone_break_1` + `_2`: celebration, stats and a 4-4-4-4
/// box-breathing guide with the break countdown.
class MilestoneScreen extends ConsumerStatefulWidget {
  const MilestoneScreen({super.key});
  @override
  ConsumerState<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends ConsumerState<MilestoneScreen> {
  FocusMilestone? _m;
  int _phase = 0;
  Timer? _breath;

  @override
  void initState() {
    super.initState();
    _m = ref.read(focusControllerProvider).milestone;
    if (_m == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/focus');
      });
    }
    _breath = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _phase = (_phase + 1) % _phases.length);
    });
  }

  @override
  void dispose() {
    _breath?.cancel();
    super.dispose();
  }

  void _close() {
    ref.read(focusControllerProvider.notifier).dismissMilestone();
    context.go('/focus');
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    if (m == null) return const Scaffold();
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final f = ref.watch(focusControllerProvider);
    final ctl = ref.read(focusControllerProvider.notifier);
    final prefs = ref.watch(prefsProvider);
    final history = ref.watch(focusHistoryProvider);
    final log = ref.watch(activityLogProvider);
    final tasks = ref.watch(tasksControllerProvider).valueOrNull ?? const [];
    final task = tasks.firstWhereOrNull((x) => x.id == m.taskId);

    final today = DateTime.now();
    final todays = history.where((s) => sameDay(s.start, today)).toList();
    final score = todays.isEmpty
        ? 100
        : (todays.where((s) => s.completed).length * 100 / todays.length).round();
    final streak = computeStreaks([...log.map((e) => e.at), ...history.map((s) => s.start)]);
    final hasNext = m.sessionNumber < f.cycleLength;
    final nextAt = today.add(Duration(seconds: f.running ? f.remainingSeconds : prefs.breakMinutes * 60));
    final phase = _phases[_phase];
    final resting = f.running && f.phase == FocusPhase.rest;
    final navPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: -140,
          left: -80,
          right: -80,
          child: Container(
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [p.accent.withValues(alpha: 0.14), Colors.transparent]),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(children: [
                IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded)),
                Expanded(
                  child: Text('Session ${m.sessionNumber} of ${f.cycleLength} Complete',
                      textAlign: TextAlign.center,
                      style: t.labelLarge?.copyWith(color: p.textMuted)),
                ),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, navPad + 96),
                children: [
                  Center(child: _CelebrationRing(minutes: m.focusedSeconds ~/ 60)),
                  const SizedBox(height: 18),
                  Text('Deep Work Block Banked',
                      textAlign: TextAlign.center, style: t.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    m.taskTitle != null
                        ? 'Great momentum! You sustained peak flow on your primary directive.'
                        : 'Great momentum! You sustained a full block of uninterrupted focus.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: p.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // task + XP
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppDecor.card(p),
                    child: Row(children: [
                      Icon(task?.isCompleted == true ? Icons.task_alt_rounded : Icons.radio_button_unchecked_rounded,
                          color: p.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.taskTitle ?? 'Free focus block',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyLarge),
                          if (task != null && !task.isCompleted)
                            GestureDetector(
                              onTap: () async {
                                ref.read(hapticsProvider).success();
                                await ref.read(tasksControllerProvider.notifier).toggle(task);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Mark task as done',
                                    style: t.labelMedium?.copyWith(
                                        color: p.accent, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ]),
                      ),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: m.xp),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: v == m.xp
                                ? [BoxShadow(color: p.accent.withValues(alpha: 0.45), blurRadius: 12)]
                                : null,
                          ),
                          child: Text('+$v XP',
                              style: t.labelMedium?.copyWith(
                                  color: p.accent, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // stats
                  Row(children: [
                    Expanded(
                        child: _Stat(
                            icon: Icons.timelapse_rounded,
                            label: "Today's Focus",
                            value: fmtHm(focusSecondsOn(history, today)),
                            note: '+${m.focusedSeconds ~/ 60}m this block')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Stat(
                            icon: Icons.psychology_outlined,
                            label: 'Focus Score',
                            value: '$score%',
                            note: score >= 90 ? 'Optimal flow state' : 'Keep building')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _Stat(
                            icon: Icons.local_fire_department_outlined,
                            label: 'Current Streak',
                            value: '${streak.current} Day${streak.current == 1 ? '' : 's'}',
                            note: streak.current > 0 && streak.current >= streak.best
                                ? 'Personal record high'
                                : 'Best: ${streak.best}d')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Stat(
                            icon: Icons.schedule_rounded,
                            label: 'Next Session',
                            value: hasNext ? DateFormat.jm().format(nextAt) : 'Done',
                            note: hasNext ? 'Sprint ${m.sessionNumber + 1} of ${f.cycleLength}' : 'Daily cycle complete')),
                  ]),
                  const SizedBox(height: 16),

                  // breather
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecor.card(p, glowing: resting),
                    child: Column(children: [
                      Row(children: [
                        Icon(Icons.spa_outlined, size: 18, color: p.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${prefs.breakMinutes}-Minute Box Breather', style: t.titleMedium),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: p.surface3, borderRadius: BorderRadius.circular(999)),
                          child: Text('4s Box', style: t.labelSmall),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 74,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeInOut,
                            width: 22 * phase.$3,
                            height: 22 * phase.$3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.accent.withValues(alpha: phase.$4),
                              boxShadow: [
                                BoxShadow(
                                    color: p.accent.withValues(alpha: 0.35 * phase.$4),
                                    blurRadius: 18)
                              ],
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(key: ValueKey(_phase), children: [
                          Text(phase.$1, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(phase.$2, style: t.bodySmall),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        f.phase == FocusPhase.rest ? fmtClock(f.remainingSeconds) : fmtClock(prefs.breakMinutes * 60),
                        style: t.headlineMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: f.breakDone ? p.accent : p.textPrimary),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // actions
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: (f.running || f.breakDone) ? null : ctl.startBreak,
                      icon: resting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(f.breakDone ? Icons.check_rounded : Icons.self_improvement_rounded),
                      label: Text(resting
                          ? 'Resting…'
                          : f.breakDone
                              ? 'Break complete'
                              : 'Start ${prefs.breakMinutes}m Break'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ctl.nextSprint();
                        context.go('/focus');
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(hasNext ? 'Next Sprint' : 'Start New Cycle'),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.note});
  final IconData icon;
  final String label, value, note;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecor.card(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: p.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.1)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 20)),
        const SizedBox(height: 2),
        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
      ]),
    );
  }
}

class _CelebrationRing extends StatelessWidget {
  const _CelebrationRing({required this.minutes});
  final int minutes;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (_, v, __) => SizedBox(
        width: 150,
        height: 150,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: const Size(150, 150),
              painter: _DonePainter(
                  v,
                  p.accent,
                  p.isDark
                      ? const Color(0x0FFFFFFF)
                      : const Color(0x1A000000))),
          Transform.scale(
            scale: 0.6 + 0.4 * v,
            child: Opacity(
              opacity: v,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_rounded, size: 40, color: p.accent),
                const SizedBox(height: 2),
                Text('${minutes.toString().padLeft(2, '0')}:00 Banked',
                    style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DonePainter extends CustomPainter {
  _DonePainter(this.t, this.color, this.track);
  final double t;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = 6);
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * math.pi * t;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_DonePainter o) => o.t != t;
}
