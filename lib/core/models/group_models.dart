import 'enums.dart';
import 'json_helpers.dart';

class Group {
  final int id;
  final String name;
  final String? description;
  final int? ownerId;
  final DateTime? createdAt;
  final int memberCount;
  final int taskCount;
  final int completedTaskCount;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.ownerId,
    this.createdAt,
    this.memberCount = 0,
    this.taskCount = 0,
    this.completedTaskCount = 0,
  });

  double get progress =>
      taskCount == 0 ? 0 : (completedTaskCount / taskCount).clamp(0, 1);

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        ownerId: (j['owner_id'] ?? j['owners_id'] ?? j['created_by']) as int?,
        createdAt: parseDate(j['created_at']),
        memberCount: (j['member_count'] ?? 0) as int,
        taskCount: (j['task_count'] ?? 0) as int,
        completedTaskCount: (j['completed_task_count'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'owner_id': ownerId,
        'created_at': dateToJson(createdAt),
        'member_count': memberCount,
        'task_count': taskCount,
        'completed_task_count': completedTaskCount,
      };
}

class GroupPost {
  final String name;
  final String? description;
  const GroupPost({required this.name, this.description});
  factory GroupPost.fromJson(Map<String, dynamic> j) => GroupPost(
      name: j['name'] as String, description: j['description'] as String?);
  Map<String, dynamic> toJson() =>
      compact({'name': name, 'description': description ?? ''});
}

class UpdateGroup {
  final String? name;
  final String? description;
  const UpdateGroup({this.name, this.description});
  factory UpdateGroup.fromJson(Map<String, dynamic> j) => UpdateGroup(
      name: j['name'] as String?, description: j['description'] as String?);
  Map<String, dynamic> toJson() =>
      compact({'name': name, 'description': description});
}

class GroupMemberResponse {
  final int userId;
  final int? groupId;
  final Role role;
  final String? name;
  final String? email;
  final String? picture;
  final DateTime? joinedAt;

