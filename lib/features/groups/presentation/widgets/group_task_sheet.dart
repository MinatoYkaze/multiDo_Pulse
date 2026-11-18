import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_controller.dart';
import '../../../../core/models/models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../tasks/presentation/task_format.dart';
import '../../../tasks/presentation/widgets/animated_check.dart';
import '../../../tasks/presentation/widgets/priority_badge.dart';
import '../groups_providers.dart';
import 'group_task_editor_sheet.dart';

/// Bottom sheet with a group task's details and full subtask CRUD.
class GroupTaskSheet extends ConsumerStatefulWidget {
  const GroupTaskSheet({super.key, required this.groupId, required this.taskId});
  final int groupId, taskId;

  static Future<void> show(BuildContext context,
          {required int groupId, required int taskId}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => GroupTaskSheet(groupId: groupId, taskId: taskId),
      );

  @override
  ConsumerState<GroupTaskSheet> createState() => _GroupTaskSheetState();
}

class _GroupTaskSheetState extends ConsumerState<GroupTaskSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _adding = false;

  GroupTaskKey get _key => (groupId: widget.groupId, taskId: widget.taskId);

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _err(Object e) {
    if (mounted) showAppSnack(context, ApiException.from(e).message, error: true, bottom: 24);
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _addSub() async {
    final v = _input.text.trim();
    if (v.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    _input.clear();
    ref.read(hapticsProvider).light();
    await _run(() => ref.read(groupSubtasksProvider(_key).notifier).add(v));
    if (mounted) _focus.requestFocus();
  }

  Future<void> _edit(GroupTaskResponse t) async {
    final members = ref.read(groupMembersProvider(widget.groupId)).valueOrNull ?? const [];
    final d = await GroupTaskEditorSheet.show(context, members: members, task: t);
    if (d == null) return;
    await _run(() => ref
        .read(groupTasksProvider(widget.groupId).notifier)
        .edit(t, d.toUpdate(null)));
  }

  Future<void> _delete(GroupTaskResponse t) async {
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
    try {
      await ref.read(groupTasksProvider(widget.groupId).notifier).remove(t);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _rename(GroupSubtaskResponse s) async {
    final c = TextEditingController(text: s.title);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename subtask'),
        content: TextField(
            controller: c,
            autofocus: true,
            onSubmitted: (x) => Navigator.pop(ctx, x.trim())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (v != null && v.isNotEmpty && v != s.title) {
      await _run(() => ref.read(groupSubtasksProvider(_key).notifier).rename(s, v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tasks = ref.watch(groupTasksProvider(widget.groupId)).valueOrNull;
    final task = tasks?.firstWhereOrNull((x) => x.id == widget.taskId);
    final subs = ref.watch(groupSubtasksProvider(_key));
    final members = ref.watch(groupMembersProvider(widget.groupId)).valueOrNull ?? const [];

    if (task == null) {
      return Container(
        height: 200,
        decoration: AppDecor.sheet(p),
        child: Center(child: CircularProgressIndicator(color: p.accent)),
      );
    }
    final assignee = members.firstWhereOrNull((m) => m.userId == task.assignedTo);
    final name = assignee?.displayName ?? task.assigneeName;
    final list = subs.valueOrNull ?? const <GroupSubtaskResponse>[];
    final done = list.where((s) => s.isCompleted).length;
    final progress = list.isEmpty ? 0.0 : done / list.length;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: AppDecor.sheet(p),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: p.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2))),
              ),
              Row(children: [
                PriorityBadge(priority: task.priority),
                const Spacer(),
                _IconBtn(icon: Icons.edit_outlined, onTap: () => _edit(task)),
                const SizedBox(width: 6),
                _IconBtn(icon: Icons.delete_outline_rounded, danger: true, onTap: () => _delete(task)),
                const SizedBox(width: 6),
                _IconBtn(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecor.card(p),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: AnimatedCheck(
                      value: task.isCompleted,
                      size: 24,
                      onChanged: () {
                        final h = ref.read(hapticsProvider);
                        if (!task.isCompleted) {
                          h.success();
                          ref.read(audioFxProvider).playChime();
                        } else {
                          h.light();
                        }
                        _run(() => ref.read(groupTasksProvider(widget.groupId).notifier).toggle(task));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(task.title,
                          style: t.headlineSmall?.copyWith(
                              color: task.isCompleted ? p.textMuted : p.textPrimary,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              decorationColor: p.textMuted)),
                      if (task.description?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        Text(task.description!.trim(),
                            style: t.bodyMedium?.copyWith(height: 1.5)),
                      ],
                      const SizedBox(height: 12),
                      Wrap(spacing: 14, runSpacing: 8, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (name != null)
                            UserAvatar(
                                user: assignee != null
                                    ? memberAsUser(assignee)
                                    : UserPost(email: '', name: name),
                                size: 20)
                          else
                            Icon(Icons.person_outline_rounded, size: 16, color: p.textMuted),
                          const SizedBox(width: 6),
                          Text(name ?? 'Unassigned', style: t.labelMedium),
                        ]),
                        if (task.dueDate != null)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.alarm_rounded, size: 14, color: p.accent),
                            const SizedBox(width: 4),
                            Text(TaskFmt.dueLabel(task.dueDate!), style: t.labelMedium),
                          ]),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecor.card(p),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('SUBTASKS',
                        style: t.labelSmall?.copyWith(
                            color: p.textMuted, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: p.surface3, borderRadius: BorderRadius.circular(999)),
                      child: Text('$done/${list.length}',
                          style: t.labelSmall?.copyWith(
                              color: p.accent, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    Text('${(progress * 100).round()}% Done',
                        style: t.labelSmall?.copyWith(color: p.textMuted)),
                  ]),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (_, c) => Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: p.surface3, borderRadius: BorderRadius.circular(999)),
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        width: c.maxWidth * progress,
                        decoration: BoxDecoration(
                            color: p.accent, borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (subs.isLoading && list.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                  else if (subs.hasError && list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(ApiException.from(subs.error!).message,
                          style: t.bodySmall?.copyWith(color: p.warning)),
                    )
                  else
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(children: [
                        for (final s in list)
                          Dismissible(
                            key: ValueKey('gsub-${s.id}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              ref.read(hapticsProvider).medium();
                              _run(() => ref.read(groupSubtasksProvider(_key).notifier).remove(s));
                            },
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            child: GestureDetector(
                              onLongPress: () => _rename(s),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                    color: p.surface2, borderRadius: BorderRadius.circular(10)),
                                child: Row(children: [
                                  AnimatedCheck(
                                    value: s.isCompleted,
                                    size: 18,
                                    onChanged: () {
                                      ref.read(hapticsProvider).light();
                                      _run(() => ref.read(groupSubtasksProvider(_key).notifier).toggle(s));
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(s.title,
                                        style: t.bodyMedium?.copyWith(
                                            color: s.isCompleted ? p.textMuted : p.textPrimary,
                                            decoration: s.isCompleted ? TextDecoration.lineThrough : null,
                                            decorationColor: p.textMuted)),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  if (_adding)
                    Container(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      decoration: BoxDecoration(
                        color: p.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.accent),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            focusNode: _focus,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'New subtask…',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onSubmitted: (_) => _addSub(),
                          ),
                        ),
                        IconButton(
                            onPressed: _addSub,
                            icon: Icon(Icons.arrow_upward_rounded, color: p.accent)),
                      ]),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        setState(() => _adding = true);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _focus.requestFocus());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_rounded, size: 18, color: p.textMuted),
                          const SizedBox(width: 6),
                          Text('Add subtask', style: t.labelLarge?.copyWith(color: p.textMuted)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.danger = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = danger ? Theme.of(context).colorScheme.error : p.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 17),
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, size: 17, color: c),
      ),
    );
  }
}
