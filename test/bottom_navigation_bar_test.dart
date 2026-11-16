import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obsidian_todo/core/router/app_shell.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';

void main() {
  Widget buildShell({
    required Size screenSize,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final router = GoRouter(
      initialLocation: '/projects',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => MediaQuery(
            data: MediaQueryData(size: screenSize, padding: padding),
            child: AppShell(shell: shell),
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/today', builder: (_, __) => const Text('Today Content')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/focus', builder: (_, __) => const Text('Focus Content')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/projects', builder: (_, __) => const Text('Projects Content')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/analytics', builder: (_, __) => const Text('Analytics Content')),
            ]),
          ],
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.build(AppThemeVariant.obsidianApplePrecision),
        routerConfig: router,
      ),
    );
  }

  testWidgets('Bottom navigation items are spaced equally and aligned properly on Web/Desktop',
      (tester) async {
    const screenSize = Size(1024, 768);
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildShell(screenSize: screenSize));
    await tester.pumpAndSettle();

    // Verify all 4 bottom navigation labels exist
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('ANALYTICS'), findsOneWidget);

    // Verify positions of icons and labels
    final todayCenter = tester.getCenter(find.text('TODAY'));
    final focusCenter = tester.getCenter(find.text('FOCUS'));
    final projectsCenter = tester.getCenter(find.text('PROJECTS'));
    final analyticsCenter = tester.getCenter(find.text('ANALYTICS'));

    // Verify vertical alignment across all labels (all labels on exact same horizontal baseline)
    expect(todayCenter.dy, equals(focusCenter.dy));
    expect(focusCenter.dy, equals(projectsCenter.dy));
    expect(projectsCenter.dy, equals(analyticsCenter.dy));

    // Verify consistent horizontal spacing (distance between adjacent items is equal)
    final d1 = focusCenter.dx - todayCenter.dx;
    final d2 = projectsCenter.dx - focusCenter.dx;
    final d3 = analyticsCenter.dx - projectsCenter.dx;
    expect((d1 - d2).abs(), lessThan(1.0));
    expect((d2 - d3).abs(), lessThan(1.0));

    // Verify bottom distance is not crammed against edge (lifted upward by at least 10px)
    expect(screenSize.height - todayCenter.dy, greaterThan(15.0));
  });

  testWidgets('Bottom navigation respects mobile safe area with home indicator',
      (tester) async {
    const screenSize = Size(390, 844);
    const insets = EdgeInsets.only(bottom: 34);
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildShell(screenSize: screenSize, padding: insets));
    await tester.pumpAndSettle();

    final projectsCenter = tester.getCenter(find.text('PROJECTS'));

    // Distance from bottom of screen should comfortably clear the 34px home indicator
    final distanceFromBottom = screenSize.height - projectsCenter.dy;
    expect(distanceFromBottom, greaterThanOrEqualTo(34.0 + 10.0));
  });
}
