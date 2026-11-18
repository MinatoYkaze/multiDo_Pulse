import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../tasks/presentation/task_format.dart';
import '../../../tasks/presentation/widgets/priority_badge.dart';

class GroupTaskDraft {
  const GroupTaskDraft(
      {required this.title,
      this.description,
      required this.priority,
      this.dueDate,
      this.assignedTo});
  final String title;
  final String? description;
  final Priority priority;
  final DateTime? dueDate;
  final int? assignedTo;

  GroupTasksCreate toCreate() => GroupTasksCreate(
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assignedTo: assignedTo);

  GroupTaskUpdate toUpdate(bool? completed) => GroupTaskUpdate(
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assignedTo: assignedTo,
      isCompleted: completed);
}

UserPost memberAsUser(GroupMemberResponse m) =>
    UserPost(id: m.userId.toString(), email: m.email ?? '', name: m.name, picture: m.picture);

/// Create / edit sheet for group tasks (adds the assignee picker).
class GroupTaskEditorSheet extends StatefulWidget {
  const GroupTaskEditorSheet(
      {super.key, required this.members, this.task, this.defaultAssignee});
  final List<GroupMemberResponse> members;
  final GroupTaskResponse? task;
  final int? defaultAssignee;

  static Future<GroupTaskDraft?> show(BuildContext context,
          {required List<GroupMemberResponse> members,
          GroupTaskResponse? task,
          int? defaultAssignee}) =>
      showModalBottomSheet<GroupTaskDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => GroupTaskEditorSheet(
            members: members, task: task, defaultAssignee: defaultAssignee),
      );

  @override
  State<GroupTaskEditorSheet> createState() => _GroupTaskEditorSheetState();
}

class _GroupTaskEditorSheetState extends State<GroupTaskEditorSheet> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _notes = TextEditingController(text: widget.task?.description ?? '');
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  late int? _assignee = widget.task?.assignedTo ?? widget.defaultAssignee;
  DateTime? _date;
  TimeOfDay? _time;
  bool _showError = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final d = widget.task?.dueDate;
    if (d != null) {
      _date = DateTime(d.year, d.month, d.day);
      if (TaskFmt.hasTime(d)) _time = TimeOfDay(hour: d.hour, minute: d.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime? get _due => _date == null
      ? null
      : DateTime(_date!.year, _date!.month, _date!.day, _time?.hour ?? 0, _time?.minute ?? 0);

  Future<void> _pickDate() async {
    final today = TaskFmt.startOfToday();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() {
          _time = t;
          _date ??= TaskFmt.startOfToday();
        });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final notes = _notes.text.trim();
    Navigator.of(context).pop(GroupTaskDraft(
      title: title,
      description: notes.isEmpty ? null : notes,
      priority: _priority,
      dueDate: _due,
      assignedTo: _assignee,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(s,
              style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.4)),
        );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: AppDecor.sheet(p),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: p.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text(_editing ? 'Edit task' : 'New group task', style: t.titleMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: p.isTerminal ? '> task title' : 'Task title',
                  errorText: _showError && _title.text.trim().isEmpty ? 'Give it a title.' : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Notes (optional)'),
              ),
              const SizedBox(height: 16),
              label('PRIORITY'),
              Row(children: [
                for (final v in Priority.values) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _priority == v
                              ? v.color(context).withValues(alpha: 0.14)
                              : p.surface1,
                          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
                          border: Border.all(
                              color: _priority == v ? v.color(context) : p.border),
                        ),
                        child: Text(v.label,
                            style: t.labelMedium?.copyWith(
                                color: _priority == v ? v.color(context) : p.textMuted,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  if (v != Priority.values.last) const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 16),
              label('ASSIGNEE'),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  if (_editing)
                  _AssigneeChip(
                    selected: _assignee == null,
                    onTap: () => setState(() => _assignee = null),
                    child: Text('Unassigned', style: t.labelMedium),
                  ),
                  for (final m in widget.members)
                    _AssigneeChip(
                      selected: _assignee == m.userId,
                      onTap: () => setState(() => _assignee = m.userId),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        UserAvatar(user: memberAsUser(m), size: 22),
                        const SizedBox(width: 6),
                        Text(m.displayName.split(' ').first, style: t.labelMedium),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              label('DUE'),
              Row(children: [
                Expanded(
                  child: _PickBtn(
                    icon: Icons.calendar_today_rounded,
                    text: _date == null ? 'No date' : TaskFmt.dueLabel(_date!),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickBtn(
                    icon: Icons.schedule_rounded,
                    text: _time == null ? 'Add time' : _time!.format(context),
                    onTap: _pickTime,
                  ),
                ),
                if (_date != null)
                  IconButton(
                    tooltip: 'Clear date',
                    onPressed: () => setState(() {
                      _date = null;
                      _time = null;
                    }),
                    icon: Icon(Icons.close_rounded, color: p.textMuted),
                  ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _save,
                    child: Text(_editing ? 'SAVE CHANGES' : 'ADD TASK')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.accent.withValues(alpha: 0.12) : p.surface1,
            borderRadius: BorderRadius.circular(p.usesGlass ? 999 : 4),
            border: Border.all(color: selected ? p.accent : p.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PickBtn extends StatelessWidget {
  const _PickBtn({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: p.surface1,
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
          border: Border.all(color: p.border),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: p.accent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      ),
    );
  }
}
