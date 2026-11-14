import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_palette.dart';

/// Formatting + shared text styles for task UIs.
///
/// Convention: a deadline at exactly 00:00 local means "date only / all day".
class TaskFmt {
  TaskFmt._();

  static bool hasTime(DateTime? d) => d != null && (d.hour != 0 || d.minute != 0);

  static DateTime startOfToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool isOverdue(Tasks t) {
    final d = t.dueDate;
    if (d == null || t.isCompleted) return false;
    return hasTime(d)
        ? d.isBefore(DateTime.now())
        : d.isBefore(startOfToday());
  }

  static String _dayWord(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(startOfToday()).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }

  /// "Today, 5:00 PM" / "Tomorrow" / "Fri, Oct 27".
  static String dueLabel(DateTime d) => hasTime(d)
      ? '${_dayWord(d)}, ${DateFormat.jm().format(d)}'
      : _dayWord(d);

  static String _span(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${math.max(1, d.inMinutes)}m';
  }

  /// "In ~2h" / "Overdue by 3d" / "Completed" / "No deadline".
  static String dueRelative(Tasks t) {
    final d = t.dueDate;
    if (t.isCompleted) return 'Completed';
    if (d == null) return 'No deadline';
    final end = hasTime(d) ? d : DateTime(d.year, d.month, d.day, 23, 59);
    final delta = end.difference(DateTime.now());
    return delta.isNegative
        ? 'Overdue by ${_span(delta.abs())}'
        : 'In ~${_span(delta)}';
  }

  static String createdLabel(DateTime? d) {
    if (d == null) return 'Just now';
    final delta = DateTime.now().difference(d);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return DateFormat('MMM d').format(d);
  }

  // ── text styles (list ↔ detail pair, used by the Hero flight too) ──

  static TextStyle listTitle(BuildContext c, {required bool done}) {
    final p = c.palette;
    return Theme.of(c).textTheme.bodyLarge!.copyWith(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w400,
          color: done ? p.textMuted : p.textPrimary,
        );
  }

  static TextStyle detailTitle(BuildContext c, {bool done = false}) {
    final p = c.palette;
    return Theme.of(c).textTheme.headlineSmall!.copyWith(
          color: p.textPrimary.withValues(alpha: done ? 0.5 : 1),
          decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: p.textMuted,
        );
  }
}
