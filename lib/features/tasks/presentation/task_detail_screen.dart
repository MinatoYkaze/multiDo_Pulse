import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../focus/presentation/focus_task_provider.dart';
import 'task_detail_controller.dart';
import 'task_format.dart';
import 'tasks_controller.dart';
import 'widgets/animated_check.dart';
import 'widgets/motion_widgets.dart';
import 'widgets/priority_badge.dart';
import 'widgets/task_editor_sheet.dart';

/// `task_detail_subtasks`: priority badge, title banner, notes, subtask
/// checklist CRUD with progress, deadline / focus cards and the focus CTA.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final int taskId;
  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _subCtl = TextEditingController();
  final _subFocus = FocusNode();
  bool _addOpen = false;
  bool _savingSub = false;

  TaskDetailController get _ctl =>
      ref.read(taskDetailProvider(widget.taskId).notifier);

  @override
  void dispose() {
    _subCtl.dispose();
    _subFocus.dispose();
    super.dispose();
  }

  void _err(Object e) => showAppSnack(context, ApiException.from(e).message,
      error: true, bottom: 90);

  void _close() => context.canPop() ? context.pop() : context.go(Routes.today);

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) _err(e);
    }
  }

  Future<void> _toggleTask(Tasks t) async {
    final h = ref.read(hapticsProvider);
    if (!t.isCompleted) {
      h.success();
      ref.read(audioFxProvider).playChime();
    } else {
      h.light();
    }
    await _run(_ctl.toggleTask);
  }

  Future<void> _addSubtask() async {
    final title = _subCtl.text.trim();
    if (title.isEmpty) {
      setState(() => _addOpen = false);
      return;
    }
    setState(() => _savingSub = true);
    ref.read(hapticsProvider).light();
    try {
      await _ctl.addSubtask(title);
      _subCtl.clear();
      if (mounted) _subFocus.requestFocus(); // keep going: rapid entry
    } catch (e) {
      if (mounted) _err(e);
    } finally {
      if (mounted) setState(() => _savingSub = false);
    }
  }

  Future<void> _pickDeadline(Tasks t) async {
    final today = TaskFmt.startOfToday();
    final init = t.dueDate ?? today;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TaskFmt.hasTime(t.dueDate)
          ? TimeOfDay(hour: t.dueDate!.hour, minute: t.dueDate!.minute)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'ADD A TIME (CANCEL FOR ALL-DAY)',
    );
    final due = DateTime(d.year, d.month, d.day, tm?.hour ?? 0, tm?.minute ?? 0);
    await _run(() => _ctl.setDue(due));
  }

  Future<void> _pickPriority(Tasks t) async {
    ref.read(hapticsProvider).selection();
    final p = await showModalBottomSheet<Priority>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrioritySheet(current: t.priority),
    );
    if (p == null || p == t.priority) return;
    await _run(() => _ctl.setPriority(p));
  }

  Future<void> _edit(Tasks t) async {
    final body = await TaskEditorSheet.show(context, task: t);
    if (body == null || !mounted) return;
    await _run(() => _ctl.edit(body));
  }

  Future<void> _delete(Tasks t, int subCount) async {
    ref.read(hapticsProvider).medium();
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Task?',
      message: TextSpan(children: [
        const TextSpan(text: 'Are you sure you want to delete '),
        TextSpan(
            text: '"${t.title}"',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        TextSpan(
            text: subCount > 0
                ? '? Its $subCount subtask${subCount == 1 ? '' : 's'} will be removed too and this cannot be undone.'
                : '? This cannot be undone.'),
      ]),
      confirmLabel: 'Delete Task',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(tasksControllerProvider.notifier).remove(t.id);
      if (mounted) _close();
    } catch (e) {
      if (mounted) _err(e);
    }
  }

  Future<void> _menu(Tasks t, int subCount) async {
    ref.read(hapticsProvider).light();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ActionSheet(),
    );
    if (!mounted) return;
    if (action == 'edit') await _edit(t);
    if (action == 'delete') await _delete(t, subCount);
  }

  void _startFocus(Tasks t) {
    ref.read(hapticsProvider).heavy();
    ref.read(focusTaskProvider.notifier).state = t;
    context.go(Routes.focus);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final async = ref.watch(taskDetailProvider(widget.taskId));
    final cached = ref.watch(tasksControllerProvider.select(
        (v) => v.valueOrNull?.firstWhereOrNull((t) => t.id == widget.taskId)));
    final task = async.valueOrNull?.task ?? cached;
    final subs = async.valueOrNull?.subtasks;
    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom > 0 ? 16.0 : mq.padding.bottom + 16;

    Widget content;
    if (task == null) {
      content = async.hasError
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorRetry(
                message: ApiException.from(async.error!).message,
                onRetry: () =>
                    ref.invalidate(taskDetailProvider(widget.taskId)),
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(count: 4, height: 90));
    } else {
      final state = async.valueOrNull;
      content = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        children: [
          _TopBar(
            task: task,
            onPriority: () => _pickPriority(task),
            onMenu: () => _menu(task, subs?.length ?? 0),
            onClose: _close,
          ),
          const SizedBox(height: 14),
          _TitleCard(task: task, onToggle: () => _toggleTask(task)),
          const SizedBox(height: 12),
          _NotesCard(task: task, onEdit: () => _edit(task)),
          const SizedBox(height: 12),
          _SubtasksCard(
            subtasks: subs,
            loading: state == null && !async.hasError,
            error: async.hasError && state == null,
            open: _addOpen,
            saving: _savingSub,
            controller: _subCtl,
            focusNode: _subFocus,
            onOpen: () {
              ref.read(hapticsProvider).light();
              setState(() => _addOpen = true);
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _subFocus.requestFocus());
            },
            onSubmit: _addSubtask,
            onToggle: (s) {
              ref.read(hapticsProvider).light();
              _run(() => _ctl.toggleSubtask(s));
            },
            onDelete: (s) {
              ref.read(hapticsProvider).medium();
              _run(() => _ctl.deleteSubtask(s));
            },
          ),
          const SizedBox(height: 12),
          _MetaGrid(
            task: task,
            workMinutes: ref.watch(prefsProvider.select((s) => s.workMinutes)),
            onDeadline: () => _pickDeadline(task),
            onClearDeadline: () => _run(() => _ctl.setDue(null)),
          ),
          const SizedBox(height: 16),
          _FocusButton(
            minutes: ref.watch(prefsProvider.select((s) => s.workMinutes)),
            onTap: () => _startFocus(task),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(bottom: false, child: content),
    );
  }
}

