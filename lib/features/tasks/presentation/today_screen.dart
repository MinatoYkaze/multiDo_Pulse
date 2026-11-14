import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/async_states.dart';
import 'task_format.dart';
import 'tasks_controller.dart';
import 'widgets/quick_add_dock.dart';
import 'widgets/task_editor_sheet.dart';
import 'widgets/task_row.dart';

/// `today_tasks_1` (plain) + `today_tasks_2` (rich motion) in one screen;
/// the ✨ header button switches between the two looks.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _adding = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _error(Object e) =>
      showAppSnack(context, ApiException.from(e).message, error: true);

  DateTime? get _defaultDue =>
      ref.read(showAllTasksProvider) ? null : TaskFmt.startOfToday();

  Future<void> _quickAdd() async {
    final title = _input.text.trim();
    if (title.isEmpty || _adding) return;
    setState(() => _adding = true);
    ref.read(hapticsProvider).light();
    try {
      await ref
          .read(tasksControllerProvider.notifier)
          .add(TasksPost(title: title, dueDate: _defaultDue));
      _input.clear();
      ref.read(hapticsProvider).success();
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _openEditor({Tasks? task, String title = ''}) async {
    _focus.unfocus();
    final body = await TaskEditorSheet.show(context,
        task: task, initialTitle: title);
    if (body == null || !mounted) return;
    final ctl = ref.read(tasksControllerProvider.notifier);
    try {
      if (task == null) {
        await ctl.add(body);
        _input.clear();
        ref.read(hapticsProvider).success();
      } else {
        await ctl.edit(task, body);
        ref.read(hapticsProvider).light();
      }
    } catch (e) {
      if (mounted) _error(e);
    }
  }

  Future<void> _toggle(Tasks t) async {
    final h = ref.read(hapticsProvider);
    t.isCompleted ? h.light() : h.success();
    try {
      await ref.read(tasksControllerProvider.notifier).toggle(t);
    } catch (e) {
      if (mounted) _error(e);
    }
  }

  Future<bool> _delete(Tasks t) async {
    ref.read(hapticsProvider).medium();
    try {
      await ref.read(tasksControllerProvider.notifier).remove(t.id);
      return true;
    } catch (e) {
      if (mounted) _error(e);
      return false;
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(tasksControllerProvider.notifier).refresh();
    } catch (e) {
      if (mounted) _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final async = ref.watch(tasksControllerProvider);
    final visible = ref.watch(visibleTasksProvider);
    final stats = ref.watch(taskStatsProvider);
    final rich = ref.watch(richMotionProvider);
    final showAll = ref.watch(showAllTasksProvider);
    final filter = ref.watch(taskFilterProvider);

    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    // mq.padding.bottom already includes the glass nav bar (extendBody).
    final dockBottom = keyboard ? 10.0 : mq.padding.bottom + 10;
    final listBottom = dockBottom + 84;

    Widget body;
    if (async.isLoading && !async.hasValue) {
      body = const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: SkeletonList());
    } else if (async.hasError && !async.hasValue) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorRetry(
          message: ApiException.from(async.error!).message,
          onRetry: () => ref.invalidate(tasksControllerProvider),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface2,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _Hero(showAll: showAll, stats: stats),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _Filters(
                  value: filter,
                  onChanged: (f) {
                    ref.read(hapticsProvider).selection();
                    ref.read(taskFilterProvider.notifier).state = f;
                  },
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: filter == TaskFilter.done
                      ? Icons.hourglass_empty_rounded
                      : Icons.task_alt_rounded,
                  title: stats.total == 0
                      ? (showAll ? 'No tasks yet' : 'Nothing on your plate')
                      : 'No tasks in this view',
                  subtitle: stats.total == 0
                      ? 'Type below to add your first task.'
                      : 'Try another filter.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, listBottom),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final t = visible[i];
                      return TaskRow(
                        key: ValueKey<int>(t.id),
                        task: t,
                        index: i,
                        rich: rich,
                        onToggle: () => _toggle(t),
                        onOpen: () {
                          ref.read(hapticsProvider).selection();
                          _focus.unfocus();
                          context.push(Routes.task(t.id));
                        },
                        onEdit: () => _openEditor(task: t),
                        onDelete: () => _delete(t),
                      );
                    },
                    childCount: visible.length,
                    findChildIndexCallback: (key) {
                      if (key is ValueKey<int>) {
                        final i = visible.indexWhere((t) => t.id == key.value);
                        return i < 0 ? null : i;
                      }
                      return null;
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(
            title: 'Pulse',
            subtitle: 'Today',
            actions: [
              _HeaderButton(
                icon: showAll
                    ? Icons.all_inbox_rounded
                    : Icons.today_rounded,
                tooltip: showAll ? 'Showing all tasks' : 'Showing today',
                onTap: () {
                  ref.read(hapticsProvider).selection();
                  ref.read(showAllTasksProvider.notifier).state = !showAll;
                },
              ),
              const SizedBox(width: 6),
              _HeaderButton(
                icon: Icons.auto_awesome_rounded,
                active: rich,
                tooltip: rich ? 'Rich motion on' : 'Rich motion off',
                onTap: () {
                  ref.read(hapticsProvider).selection();
                  ref.read(richMotionProvider.notifier).toggle();
                },
              ),
            ],
          ),
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: body),
              Positioned(
                left: 16,
                right: 16,
                bottom: dockBottom,
                child: QuickAddDock(
                  controller: _input,
                  focusNode: _focus,
                  busy: _adding,
                  onSubmit: _quickAdd,
                  onExpand: () => _openEditor(title: _input.text.trim()),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── pieces ─────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.showAll, required this.stats});
  final bool showAll;
  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
                style: t.labelMedium
                    ?.copyWith(color: p.textMuted, letterSpacing: 1)),
            Text(showAll ? 'All Tasks' : 'Today',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(
                  scale: a, child: FadeTransition(opacity: a, child: c)),
              child: Text('${stats.done}',
                  key: ValueKey(stats.done),
                  style: t.bodyMedium?.copyWith(
                      color: p.accent, fontWeight: FontWeight.w600)),
            ),
            Text(' of ${stats.total} completed',
                style: t.bodyMedium?.copyWith(color: p.textMuted)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      TweenAnimationBuilder<double>(
        tween: Tween<double>(end: stats.ratio),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Container(
          height: 6,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                        color: p.accent.withValues(alpha: 0.6), blurRadius: 8)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.value, required this.onChanged});
  final TaskFilter value;
  final ValueChanged<TaskFilter> onChanged;

  static const _labels = {
    TaskFilter.all: 'All',
    TaskFilter.pending: 'Pending',
    TaskFilter.done: 'Done',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Row(children: [
      for (final f in TaskFilter.values) ...[
        GestureDetector(
          onTap: () => onChanged(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: f == value
                  ? (p.isTerminal
                      ? p.accent.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.10))
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 999),
              border: Border.all(
                  color: f == value && p.isTerminal
                      ? p.accent
                      : Colors.transparent),
              boxShadow: f == value && !p.isTerminal
                  ? [
                      BoxShadow(
                          color: Colors.white.withValues(alpha: 0.08),
                          blurRadius: 12)
                    ]
                  : null,
            ),
            child: Text(_labels[f]!,
                style: t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: f == value
                        ? (p.isTerminal ? p.accent : Colors.white)
                        : p.textMuted)),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ]);
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton(
      {required this.icon,
      required this.onTap,
      required this.tooltip,
      this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? p.accent.withValues(alpha: 0.12)
                : p.surface3.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
            boxShadow: active
                ? [BoxShadow(color: p.accentGlow, blurRadius: 12)]
                : null,
          ),
          child: Icon(icon,
              size: 18, color: active ? p.accent : p.textPrimary),
        ),
      ),
    );
  }
}
