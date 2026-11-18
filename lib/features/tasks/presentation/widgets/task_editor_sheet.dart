import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../task_format.dart';
import 'priority_badge.dart';

/// Create / edit sheet. Resolves a [TasksPost] (or null when dismissed).
class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, this.task, this.initialTitle = ''});
  final Tasks? task;
  final String initialTitle;

  static Future<TasksPost?> show(BuildContext context,
          {Tasks? task, String initialTitle = ''}) =>
      showModalBottomSheet<TasksPost>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => TaskEditorSheet(task: task, initialTitle: initialTitle),
      );

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? widget.initialTitle);
  late final TextEditingController _notes =
      TextEditingController(text: widget.task?.description ?? '');
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  DateTime? _date; // date part only
  TimeOfDay? _time;

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
      : DateTime(_date!.year, _date!.month, _date!.day, _time?.hour ?? 0,
          _time?.minute ?? 0);

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
    if (t != null) setState(() => _time = t);
  }

  void _setDay(int plusDays) => setState(
      () => _date = TaskFmt.startOfToday().add(Duration(days: plusDays)));

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final notes = _notes.text.trim();
    final had = widget.task?.description?.isNotEmpty == true;
    Navigator.of(context).pop(TasksPost(
      title: title,
      description: notes.isEmpty ? (had ? '' : null) : notes,
      priority: _priority,
      dueDate: _due,
      clearDueDate: _due == null,
      isCompleted: widget.task?.isCompleted,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final today = TaskFmt.startOfToday();
    final isToday = _date != null && _date == today;
    final isTomorrow =
        _date != null && _date == today.add(const Duration(days: 1));

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: AppDecor.sheet(p),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text(_editing ? 'Edit Task' : 'New Task',
                      style: t.titleMedium?.copyWith(fontSize: 19)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _title,
                    autofocus: !_editing,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Task title'),
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
                  _Label('PRIORITY', p, t),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final pr in Priority.values) ...[
                      Expanded(
                        child: _PriorityChoice(
                          priority: pr,
                          selected: pr == _priority,
                          onTap: () => setState(() => _priority = pr),
                        ),
                      ),
                      if (pr != Priority.values.last) const SizedBox(width: 8),
                    ],
                  ]),
                  const SizedBox(height: 16),
                  _Label('DEADLINE', p, t),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Chip('Today', selected: isToday, onTap: () => _setDay(0)),
                    _Chip('Tomorrow',
                        selected: isTomorrow, onTap: () => _setDay(1)),
                    _Chip(
                      _date == null || isToday || isTomorrow
                          ? 'Pick date'
                          : DateFormat('EEE, MMM d').format(_date!),
                      icon: Icons.calendar_today_rounded,
                      selected: _date != null && !isToday && !isTomorrow,
                      onTap: _pickDate,
                    ),
                    if (_date != null)
                      _Chip(
                        _time == null ? 'Add time' : _time!.format(context),
                        icon: Icons.schedule_rounded,
                        selected: _time != null,
                        onTap: _pickTime,
                      ),
                    if (_date != null)
                      _Chip('Clear',
                          icon: Icons.close_rounded,
                          selected: false,
                          onTap: () => setState(() {
                                _date = null;
                                _time = null;
                              })),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _title.text.trim().isEmpty ? null : _save,
                        child: Text(_editing ? 'Save Changes' : 'Add Task'),
                      ),
                    ),
                  ]),
                ]),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.p, this.t);
  final String text;
  final AppPalette p;
  final TextTheme t;
  @override
  Widget build(BuildContext context) => Text(text,
      style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1));
}

class _PriorityChoice extends StatelessWidget {
  const _PriorityChoice(
      {required this.priority, required this.selected, required this.onTap});
  final Priority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = priority.color(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
          border: Border.all(color: selected ? c : Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PriorityDot(priority),
          const SizedBox(width: 6),
          Text(priority.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? c : p.textMuted,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label,
      {required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? p.accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 999),
          border: Border.all(
              color: selected ? p.accent.withValues(alpha: 0.6) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? p.accent : p.textMuted),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? p.accent : p.textPrimary)),
        ]),
      ),
    );
  }
}
