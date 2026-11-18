import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Offline-first cache service backed by Hive.
///
/// Stores tasks and workspaces in encrypted/keyed local storage so the UI can
/// render cached data instantly with zero loading spinners on cold start or
/// when the user has no internet connection.
class OfflineCache {
  OfflineCache(this._box);
  final Box<dynamic> _box;

  static const String boxName = 'multido_offline_cache';
  static const String _kUserKey = 'cached_user_profile_v1';
  static const String _kTasksKey = 'cached_personal_tasks_v1';
  static const String _kGroupsKey = 'cached_workspaces_v1';
  static const String _kGroupTasksPrefix = 'cached_gtasks_';

  /// Synchronously loads cached user profile for instant offline cold start.
  UserPost? getUser() {
    try {
      final raw = _box.get(_kUserKey);
      if (raw != null) {
        final Map<String, dynamic> decoded =
            raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw as Map);
        return UserPost.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveUser(UserPost user) async {
    try {
      await _box.put(_kUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> clearUser() async {
    try {
      await _box.delete(_kUserKey);
    } catch (_) {}
  }

  /// Synchronously loads cached personal tasks. Instant execution (no async delay).
  List<Tasks> getTasks() {
    try {
      final raw = _box.get(_kTasksKey);
      if (raw != null) {
        final List<dynamic> decoded = raw is String ? jsonDecode(raw) : (raw as List);
        return decoded
            .map((e) => Tasks.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Saves personal tasks to Hive.
  Future<void> saveTasks(List<Tasks> tasks) async {
    try {
      final jsonList = tasks.map((t) => t.toJson()).toList();
      await _box.put(_kTasksKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Synchronously loads cached workspaces/groups. Instant execution.
  List<Group> getGroups() {
    try {
      final raw = _box.get(_kGroupsKey);
      if (raw != null) {
        final List<dynamic> decoded = raw is String ? jsonDecode(raw) : (raw as List);
        return decoded
            .map((e) => Group.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Saves workspaces/groups to Hive.
  Future<void> saveGroups(List<Group> groups) async {
    try {
      final jsonList = groups.map((g) => g.toJson()).toList();
      await _box.put(_kGroupsKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Synchronously loads cached tasks for a specific group workspace.
  List<GroupTaskResponse> getGroupTasks(int groupId) {
    try {
      final raw = _box.get('$_kGroupTasksPrefix$groupId');
      if (raw != null) {
        final List<dynamic> decoded = raw is String ? jsonDecode(raw) : (raw as List);
        return decoded
            .map((e) => GroupTaskResponse.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Saves tasks for a specific group workspace.
  Future<void> saveGroupTasks(int groupId, List<GroupTaskResponse> tasks) async {
    try {
      final jsonList = tasks.map((t) => t.toJson()).toList();
      await _box.put('$_kGroupTasksPrefix$groupId', jsonEncode(jsonList));
    } catch (_) {}
  }

  // ── pending offline mutation queue ────────────────────────────

  static const String _kPendingActionsKey = 'cached_pending_actions_v1';

  List<Map<String, dynamic>> getPendingActions() {
    try {
      final raw = _box.get(_kPendingActionsKey);
      if (raw != null) {
        final List<dynamic> decoded = raw is String ? jsonDecode(raw) : (raw as List);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> savePendingActions(List<Map<String, dynamic>> actions) async {
    try {
      await _box.put(_kPendingActionsKey, jsonEncode(actions));
    } catch (_) {}
  }

  Future<void> addPendingAction(Map<String, dynamic> action) async {
    final list = [...getPendingActions(), action];
    await savePendingActions(list);
  }

  Future<void> removePendingAction(String actionId) async {
    final list = getPendingActions().where((a) => a['action_id'] != actionId).toList();
    await savePendingActions(list);
  }

  /// Clears cache on logout.
  Future<void> clearAll() async {
    try {
      await _box.clear();
    } catch (_) {}
  }
}

final offlineCacheProvider = Provider<OfflineCache>((ref) {
  throw UnimplementedError('offlineCacheProvider must be overridden in ProviderScope');
});