  const GroupMemberResponse({
    required this.userId,
    this.groupId,
    this.role = Role.member,
    this.name,
    this.email,
    this.picture,
    this.joinedAt,
  });

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : (email ?? 'User $userId');

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final s = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'
        : displayName.substring(0, displayName.length.clamp(1, 2));
    return s.toUpperCase();
  }

  factory GroupMemberResponse.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? Map<String, dynamic>.from(j['user']) : j;
    final rawId = j['user_id'] ?? user['id'] ?? j['id'];
    final userId = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0);
    return GroupMemberResponse(
      userId: userId,
      groupId: j['group_id'] as int?,
      role: Role.fromJson(j['role']),
      name: (user['username'] ?? user['name'] ?? user['full_name'] ?? j['username'] ?? j['name']) as String?,
      email: (user['email'] ?? j['email']) as String?,
      picture: (user['picture'] ?? user['avatar_url'] ?? j['picture']) as String?,
      joinedAt: parseDate(j['joined_at'] ?? j['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'group_id': groupId,
        'role': role.toJson(),
        'name': name,
        'email': email,
        'picture': picture,
        'joined_at': dateToJson(joinedAt),
      };
}

/// Body for POST /groups/{group_id}/invite.
class GroupInvitationBase {
  final String email;
  final Role? role;
  const GroupInvitationBase({required this.email, this.role});
  factory GroupInvitationBase.fromJson(Map<String, dynamic> j) =>
      GroupInvitationBase(
        email: j['email'] as String,
        role: j['role'] == null ? null : Role.fromJson(j['role']),
      );
  Map<String, dynamic> toJson() => {'email': email};
}

/// Body for PATCH /groups/invitations/{invitation_id}/respond.
class GroupInvitationRespond {
  final InvitationStatus status;
  const GroupInvitationRespond({required this.status});
  factory GroupInvitationRespond.fromJson(Map<String, dynamic> j) =>
      GroupInvitationRespond(status: InvitationStatus.fromJson(j['status']));
  Map<String, dynamic> toJson() => {'status': status.toJson()};
}

/// Response schema for in-app group invitations:
/// POST /groups/{group_id}/invite, GET /groups/invitations,
/// and PATCH /groups/invitations/{invitation_id}/respond.
class InGroupInvitationResponse {
  final int id;
  final int groupId;
  final int invitedUserId;
  final int invitedBy;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;
  final String? groupName;
  final String? inviterName;
  final String? inviterEmail;

  const InGroupInvitationResponse({
    required this.id,
    required this.groupId,
    required this.invitedUserId,
    required this.invitedBy,
    this.status = InvitationStatus.pending,
    required this.createdAt,
    this.respondedAt,
    required this.expiresAt,
    this.groupName,
    this.inviterName,
    this.inviterEmail,
  });

  String? get token => null;
  bool get isResend => false;
  String get email => inviterEmail ?? '';
  Role get role => Role.member;

  bool get isExpired =>
      status == InvitationStatus.expired ||
      (status == InvitationStatus.pending &&
          DateTime.now().toUtc().isAfter(expiresAt.toUtc()));

  factory InGroupInvitationResponse.fromJson(Map<String, dynamic> j) =>
      InGroupInvitationResponse(
        id: j['id'] as int,
        groupId: j['group_id'] as int,
        invitedUserId: j['invited_user_id'] as int,
        invitedBy: j['invited_by'] as int,
        status: InvitationStatus.fromJson(j['status']),
        createdAt: parseDate(j['created_at']) ?? DateTime.now().toUtc(),
        respondedAt: parseDate(j['responded_at']),
        expiresAt: parseDate(j['expires_at']) ?? DateTime.now().toUtc(),
        groupName: j['group_name'] as String?,
        inviterName: j['inviter_name'] as String?,
        inviterEmail: j['inviter_email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'invited_user_id': invitedUserId,
        'invited_by': invitedBy,
        'status': status.toJson(),
        'created_at': dateToJson(createdAt),
        'responded_at': dateToJson(respondedAt),
        'expires_at': dateToJson(expiresAt),
        if (groupName != null) 'group_name': groupName,
        if (inviterName != null) 'inviter_name': inviterName,
        if (inviterEmail != null) 'inviter_email': inviterEmail,
      };
}

typedef GroupInvitationResponse = InGroupInvitationResponse;

class GroupTaskResponse {
  final int id;
  final int groupId;
  final String title;
  final String? description;
  final Priority priority;
  final bool isCompleted;
  final DateTime? dueDate;
  final int? assignedTo;
  final String? assigneeName;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<GroupSubtaskResponse> subtasks;

  const GroupTaskResponse({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    this.priority = Priority.medium,
    this.isCompleted = false,
    this.dueDate,
    this.assignedTo,
    this.assigneeName,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.subtasks = const [],
  });

  factory GroupTaskResponse.fromJson(Map<String, dynamic> j) =>
      GroupTaskResponse(
        id: j['id'] as int,
        groupId: (j['group_id'] ?? 0) as int,
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        priority: Priority.fromJson(j['priority']),
        isCompleted: (j['is_completed'] == true || j['completed'] == true),
        dueDate: parseDate(j['due_date']),
        assignedTo: (j['assigned_to'] ?? j['assignee_id']) as int?,
        assigneeName: j['assignee_name'] as String?,
        createdBy: j['created_by'] as int?,
        createdAt: parseDate(j['created_at']),
        updatedAt: parseDate(j['updated_at']),
        subtasks: (j['subtasks'] as List? ?? const [])
            .map((e) =>
                GroupSubtaskResponse.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'title': title,
        'description': description,
        'priority': priority.toJson(),
        'is_completed': isCompleted,
        'due_date': dateToJson(dueDate),
        'assigned_to': assignedTo,
        'assignee_name': assigneeName,
        'created_by': createdBy,
        'created_at': dateToJson(createdAt),
        'updated_at': dateToJson(updatedAt),
        'subtasks': subtasks.map((e) => e.toJson()).toList(),
      };

  GroupTaskResponse copyWith(
          {bool? isCompleted, List<GroupSubtaskResponse>? subtasks}) =>
      GroupTaskResponse(
        id: id,
        groupId: groupId,
        title: title,
        description: description,
        priority: priority,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate,
        assignedTo: assignedTo,
        assigneeName: assigneeName,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        subtasks: subtasks ?? this.subtasks,
      );
}

/// Body for POST /groups/{group_id}/tasks.
class GroupTasksCreate {
  final String title;
  final String? description;
  final Priority priority;
  final DateTime? dueDate;
  final int? assignedTo;

  const GroupTasksCreate({
    required this.title,
    this.description,
    this.priority = Priority.medium,
    this.dueDate,
    this.assignedTo,
  });

  factory GroupTasksCreate.fromJson(Map<String, dynamic> j) => GroupTasksCreate(
        title: j['title'] as String,
        description: j['description'] as String?,
        priority: Priority.fromJson(j['priority']),
        dueDate: parseDate(j['due_date']),
        assignedTo: j['assigned_to'] as int?,
      );

  Map<String, dynamic> toJson() => compact({
        'title': title,
        'description': description,
        'priority': priority.toJson(),
        'due_date': dateToJson(dueDate),
        'assigned_to': assignedTo,
      });
}

/// Body for PATCH /groups/{group_id}/tasks/{task_id}.
class GroupTaskUpdate {
  final String? title;
  final String? description;
  final Priority? priority;
  final DateTime? dueDate;
  final bool? isCompleted;
  final int? assignedTo;

  const GroupTaskUpdate({
    this.title,
    this.description,
    this.priority,
    this.dueDate,
    this.isCompleted,
    this.assignedTo,
  });

  factory GroupTaskUpdate.fromJson(Map<String, dynamic> j) => GroupTaskUpdate(
        title: j['title'] as String?,
        description: j['description'] as String?,
        priority:
            j['priority'] == null ? null : Priority.fromJson(j['priority']),
        dueDate: parseDate(j['due_date']),
        isCompleted: (j['completed'] ?? j['is_completed']) as bool?,
        assignedTo: (j['assigned_to'] ?? j['assignee_id']) as int?,
      );

  Map<String, dynamic> toJson() => compact({
        'title': title,
        'description': description,
        'priority': priority?.toJson(),
        'due_date': dateToJson(dueDate),
        'completed': isCompleted,
        'assigned_to': assignedTo,
      });
}

class GroupSubtaskCreate {
  final String title;
  const GroupSubtaskCreate({required this.title});
  factory GroupSubtaskCreate.fromJson(Map<String, dynamic> j) =>
      GroupSubtaskCreate(title: j['title'] as String);
  Map<String, dynamic> toJson() => {'title': title};
}

class GroupSubtaskResponse {
  final int id;
  final int taskId;
  final String title;
  final bool isCompleted;

  const GroupSubtaskResponse({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  factory GroupSubtaskResponse.fromJson(Map<String, dynamic> j) =>
      GroupSubtaskResponse(
        id: j['id'] as int,
        taskId: (j['task_id'] ?? j['group_task_id'] ?? 0) as int,
        title: (j['title'] ?? '') as String,
        isCompleted: (j['is_completed'] == true || j['completed'] == true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_id': taskId,
        'group_task_id': taskId,
        'title': title,
        'completed': isCompleted,
        'is_completed': isCompleted,
      };

  GroupSubtaskResponse copyWith({String? title, bool? isCompleted}) =>
      GroupSubtaskResponse(
        id: id,
        taskId: taskId,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

class GroupSubtaskUpdate {
  final String? title;
  final bool? isCompleted;
  const GroupSubtaskUpdate({this.title, this.isCompleted});
  factory GroupSubtaskUpdate.fromJson(Map<String, dynamic> j) =>
      GroupSubtaskUpdate(
          title: j['title'] as String?,
          isCompleted: (j['completed'] ?? j['is_completed']) as bool?);
  Map<String, dynamic> toJson() =>
      compact({'title': title, 'completed': isCompleted});
}
