import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_snack.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../../tasks/presentation/widgets/priority_badge.dart';
import '../data/focus_history.dart';
import 'focus_controller.dart';
import 'focus_ring.dart';
import 'focus_task_provider.dart';

String fmtClock(int secs) {
  final m = secs ~/ 60, s = secs % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String fmtHm(int secs) {
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with SingleTickerProviderStateMixin {
  // drives ring glow + pointer pulse
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse(bool running) {
    if (running && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!running && _pulse.isAnimating) {
      _pulse.animateTo(0, duration: const Duration(milliseconds: 400));
    }
  }

  Future<void> _pickTask() async {
    ref.read(hapticsProvider).selection();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const _TaskPicker(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final f = ref.watch(focusControllerProvider);
    final ctl = ref.read(focusControllerProvider.notifier);
    final prefs = ref.watch(prefsProvider);
    final task = ref.watch(focusTaskProvider);
    final history = ref.watch(focusHistoryProvider);
    final navPad = MediaQuery.paddingOf(context).bottom;
    _syncPulse(f.running);

    final isWork = f.phase == FocusPhase.work;
    final today = DateTime.now();
    final todaySecs = focusSecondsOn(history, today) + (isWork ? f.elapsedSeconds : 0);
    final todays = history.where((s) => sameDay(s.start, today)).toList();
    final yield = todays.isEmpty
        ? null
        : (todays.where((s) => s.completed).length * 100 / todays.length).round();

    final status = f.running
        ? (isWork ? ('In Zone', Icons.change_circle_outlined) : ('Resting', Icons.spa_outlined))
        : f.breakDone
            ? ('Break complete', Icons.check_circle_outline_rounded)
            : f.pristine
                ? ('Ready', Icons.play_circle_outline_rounded)
                : ('Paused', Icons.pause_circle_outline_rounded);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(title: 'Pulse', subtitle: 'Focus Mode'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, navPad + 96),
              children: [
                // ── active directive ──
                GestureDetector(
                  onTap: _pickTask,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppDecor.card(p, glowing: f.running && isWork),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.bolt_rounded, size: 14, color: p.accent),
                        const SizedBox(width: 4),
                        Text('ACTIVE DIRECTIVE',
                            style: t.labelSmall?.copyWith(
                                color: p.accent, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: p.surface3,
                              borderRadius: BorderRadius.circular(p.pillRadius.clamp(4, 999))),
                          child: Text('Deep Work ${prefs.workMinutes}m', style: t.labelSmall),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: Text(task?.title ?? 'Free focus · tap to pick a task',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(
                                  color: task == null ? p.textMuted : p.textPrimary)),
                        ),
                        Icon(Icons.unfold_more_rounded, color: p.textMuted, size: 20),
                      ]),
                      if (task != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.folder_outlined, size: 14, color: p.textMuted),
                          const SizedBox(width: 4),
                          Text('Personal', style: t.bodySmall),
                          const SizedBox(width: 6),
                          Text('•', style: t.bodySmall),
                          const SizedBox(width: 6),
                          Text('${task.priority.name.toUpperCase()} PRIORITY',
                              style: t.labelSmall?.copyWith(
                                  color: task.priority.color(context), fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // ── cycle indicator ──
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(isWork ? 'Pomodoro' : 'Break', style: t.labelMedium?.copyWith(color: p.textMuted)),
                  const SizedBox(width: 8),
                  Text('•', style: t.labelMedium?.copyWith(color: p.textMuted)),
                  const SizedBox(width: 8),
                  Text('Session ${f.sessionIndex} of ${f.cycleLength}', style: t.labelMedium),
                  const SizedBox(width: 10),
                  for (var i = 1; i <= f.cycleLength; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 4),
                      width: i == f.sessionIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < f.sessionIndex || (i == f.sessionIndex && !isWork)
                            ? p.accent
                            : i == f.sessionIndex
                                ? p.accent.withValues(alpha: 0.7)
                                : (p.isDark
                                    ? const Color(0x1FFFFFFF)
                                    : const Color(0x1F000000)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),

                // ── ring + time ──
                Center(
                  child: SizedBox(
                    width: 272,
                    height: 272,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => CustomPaint(
                        painter: FocusRingPainter(
                          progress: f.progress,
                          pulse: Curves.easeInOut.transform(_pulse.value),
                          accent: isWork ? p.accent : const Color(0xFF78FFD6),
                          track: p.isDark
                              ? const Color(0x0FFFFFFF)
                              : const Color(0x1A000000),
                          active: f.running,
                        ),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(isWork ? 'TIME REMAINING' : 'REST',
                                style: t.labelSmall?.copyWith(
                                    color: p.textMuted, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (c, a) => FadeTransition(
                                opacity: a,
                                child: ScaleTransition(
                                    scale: Tween(begin: 0.96, end: 1.0).animate(a), child: c),
                              ),
                              child: Text(
                                fmtClock(f.remainingSeconds),
                                key: ValueKey(f.remainingSeconds),
                                style: t.displaySmall?.copyWith(
                                  fontSize: 58,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: f.running ? p.accent.withValues(alpha: 0.12) : p.surface3,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(status.$2, size: 14, color: f.running ? p.accent : p.textMuted),
                                const SizedBox(width: 5),
                                Text(status.$1,
                                    style: t.labelSmall?.copyWith(
                                        color: f.running ? p.accent : p.textMuted,
                                        fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── main controls ──
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StepButton(label: '-5m', icon: Icons.remove_rounded, onTap: () => ctl.adjust(-5)),
                  const SizedBox(width: 22),
                  _PlayButton(running: f.running, onTap: ctl.toggle, pulse: _pulse),
                  const SizedBox(width: 22),
                  _StepButton(label: '+5m', icon: Icons.add_rounded, onTap: () => ctl.adjust(5)),
                ]),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TextAction(icon: Icons.restart_alt_rounded, label: 'Reset', onTap: ctl.reset),
                  const SizedBox(width: 8),
                  _TextAction(
                      icon: Icons.skip_next_rounded,
                      label: isWork ? 'Skip to break' : 'Next sprint',
                      onTap: ctl.skip),
                  const SizedBox(width: 8),
                  _TextAction(
                    icon: Icons.bookmark_add_outlined,
                    label: 'Flag',
                    onTap: () {
                      ref.read(hapticsProvider).success();
                      showAppSnack(context, 'Moment flagged at ${fmtClock(f.elapsedSeconds)}');
                    },
                  ),
                ]),
                const SizedBox(height: 22),

                // ── stats ──
                Row(children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule_rounded,
                      label: "Today's Focus",
                      value: fmtHm(todaySecs),
                      suffix: '/ 4h',
                      progress: (todaySecs / (4 * 3600)).clamp(0.0, 1.0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.verified_outlined,
                      label: 'Session Yield',
                      value: yield == null ? '—' : '$yield%',
                      suffix: yield == null ? '' : 'completed',
                      progress: (yield ?? 0) / 100,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.running, required this.onTap, required this.pulse});
  final bool running;
  final VoidCallback onTap;
  final Animation<double> pulse;
  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedBuilder(
          animation: widget.pulse,
          builder: (_, child) => Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: p.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: p.accent.withValues(alpha: 0.25 + (widget.running ? 0.2 * widget.pulse.value : 0)),
                    blurRadius: 22 + 12 * widget.pulse.value),
              ],
            ),
            child: child,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(widget.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(widget.running), size: 40, color: p.onAccent),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: p.surface2,
          shape: p.usesGlass ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: p.usesGlass ? null : BorderRadius.circular(4),
          border: Border.all(color: p.border),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: p.textMuted),
          Text(label.replaceAll(RegExp(r'[+-]'), ''),
              style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: p.textMuted),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: p.textMuted)),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.suffix,
      required this.progress});
  final IconData icon;
  final String label, value, suffix;
  final double progress;
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
                style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.2)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(suffix, style: t.bodySmall),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: p.isDark
                    ? const Color(0x0FFFFFFF)
                    : const Color(0x14000000)),
          ),
        ),
      ]),
    );
  }
}

