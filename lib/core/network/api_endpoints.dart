/// Every path from the FastAPI (OpenAPI 3.1) spec, in one place.
class Api {
  Api._();

  /// Default deployed FastAPI origin on Render.
  static const baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://multido-api.onrender.com');

  /// Custom URL scheme the backend redirects to after Google OAuth
  /// (e.g. obsidiantodo://auth?access_token=...&refresh_token=...).
  static const callbackScheme = 'obsidiantodo';

  /// Secret key for developer access without regular sign-in.
  /// Can be overridden at launch: --dart-define=DEV_SECRET_KEY=...
  static const devSecretKey =
      String.fromEnvironment('DEV_SECRET_KEY', defaultValue: 'DEV2026');

  /// Set to true to automatically sign in as developer on startup:
  /// --dart-define=DEV_BYPASS=true
  static const devBypass =
      bool.fromEnvironment('DEV_BYPASS', defaultValue: false);

  // Auth
  static const googleLogin = '/auth/google/login';
  static const googleCallback = '/auth/google/callback';
  static const refresh = '/auth/refresh';
  static const me = '/auth/me';
  static const logout = '/auth/Logout'; // capital L, as in the spec

  // Personal tasks
  static const tasks = '/tasks/';
  static String task(int id) => '/tasks/$id';
  static String subtasks(int taskId) => '/tasks/$taskId/subtasks';
  static String subtask(int subtaskId) => '/tasks/subtasks/$subtaskId';

  // Groups
  static const groups = '/groups/';
  static String group(int id) => '/groups/$id';
  static String groupTasks(int g) => '/groups/$g/tasks';
  static String groupTask(int g, int t) => '/groups/$g/tasks/$t';
  static String groupMyTasks(int g) => '/groups/$g/my-tasks';
  static String groupSubtasks(int g, int t) => '/groups/$g/tasks/$t/subtasks';
  static String groupSubtask(int g, int s) => '/groups/$g/tasks/subtasks/$s';
  static String groupMembers(int g) => '/groups/$g/members';
  static String groupInvite(int g) => '/groups/$g/invite';
  static String acceptInvitation(String token) =>
      '/groups/invitations/$token/accept';
  static String invitationPreview(String token) =>
      '/groups/invitations/$token/preview';
  static String groupLeave(int g) => '/groups/$g/leave';
  static String groupMember(int g, int userId) => '/groups/$g/members/$userId';

  // AI
  static const aiChat = '/ai/chat';
  static const aiConversation = '/ai/conversation';
}
