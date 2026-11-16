import '../../../core/models/models.dart';

/// Centralized permission matrix for group and project operations.
/// Strictly aligned with TaskAPI backend authorization (`app/routes/groups.py`).
class GroupPermissionPolicy {
  final int? currentUserId;
  final Group? group;
  final Role userRole;

  const GroupPermissionPolicy({
    required this.currentUserId,
    required this.group,
    this.userRole = Role.member,
  });

  /// Check whether the current user is an owner of the group.
  bool get isOwner =>
      (group?.ownerId != null &&
          currentUserId != null &&
          group!.ownerId == currentUserId) ||
      userRole == Role.owner;

  /// Check whether the current user is an admin in the group.
  bool get isAdmin => userRole == Role.admin;

  /// Check whether the user can manage the group (owner).
  bool get canManageGroup => isOwner;

  /// Whether user can invite members to this group.
  /// Backend: `group.owners_id == current_user["id"]`
  bool get canInviteMembers => isOwner;

  /// Whether user can remove a member from this group.
  /// Backend: `current_member.role == Role.owner` and target member is not owner.
  bool canRemoveMember(GroupMemberResponse member) {
    if (!isOwner) return false;
    if (member.role == Role.owner) return false;
    if (member.userId == currentUserId) return false;
    return true;
  }

  /// Whether user can delete the group.
  /// Backend: `group.owners_id == current_user["id"]`
  bool get canDeleteGroup => isOwner;

  /// Whether user can edit group metadata.
  /// Backend: `group.owners_id == current_user["id"]`
  bool get canEditGroup => isOwner;

  /// Whether user can create tasks in this group.
  /// Backend: `group.owners_id == current_user["id"]` (403 if not owner)
  bool get canCreateTask => isOwner;

  /// Whether user can delete a task.
  /// Backend: `group.owners_id == current_user["id"]`
  bool get canDeleteTask => isOwner;

  /// Whether user can reassign a task.
  /// Backend: `Only the group owner can reassign tasks`
  bool get canAssignTask => isOwner;

  /// Whether user can edit a task (title, description, due date, priority).
  /// Backend: `is_owner || is_assigned`.
  bool canEditTask(GroupTaskResponse task) {
    if (isOwner) return true;
    return currentUserId != null && task.assignedTo == currentUserId;
  }

  /// Whether user can update task completion status.
  /// Backend: `is_owner || is_assigned`.
  bool canToggleTaskStatus(GroupTaskResponse task) {
    if (isOwner) return true;
    return currentUserId != null && task.assignedTo == currentUserId;
  }

  /// Whether user can create subtasks on a task.
  /// Backend: `is_owner || is_assigned`.
  bool canCreateSubtask(GroupTaskResponse task) {
    if (isOwner) return true;
    return currentUserId != null && task.assignedTo == currentUserId;
  }

  /// Whether user can delete subtasks.
  /// Backend: owner only.
  bool get canDeleteSubtask => isOwner;
}