// ───────────────────────── sections ─────────────────────────

BoxDecoration _cardDeco(AppPalette p) => p.usesGlass
    ? BoxDecoration(
        color: p.isDark ? const Color(0xFF16181F) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      )
    : AppDecor.card(p);

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.task,
      required this.onPriority,
      required this.onMenu,
      required this.onClose});
  final Tasks task;
  final VoidCallback onPriority;
  final VoidCallback onMenu;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      const SizedBox(height: 6),
      Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: p.textMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_outline_rounded, size: 13, color: p.accent),
                const SizedBox(width: 4),
                Text('Personal', style: t.labelMedium),
              ]),
            ),
            PriorityBadge(priority: task.priority, onTap: onPriority),
          ]),
        ),
        _RoundIcon(icon: Icons.more_horiz_rounded, onTap: onMenu, label: 'More actions'),
        const SizedBox(width: 6),
        _RoundIcon(icon: Icons.close_rounded, onTap: onClose, label: 'Close'),
      ]),
    ]);
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, required this.label});
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: p.surface3,
              borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 17)),
          child: Icon(icon, size: 18, color: p.textMuted),
        ),
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.task, required this.onToggle});
  final Tasks task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final done = task.isCompleted;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDeco(p),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 14),
      child: Stack(children: [
        Positioned(
          right: -40,
          top: -40,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.07), blurRadius: 40, spreadRadius: 20)],
            ),
          ),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: AnimatedCheck(value: done, onChanged: onToggle, size: 24),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                HeroTitle(
                  tag: 'task-title-${task.id}',
                  text: task.title,
                  fromStyle: TaskFmt.listTitle(context, done: false),
                  toStyle: TaskFmt.detailTitle(context),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TaskFmt.detailTitle(context, done: done),
                    child: Text(task.title),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(done ? Icons.check_circle_outline_rounded : Icons.bolt_rounded,
                      size: 14, color: p.accent),
                  const SizedBox(width: 4),
                  Text(done ? 'Completed' : 'In progress',
                      style: t.bodySmall?.copyWith(color: p.textMuted)),
                  Text('  •  ', style: t.bodySmall?.copyWith(color: p.textMuted)),
                  Flexible(
                    child: Text('Created ${TaskFmt.createdLabel(task.createdAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: p.textMuted)),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(children: [
      Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: p.textMuted, letterSpacing: 1, fontWeight: FontWeight.w700)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]);
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.task, required this.onEdit});
  final Tasks task;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final has = task.description != null && task.description!.trim().isNotEmpty;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        decoration: _cardDeco(p),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel('Notes',
              trailing: Icon(has ? Icons.description_outlined : Icons.edit_outlined,
                  size: 15, color: p.textMuted)),
          const SizedBox(height: 8),
          Text(has ? task.description!.trim() : 'Add notes…',
              style: t.bodyMedium?.copyWith(
                  height: 1.5, color: has ? p.textPrimary : p.textMuted)),
        ]),
      ),
    );
  }
}

