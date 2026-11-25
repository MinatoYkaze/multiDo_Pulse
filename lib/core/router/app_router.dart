import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/ai/presentation/ai_chat_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/groups/presentation/group_workspace_screen.dart';
import '../../features/groups/presentation/invitations_inbox_screen.dart';
import '../../features/groups/presentation/projects_dashboard_screen.dart';
import '../../features/groups/presentation/projects_screen.dart';
import '../../features/groups/presentation/workspace_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/tasks/presentation/task_detail_screen.dart';
import '../../features/tasks/presentation/today_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/focus/presentation/milestone_screen.dart';
import 'app_shell.dart';

class Routes {
  Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const today = '/today';
  static const focus = '/focus';
  static const projects = '/projects';
  static String project(int id) => '/projects/$id';
  static const analytics = '/analytics';
  static const milestone = '/focus/milestone';
  static String workspace(int id) => '/projects/$id';
  static const settings = '/settings';
  static const ai = '/ai';
  static const invitations = '/invitations';

  /// Nested under the Today branch so the bottom nav stays visible and the
  /// title Hero can fly (heroes don't cross nested-navigator boundaries).
  static String task(int id) => '/today/tasks/$id';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluates `redirect` whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext _, GoRouterState s) {
    final auth = ref.read(authControllerProvider);
    final path = s.uri.path;
    final isSplash = path == Routes.splash;
    final isLogin = path == Routes.login;

    // Where the user originally wanted to go (deep link, e.g. /invite/abc).
    String? from() {
      String? f;
      if (isSplash || isLogin) {
        f = s.uri.queryParameters['from'];
      } else if (path != Routes.today && path != '/') {
        f = s.uri.toString();
      }
      if (f == null || f.startsWith(Routes.login) || f.startsWith(Routes.splash)) {
        return null;
      }
      return f;
    }

    String withFrom(String base) {
      final f = from();
      return f == null ? base : '$base?from=${Uri.encodeComponent(f)}';
    }

    if (auth.isLoading && !auth.hasValue) {
      return isSplash ? null : withFrom(Routes.splash);
    }
    if (auth.valueOrNull == null) {
      return isLogin ? null : withFrom(Routes.login);
    }
    if (isSplash || isLogin || path == '/') return from() ?? Routes.today;
    return null;
  }

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.today,
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.invitations,
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const InvitationsInboxScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          child: const SettingsScreen(),
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
        ),
      ),
      GoRoute(
        path: Routes.ai,
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          child: AIChatScreen(
            initialThreadId: s.uri.queryParameters['thread_id'],
          ),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.today,
              builder: (_, __) => const TodayScreen(),
              routes: [
                GoRoute(
                  path: 'tasks/:id',
                  pageBuilder: (_, s) => CustomTransitionPage(
                    key: s.pageKey,
                    child: TaskDetailScreen(
                        taskId: int.tryParse(s.pathParameters['id'] ?? '') ?? -1),
                    transitionDuration: const Duration(milliseconds: 380),
                    reverseTransitionDuration:
                        const Duration(milliseconds: 300),
                    transitionsBuilder: (_, anim, __, child) {
                      final curved = CurvedAnimation(
                          parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
                      return FadeTransition(
                        opacity: CurvedAnimation(
                            parent: anim, curve: Curves.easeOut),
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero)
                              .animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.focus,
              builder: (_, __) => const FocusScreen(),
              routes: [
                GoRoute(
                  path: 'milestone',
                  pageBuilder: (_, s) => CustomTransitionPage(
                    key: s.pageKey,
                    child: const MilestoneScreen(),
                    transitionDuration: const Duration(milliseconds: 420),
                    reverseTransitionDuration: const Duration(milliseconds: 300),
                    transitionsBuilder: (_, anim, __, child) {
                      final curved = CurvedAnimation(
                          parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
                      return FadeTransition(
                        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.06), end: Offset.zero)
                              .animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.projects,
              builder: (_, __) => const ProjectsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (_, s) => CustomTransitionPage(
                    key: s.pageKey,
                    child: WorkspaceScreen(
                        groupId: int.tryParse(s.pathParameters['id'] ?? '') ?? -1),
                    transitionDuration: const Duration(milliseconds: 360),
                    reverseTransitionDuration: const Duration(milliseconds: 280),
                    transitionsBuilder: (_, anim, __, child) {
                      final curved = CurvedAnimation(
                          parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
                      return FadeTransition(
                        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0.06, 0), end: Offset.zero)
                              .animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.analytics,
                builder: (_, __) => const AnalyticsScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);

  return router;
});
