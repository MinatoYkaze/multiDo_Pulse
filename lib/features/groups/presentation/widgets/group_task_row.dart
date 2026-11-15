import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../tasks/presentation/task_format.dart';
import '../../../tasks/presentation/widgets/animated_check.dart';
import '../../../tasks/presentation/widgets/motion_widgets.dart';
import '../../../tasks/presentation/widgets/priority_badge.dart';
import 'group_task_editor_sheet.dart';

class GroupTaskRow extends StatefulWidget {
  const GroupTaskRow({
    super.key,
    required this.task,
    required this.index,
    required this.rich,
    this.assignee,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final GroupTaskResponse task;
  final int index;
  final bool rich;
  final GroupMemberResponse? assignee;
  final VoidCallback onToggle, onOpen, onEdit;
  final Future<bool> Function() onDelete;

  @override
  State<GroupTaskRow> createState() => _GroupTaskRowState();
}

class _GroupTaskRowState extends State<GroupTaskRow> {
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final task = widget.task;
    final done = task.isCompleted;
    final radius = BorderRadius.circular(p.isTerminal ? 4 : 14);
    final due = task.dueDate;
    final overdue = !done &&
        due != null &&
        (TaskFmt.hasTime(due) ? due.isBefore(DateTime.now()) : due.isBefore(TaskFmt.startOfToday()));
    final name = widget.assignee?.displayName ?? task.assigneeName;

    final card = GestureDetector(
      onTap: widget.onOpen,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: done ? 0.55 : 1,
        child: Container(
          decoration: AppDecor.card(p, dimmed: done),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnimatedCheck(
                        value: done, onChanged: widget.onToggle, size: 20, rich: widget.rich),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: StrikeText(
                            task.title,
                            struck: done,
                            lineColor: p.textMuted,
                            style: t.bodyLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                                color: done ? p.textMuted : p.textPrimary),
                          ),
                        ),
                        if (!done && task.priority != Priority.low) ...[
                          const SizedBox(width: 8),
                          _Tag(priority: task.priority),
                        ],
                      ]),
                      if (task.description?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(task.description!.trim(),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                      ],
                    ]),
                  ),
                ]),
              ),
              // footer strip: assignee · due · subtask count
              Container(
                color: p.isDark
                    ? Colors.white.withValues(alpha: 0.025)
                    : Colors.black.withValues(alpha: 0.025),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  if (name != null) ...[
                    UserAvatar(
                        user: widget.assignee != null
                            ? memberAsUser(widget.assignee!)
                            : UserPost(email: '', name: name),
                        size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis, style: t.labelSmall)),
                  ] else ...[
                    Icon(Icons.person_outline_rounded, size: 16, color: p.textMuted),
                    const SizedBox(width: 6),
                    Text('Unassigned', style: t.labelSmall?.copyWith(color: p.textMuted)),
                  ],
                  const Spacer(),
                  if (task.subtasks.isNotEmpty) ...[
                    Icon(Icons.checklist_rounded, size: 14, color: p.textMuted),
                    const SizedBox(width: 3),
                    Text('${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                        style: t.labelSmall?.copyWith(color: p.textMuted)),
                    const SizedBox(width: 10),
                  ],
                  if (due != null && !done) ...[
                    Icon(Icons.alarm_rounded,
                        size: 13, color: overdue ? p.warning : p.textMuted),
                    const SizedBox(width: 4),
                    Text(TaskFmt.dueLabel(due),
                        style: t.labelSmall?.copyWith(
                            color: overdue ? p.warning : p.textMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

    final slidable = Slidable(
      key: ValueKey('slide-gt-${task.id}'),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.26,
        children: [
          _Act(
            icon: done ? Icons.undo_rounded : Icons.check_rounded,
            label: done ? 'Undo' : 'Done',
            color: p.accent,
            radius: radius,
            onTap: widget.onToggle,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.5,
        children: [
          _Act(
              icon: Icons.edit_outlined,
              label: 'Edit',
              color: p.textPrimary,
              radius: radius,
              onTap: widget.onEdit),
          _Act(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Theme.of(context).colorScheme.error,
              radius: radius,
              onTap: _confirmDelete),
        ],
      ),
      child: card,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _removing
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Entrance(index: widget.index, enabled: widget.rich, child: slidable),
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.priority});
  final Priority priority;
  @override
  Widget build(BuildContext context) {
    final c = priority.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.palette.isTerminal ? 2 : 6),
      ),
      child: Text(
        priority == Priority.high ? 'P1 CRITICAL' : 'P2',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: c, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act(
      {required this.icon,
      required this.label,
      required this.color,
      required this.radius,
      required this.onTap});
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
      padding: EdgeInsets.zero,
      borderRadius: radius,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: radius,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
