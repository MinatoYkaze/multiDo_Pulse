import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../task_format.dart';
import 'animated_check.dart';
import 'motion_widgets.dart';
import 'priority_badge.dart';

/// One card in the Today stream: spring checkbox, animated strike-through,
/// Hero title, trailing badge, swipe actions (right = complete, left = edit /
/// delete) and a collapse animation on delete.
class TaskRow extends StatefulWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.index,
    required this.rich,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Tasks task;
  final int index;
  final bool rich;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  /// Performs the delete; resolves `true` on success.
  final Future<bool> Function() onDelete;

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _removing = false;

  Future<void> _confirmDelete() async {
    final t = widget.task;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Task?',
      message: TextSpan(children: [
        const TextSpan(text: 'Are you sure you want to delete '),
        TextSpan(
            text: '"${t.title}"',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        const TextSpan(text: '? This cannot be undone.'),
      ]),
      confirmLabel: 'Delete Task',
    );
    if (!ok || !mounted) return;
    setState(() => _removing = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final done = await widget.onDelete();
    if (!done && mounted) setState(() => _removing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final done = t.isCompleted;
    final radius =
        BorderRadius.circular(context.palette.isTerminal ? 4 : 14);

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Entrance(
        index: widget.index,
        enabled: widget.rich,
        child: Slidable(
          key: ValueKey('slide-${t.id}'),
          startActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.26,
            children: [
              _SwipeAction(
                icon: done ? Icons.undo_rounded : Icons.check_rounded,
                label: done ? 'Undo' : 'Done',
                color: context.palette.accent,
                radius: radius,
                onTap: widget.onToggle,
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.5,
            children: [
              _SwipeAction(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: context.palette.textPrimary,
                radius: radius,
                onTap: widget.onEdit,
              ),
              _SwipeAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: Theme.of(context).colorScheme.error,
                radius: radius,
                onTap: _confirmDelete,
              ),
            ],
          ),
          child: _Card(
            task: t,
            rich: widget.rich,
            radius: radius,
            onOpen: widget.onOpen,
            onToggle: widget.onToggle,
          ),
        ),
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _removing
          ? const SizedBox(width: double.infinity)
          : AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              child: content),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.task,
    required this.rich,
    required this.radius,
    required this.onOpen,
    required this.onToggle,
  });
  final Tasks task;
  final bool rich;
  final BorderRadius radius;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final done = task.isCompleted;

    final bg = p.usesGlass
        ? (p.isDark
            ? Colors.white.withValues(alpha: done ? 0.015 : 0.03)
            : (done ? const Color(0xFFF1F3F6) : Colors.white))
        : (done ? p.base : p.surface1);
    final border = p.usesGlass
        ? (p.isDark
            ? Colors.white.withValues(alpha: done ? 0.04 : 0.06)
            : (done ? p.border.withValues(alpha: 0.5) : p.border))
        : p.border.withValues(alpha: done ? 0.5 : 1);

    final listStyle = TaskFmt.listTitle(context, done: done);
    final subtasks = task.subtasks;

    return AnimatedOpacity(
      opacity: done ? 0.5 : 1,
      duration: const Duration(milliseconds: 300),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
            color: bg, borderRadius: radius, border: Border.all(color: border)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(children: [
                AnimatedCheck(
                    value: done, onChanged: onToggle, rich: rich, size: 20),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HeroTitle(
                          tag: 'task-title-${task.id}',
                          text: task.title,
                          fromStyle: TaskFmt.listTitle(context, done: false),
                          toStyle: TaskFmt.detailTitle(context),
                          child: StrikeText(
                            task.title,
                            struck: done,
                            style: listStyle,
                            lineColor: p.textMuted,
                          ),
                        ),
                        if (subtasks.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(children: [
                              Icon(Icons.checklist_rounded,
                                  size: 13, color: p.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                  '${subtasks.where((s) => s.isCompleted).length}/${subtasks.length}',
                                  style: t.bodySmall
                                      ?.copyWith(color: p.textMuted)),
                            ]),
                          ),
                      ]),
                ),
                const SizedBox(width: 12),
                _Trailing(task: task),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.task});
  final Tasks task;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: p.textMuted, fontSize: 12);
    if (task.isCompleted) return Text('Done', style: style);
    if (TaskFmt.isOverdue(task)) {
      return Text('Overdue', style: style?.copyWith(color: p.warning));
    }
    if (TaskFmt.hasTime(task.dueDate)) {
      return Text(DateFormat.jm().format(task.dueDate!), style: style);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PriorityDot(task.priority),
      const SizedBox(width: 6),
      Text(task.priority.label, style: style?.copyWith(fontSize: 10, letterSpacing: 0.6)),
    ]);
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.radius,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onTap(),
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: radius,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontSize: 9)),
        ]),
      ),
    );
  }
}
