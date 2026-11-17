import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';
import 'package:obsidian_todo/features/groups/presentation/groups_controller.dart';
import 'package:obsidian_todo/features/groups/presentation/projects_dashboard_screen.dart';

void main() {
  testWidgets('ProjectsDashboardScreen displays empty state when no projects',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupsControllerProvider.overrideWith(() => _MockEmptyGroupsController()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppThemeVariant.obsidianApplePrecision),
          home: const ProjectsDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('CREATE PROJECT'), findsOneWidget);
  });

  testWidgets('ProjectsDashboardScreen displays projects list with progress',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupsControllerProvider.overrideWith(() => _MockPopulatedGroupsController()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppThemeVariant.obsidianApplePrecision),
          home: const ProjectsDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('MultiDo Mobile App'), findsOneWidget);
    expect(find.text('Backend API Integration'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2 / 3 members'), findsOneWidget);
    expect(find.text('1/2 tasks'), findsOneWidget);
  });
}

class _MockEmptyGroupsController extends GroupsController {
  @override
  Future<List<Group>> build() async => const [];
}

class _MockPopulatedGroupsController extends GroupsController {
  @override
  Future<List<Group>> build() async => const [
        Group(
          id: 1,
          name: 'MultiDo Mobile App',
          description: 'Backend API Integration',
          memberCount: 2,
          taskCount: 2,
          completedTaskCount: 1,
        ),
      ];
}
