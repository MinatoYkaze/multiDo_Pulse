import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../tasks/presentation/task_format.dart';
import 'groups_controller.dart';

class GroupTaskEditorSheet extends ConsumerStatefulWidget {
  const GroupTaskEditorSheet({
    super.key,
    required this.groupId,
    this.task,
    this.members = const [],
    this.canAssign = true,
  });

  final int groupId;
  final GroupTaskResponse? task;
  final List<GroupMemberResponse> members;
  final bool canAssign;

  static Future<GroupTaskResponse?> show(
    BuildContext context, {
    required int groupId,
    GroupTaskResponse? task,
    List<GroupMemberResponse> members = const [],
    bool canAssign = true,
  }) {
    return showModalBottomSheet<GroupTaskResponse>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => GroupTaskEditorSheet(
        groupId: groupId,
        task: task,
        members: members,
        canAssign: canAssign,
      ),
    );
  }

  @override
  ConsumerState<GroupTaskEditorSheet> createState() =>
      _GroupTaskEditorSheetState();
}

class _GroupTaskEditorSheetState extends ConsumerState<GroupTaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.task?.description ?? '');
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  DateTime? _date;
  TimeOfDay? _time;
  int? _assignedTo;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final d = widget.task?.dueDate;
    if (d != null) {
      _date = DateTime(d.year, d.month, d.day);
      if (TaskFmt.hasTime(d)) _time = TimeOfDay(hour: d.hour, minute: d.minute);
    }
    _assignedTo = widget.task?.assignedTo;
    if (_assignedTo == null && widget.members.isNotEmpty) {
      _assignedTo = widget.members.first.userId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  DateTime? get _due => _date == null
      ? null
      : DateTime(
          _date!.year,
          _date!.month,
          _date!.day,
          _time?.hour ?? 0,
          _time?.minute ?? 0,
        );

  Future<void> _pickDate() async {
    final today = TaskFmt.startOfToday();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    setState(() => _time = t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignedTo == null && widget.members.isNotEmpty) {
      _assignedTo = widget.members.first.userId;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        final updated = await ref
            .read(groupTasksControllerProvider(widget.groupId).notifier)
            .updateTask(
              widget.task!.id,
              GroupTaskUpdate(
                title: _title.text.trim(),
                description:
                    _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                priority: _priority,
                dueDate: _due,
                assignedTo:
                    widget.canAssign ? _assignedTo : widget.task!.assignedTo,
              ),
            );
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        final created = await ref
            .read(groupTasksControllerProvider(widget.groupId).notifier)
            .createTask(
              GroupTasksCreate(
                title: _title.text.trim(),
                description:
                    _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                priority: _priority,
                dueDate: _due,
                assignedTo: _assignedTo ?? (widget.members.isNotEmpty ? widget.members.first.userId : 1),
              ),
            );
        if (mounted) Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context);

    // Fallback members if none passed
    final membersAsync =
        ref.watch(groupMembersControllerProvider(widget.groupId));
    final memberList = widget.members.isNotEmpty
        ? widget.members
        : (membersAsync.valueOrNull ?? const []);

    return Padding(
      padding: insets,
      child: Container(
        decoration: AppDecor.sheet(p),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      _isEditing ? 'EDIT TASK' : 'NEW PROJECT TASK',
                      style: t.labelLarge?.copyWith(
                        letterSpacing: 1.2,
                        color: p.accent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: p.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: p.warningBg,
                      border: Border.all(color: p.warningBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: t.bodySmall?.copyWith(color: p.warning),
                    ),
                  ),
                ],
                TextFormField(
                  controller: _title,
                  autofocus: !_isEditing,
                  style: t.titleMedium,
                  decoration: const InputDecoration(
                    hintText: 'What needs to be done?',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a task title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  style: t.bodyMedium,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add description or notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                // Priority picker
                Text('PRIORITY',
                    style: t.labelSmall?.copyWith(color: p.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: Priority.values.map((pr) {
                    final sel = _priority == pr;
                    return ChoiceChip(
                      label: Text(pr.name.toUpperCase()),
                      selected: sel,
                      onSelected: (_) => setState(() => _priority = pr),
                      labelStyle: t.labelSmall?.copyWith(
                        color: sel ? p.onAccent : p.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedColor: p.accent,
                      backgroundColor: p.surface1,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Assignee picker
                Text('ASSIGN TO',
                    style: t.labelSmall?.copyWith(color: p.textMuted)),
                const SizedBox(height: 8),
                if (memberList.isEmpty)
                  Text(
                    'No members found in project.',
                    style: t.bodySmall?.copyWith(color: p.textMuted),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _assignedTo ?? memberList.first.userId,
                    dropdownColor: p.surface2,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: p.border),
                      ),
                      helperText: widget.canAssign
                          ? null
                          : 'Only project owner can reassign tasks',
                      helperStyle: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                    items: memberList.map((m) {
                      return DropdownMenuItem<int>(
                        value: m.userId,
                        child: Text(
                          '${m.displayName} (${m.role.name})',
                          style: t.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: widget.canAssign
                        ? (val) => setState(() => _assignedTo = val)
                        : null,
                  ),
                const SizedBox(height: 16),
                // Due date
                Text('DUE DATE',
                    style: t.labelSmall?.copyWith(color: p.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        _date == null
                            ? 'Set date'
                            : DateFormat('MMM d, y').format(_date!),
                      ),
                      onPressed: _pickDate,
                    ),
                    if (_date != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(_time == null ? 'Set time' : _time!.format(context)),
                        onPressed: _pickTime,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _date = null;
                          _time = null;
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'SAVE CHANGES' : 'CREATE TASK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
