import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';
import 'package:obsidian_todo/features/tasks/presentation/widgets/animated_check.dart';
import 'package:obsidian_todo/features/tasks/presentation/widgets/task_row.dart';

void main() {
  testWidgets('TaskRow taps AnimatedCheck calls onToggle', (tester) async {
    bool toggled = false;
    final task = Tasks(id: 1, title: 'Test Task', isCompleted: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppThemeVariant.obsidianPulse),
        home: Scaffold(
          body: TaskRow(
            task: task,
            index: 0,
            rich: false,
            onToggle: () {
              toggled = true;
            },
            onOpen: () {},
            onEdit: () {},
            onDelete: () async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final checkFinder = find.byType(AnimatedCheck);
    expect(checkFinder, findsOneWidget);

    await tester.tap(checkFinder);
    await tester.pumpAndSettle();

    expect(toggled, isTrue, reason: 'Tapping AnimatedCheck must trigger onToggle');
  });

  testWidgets('TaskRow swipes and taps Done calls onToggle', (tester) async {
    bool toggled = false;
    final task = Tasks(id: 1, title: 'Test Task', isCompleted: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppThemeVariant.obsidianPulse),
        home: Scaffold(
          body: TaskRow(
            task: task,
            index: 0,
            rich: false,
            onToggle: () {
              toggled = true;
            },
            onOpen: () {},
            onEdit: () {},
            onDelete: () async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Drag from left to right to reveal the start action pane ("Done")
    await tester.drag(find.byType(TaskRow), const Offset(200, 0));
    await tester.pumpAndSettle();

    final doneFinder = find.text('DONE');
    expect(doneFinder, findsOneWidget);

    await tester.tap(doneFinder);
    await tester.pumpAndSettle();

    expect(toggled, isTrue, reason: 'Tapping Done swipe action must trigger onToggle');
  });
}