class _SubtasksCard extends StatelessWidget {
  const _SubtasksCard({
    required this.subtasks,
    required this.loading,
    required this.error,
    required this.open,
    required this.saving,
    required this.controller,
    required this.focusNode,
    required this.onOpen,
    required this.onSubmit,
    required this.onToggle,
    required this.onDelete,
  });
  final List<SubtaskResponse>? subtasks;
  final bool loading;
  final bool error;
  final bool open;
  final bool saving;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onOpen;
  final VoidCallback onSubmit;
  final ValueChanged<SubtaskResponse> onToggle;
  final ValueChanged<SubtaskResponse> onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final list = subtasks ?? const <SubtaskResponse>[];
    final done = list.where((s) => s.isCompleted).length;
    final ratio = list.isEmpty ? 0.0 : done / list.length;
    final pct = (ratio * 100).round();

    return Container(
      decoration: _cardDeco(p),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('SUBTASKS',
              style: t.labelSmall?.copyWith(
                  color: p.textMuted, letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 999)),
            child: Text('$done/${list.length}',
                style: t.labelSmall?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('$pct% Done', style: t.labelSmall?.copyWith(color: p.textMuted)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: ratio),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: p.accent,
              backgroundColor: p.surface3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const SkeletonList(count: 2, height: 42)
        else if (error)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Could not load subtasks.',
                style: t.bodySmall?.copyWith(color: p.warning)),
          )
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(children: [
              for (final s in list)
                _SubtaskRow(
                  key: ValueKey<int>(s.id),
                  subtask: s,
                  onToggle: () => onToggle(s),
                  onDelete: () => onDelete(s),
                ),
            ]),
          ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: open
              ? _AddField(
                  key: const ValueKey('field'),
                  controller: controller,
                  focusNode: focusNode,
                  saving: saving,
                  onSubmit: onSubmit)
              : _GhostAdd(key: const ValueKey('ghost'), onTap: onOpen),
        ),
      ]),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow(
      {super.key,
      required this.subtask,
      required this.onToggle,
      required this.onDelete});
  final SubtaskResponse subtask;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final done = subtask.isCompleted;
    final radius = BorderRadius.circular(p.isTerminal ? 4 : 12);
    final danger = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss-${subtask.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.15), borderRadius: radius),
          child: Icon(Icons.delete_outline_rounded, color: danger, size: 20),
        ),
        child: GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(2, 0, 12, 0),
            decoration: BoxDecoration(
              color: p.usesGlass
                  ? (p.isDark
                      ? Color(done ? 0xB31F1F24 : 0xFF1F1F24)
                      : Color(done ? 0xB3ECEFF3 : 0xFFF1F4F8))
                  : p.surface2.withValues(alpha: done ? 0.7 : 1),
              borderRadius: radius,
            ),
            child: Row(children: [
              AnimatedCheck(value: done, onChanged: onToggle, rich: false),
              const SizedBox(width: 0),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: t.bodyMedium!.copyWith(
                    color: done ? p.textMuted : p.textPrimary,
                    decoration:
                        done ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: p.textMuted,
                  ),
                  child: Text(subtask.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Icon(done ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 16,
                  color: done ? p.accent.withValues(alpha: 0.8) : p.textMuted.withValues(alpha: 0.5)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GhostAdd extends StatelessWidget {
  const _GhostAdd({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: p.surface3.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_rounded, size: 18, color: p.accent),
          const SizedBox(width: 6),
          Text('Add subtask',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: p.accent)),
        ]),
      ),
    );
  }
}

