import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';
import 'package:obsidian_todo/features/groups/presentation/widgets/group_task_row.dart';
import 'package:obsidian_todo/features/tasks/presentation/widgets/animated_check.dart';

void main() {
  testWidgets('GroupTaskRow taps AnimatedCheck calls onToggle', (tester) async {
    bool toggled = false;
    final task = GroupTaskResponse(
      id: 1,
      groupId: 1,
      title: 'Group Task',
      isCompleted: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppThemeVariant.obsidianPulse),
        home: Scaffold(
          body: GroupTaskRow(
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

    expect(toggled, isTrue, reason: 'Tapping AnimatedCheck in GroupTaskRow must trigger onToggle');
  });

  testWidgets('GroupTaskRow swipes and taps Done calls onToggle', (tester) async {
    bool toggled = false;
    final task = GroupTaskResponse(
      id: 1,
      groupId: 1,
      title: 'Group Task',
      isCompleted: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppThemeVariant.obsidianPulse),
        home: Scaffold(
          body: GroupTaskRow(
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
    await tester.drag(find.byType(GroupTaskRow), const Offset(200, 0));
    await tester.pumpAndSettle();

    final doneFinder = find.text('Done');
    expect(doneFinder, findsOneWidget);

    await tester.tap(doneFinder);
    await tester.pumpAndSettle();

    expect(toggled, isTrue, reason: 'Tapping Done swipe action in GroupTaskRow must trigger onToggle');
  });
}