class _TaskPicker extends ConsumerWidget {
  const _TaskPicker();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tasks = (ref.watch(tasksControllerProvider).valueOrNull ?? const <Tasks>[])
        .where((x) => !x.isCompleted)
        .toList();
    final selected = ref.watch(focusTaskProvider);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      decoration: AppDecor.sheet(p),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: p.textMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(children: [
              Text('Choose a task', style: t.titleMedium),
              const Spacer(),
              if (selected != null)
                TextButton(
                  onPressed: () {
                    ref.read(focusTaskProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                  child: const Text('FREE FOCUS'),
                ),
            ]),
          ),
          Flexible(
            child: tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No pending tasks. Add one from Today.',
                        style: t.bodyMedium?.copyWith(color: p.textMuted)))
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final x in tasks)
                        GestureDetector(
                          onTap: () {
                            ref.read(hapticsProvider).selection();
                            ref.read(focusTaskProvider.notifier).state = x;
                            Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: AppDecor.card(p, glowing: selected?.id == x.id),
                            child: Row(children: [
                              PriorityDot(x.priority, size: 8),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(x.title,
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge)),
                              if (selected?.id == x.id)
                                Icon(Icons.check_circle_rounded, size: 18, color: p.accent),
                            ]),
                          ),
                        ),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}