class _AddField extends StatelessWidget {
  const _AddField(
      {super.key,
      required this.controller,
      required this.focusNode,
      required this.saving,
      required this.onSubmit});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: !saving,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
              hintText: 'New subtask… (empty + ✓ to close)', isDense: true),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: saving ? null : onSubmit,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 14)),
          child: saving
              ? Padding(
                  padding: const EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: p.onAccent))
              : Icon(Icons.check_rounded, color: p.onAccent),
        ),
      ),
    ]);
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid(
      {required this.task,
      required this.workMinutes,
      required this.onDeadline,
      required this.onClearDeadline});
  final Tasks task;
  final int workMinutes;
  final VoidCallback onDeadline;
  final VoidCallback onClearDeadline;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final due = task.dueDate;
    final overdue = TaskFmt.isOverdue(task);
    final warn = overdue ? p.warning : p.textMuted;

    Widget tile(IconData icon, Color iconColor) => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: p.surface3, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 15, color: iconColor),
        );

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: GestureDetector(
            onTap: onDeadline,
            child: Container(
              decoration: _cardDeco(p),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('DEADLINE',
                        style: t.labelSmall?.copyWith(
                            color: p.textMuted,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (due != null)
                    GestureDetector(
                      onTap: onClearDeadline,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.close_rounded, size: 14, color: p.textMuted),
                      ),
                    ),
                  tile(Icons.calendar_today_rounded, p.accent),
                ]),
                const SizedBox(height: 12),
                Text(due == null ? 'Set a date' : TaskFmt.dueLabel(due),
                    style: t.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(TaskFmt.dueRelative(task),
                    style: t.bodySmall?.copyWith(color: warn)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: _cardDeco(p),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('FOCUS',
                      style: t.labelSmall?.copyWith(
                          color: p.textMuted,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700)),
                ),
                tile(Icons.timer_outlined, p.warning),
              ]),
              const SizedBox(height: 12),
              Text('${workMinutes}m Sprint',
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('1 Pomodoro cycle',
                  style: t.bodySmall?.copyWith(color: p.textMuted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _FocusButton extends StatefulWidget {
  const _FocusButton({required this.minutes, required this.onTap});
  final int minutes;
  final VoidCallback onTap;
  @override
  State<_FocusButton> createState() => _FocusButtonState();
}

class _FocusButtonState extends State<_FocusButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 14),
            boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.play_arrow_rounded, color: p.onAccent, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text('START FOCUS ON THIS TASK',
                  overflow: TextOverflow.ellipsis,
                  style: t.labelLarge?.copyWith(
                      color: p.onAccent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(width: 6),
            Text('(${widget.minutes}m)',
                style: t.labelSmall?.copyWith(
                    color: p.onAccent.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── sheets ─────────────────────────

class _ActionSheet extends StatelessWidget {
  const _ActionSheet();
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final danger = Theme.of(context).colorScheme.error;
    Widget item(IconData i, String label, String value, Color c) => ListTile(
          leading: Icon(i, color: c),
          title: Text(label, style: TextStyle(color: c)),
          onTap: () => Navigator.of(context).pop(value),
        );
    return Container(
      decoration: AppDecor.sheet(p),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          item(Icons.edit_outlined, 'Edit details', 'edit', p.textPrimary),
          item(Icons.delete_outline_rounded, 'Delete task', 'delete', danger),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _PrioritySheet extends StatelessWidget {
  const _PrioritySheet({required this.current});
  final Priority current;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: AppDecor.sheet(p),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          for (final pr in Priority.values.reversed)
            ListTile(
              leading: PriorityDot(pr, size: 10),
              title: Text(pr.tag),
              trailing: pr == current
                  ? Icon(Icons.check_rounded, color: p.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(pr),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
