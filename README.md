# Obsidian Todo (Flutter)
Phase 1: pubspec, folder structure, both themes, Dio client + QueuedInterceptor, all models.

    flutter create . --platforms=android,ios
    flutter pub get
    flutter run --dart-define=API_BASE_URL=https://your-api.example.com

Models/endpoints were inferred from schema names; verify against your openapi.json.

## Phase 2 notes
- **Google OAuth**: backend must finish the flow by redirecting to
  `obsidiantodo://auth?access_token=…&refresh_token=…` (or `?code=&state=`).
  - Android: in `AndroidManifest.xml` add inside `<application>`:
    ```xml
    <activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="true">
      <intent-filter android:label="flutter_web_auth_2">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="obsidiantodo"/>
      </intent-filter>
    </activity>
    ```
  - iOS: add `obsidiantodo` under `CFBundleURLTypes` in `Info.plist`.
  - Web/desktop: use the "DEV: SECRET KEY / ACCESS TOKEN" button (debug builds).
- **Developer Secret Key Bypass (No sign-in required)**:
  - Default key: `DEV2026`
  - Option 1 (In-App): Click `DEV: SECRET KEY / ACCESS TOKEN` on the login screen (or tap the Pulse logo 5 times) and tap **Sign In With Secret Key**.
  - Option 2 (Auto sign-in at launch):
    ```bash
    flutter run --dart-define=DEV_BYPASS=true
    ```
  - Option 3 (Custom secret key):
    ```bash
    flutter run --dart-define=DEV_SECRET_KEY=your_custom_key
    ```
- **Invite deep links**: `https://<your-domain>/invite/<token>` → `/invite/:token`
  (signed-out users are sent to login first and returned afterwards).

## Phase 3 notes (personal tasks)
- **Today** (`today_tasks_1` + `today_tasks_2`): one screen, two looks. The ✨ header
  button toggles *rich motion* (spring checkbox, drawn checkmark, strike-through
  sweep, particle burst, staggered entrance) vs the plain static look. The calendar
  button switches Today ↔ All tasks. Filters: All / Pending / Done.
  - "Today" = undated tasks + due today + overdue-and-pending.
  - A deadline at exactly 00:00 local means *all day* (no time shown).
  - Swipe right = complete, swipe left = Edit / Delete (with the confirm modal).
- **Task detail** lives at `/today/tasks/:id` (nested in the Today branch so the nav bar
  stays visible and the title Hero can fly). Priority pill (tap to change), notes,
  subtask CRUD (tap to toggle, swipe left to delete, inline add), deadline picker,
  and "Start focus" → stores the task in `focusTaskProvider` for Phase 5.
- Endpoints used: `GET/POST /tasks/`, `GET/PUT/DELETE /tasks/{id}`,
  `GET/POST /tasks/{id}/subtasks`, `PUT/DELETE /tasks/subtasks/{id}`.
- Requires Flutter ≥ 3.27 (`Color.withValues`, `DialogThemeData`).
- `showConfirmDialog` (core/widgets) is the shared delete modal, reused in Phase 4.

## Phase 4 notes (Projects / groups)
- `/projects` → workspace list (swipe: pin · edit · delete, shimmer progress, delete confirmation modal).
- `/projects/:id` → workspace detail (All Group Tasks / My Assigned Tasks, members, invites, subtasks).
- Progress per card is computed from `GET /groups/{id}/tasks` (one request per workspace, cached).
- Pin is local-only (no API field); persisted in SharedPreferences.
- Roles: owner/admin can invite, edit and remove members; only the owner can delete; non-owners can leave.

## Phase 5 notes (Focus · Analytics · AI)
- **Focus**: Pomodoro engine (`focus_controller.dart`) survives tab switches; haptics on minute ticks,
  halfway, last-10-seconds countdown and a celebration pattern on completion. Finishing a block opens
  `/focus/milestone` (box-breathing break, XP, stats). Work/rest lengths and auto-start come from Settings.
- **Analytics**: computed live from tasks + group tasks + local logs. Personal task completions are logged
  on-device (`activity_log.dart`); focus sessions are stored in `focus_history.dart`. Group tasks use the
  server `updated_at`.
- **AI**: Sparkle button in every tab header opens the Pulse AI sheet (`/ai/chat`, `/ai/conversation`).
  Backed by FastAPI `/ai/*` routes powered by Groq.

