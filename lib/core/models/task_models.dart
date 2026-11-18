import 'enums.dart';
import 'json_helpers.dart';

/// Response model for personal tasks (`Tasks`).
class Tasks {
  final int id;
  final String title;
  final String? description;
  final Priority priority;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final List<SubtaskResponse> subtasks;

  const Tasks({
    required this.id,
    required this.title,
    this.description,
    this.priority = Priority.medium,
    this.isCompleted = false,
    this.dueDate,
    this.createdAt,
    this.subtasks = const [],
  });

  factory Tasks.fromJson(Map<String, dynamic> j) => Tasks(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? j['content']) as String?,
        priority: Priority.fromJson(j['priority']),
        isCompleted: (j['is_completed'] == true || j['completed'] == true),
        dueDate: parseDate(j['due_date']),
        createdAt: parseDate(j['created_at']),
        subtasks: (j['subtasks'] as List? ?? const [])
            .map((e) => SubtaskResponse.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'content': description ?? '',
        'priority': priority.toJson(),
        'is_completed': isCompleted,
        'completed': isCompleted,
        'due_date': dateToJson(dueDate),
        'created_at': dateToJson(createdAt),
        'subtasks': subtasks.map((e) => e.toJson()).toList(),
      };

  Tasks copyWith({
    String? title,
    String? description,
    Priority? priority,
    bool? isCompleted,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<SubtaskResponse>? subtasks,
  }) =>
      Tasks(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        createdAt: createdAt,
        subtasks: subtasks ?? this.subtasks,
      );
}

/// Body for POST /tasks/ and PUT /tasks/{id}.
class TasksPost {
  final String title;
  final String? description;
  final Priority priority;
  final DateTime? dueDate;
  final bool? isCompleted;

  /// When true and [dueDate] is null, `due_date: null` is sent explicitly so
  /// the server clears the deadline (plain null fields are omitted).
  final bool clearDueDate;

  const TasksPost({
    required this.title,
    this.description,
    this.priority = Priority.medium,
    this.dueDate,
    this.isCompleted,
    this.clearDueDate = false,
  });

  factory TasksPost.fromTask(Tasks t) => TasksPost(
        title: t.title,
        description: t.description,
        priority: t.priority,
        dueDate: t.dueDate,
        isCompleted: t.isCompleted,
        clearDueDate: t.dueDate == null,
      );

  factory TasksPost.fromJson(Map<String, dynamic> j) => TasksPost(
        title: j['title'] as String,
        description: (j['description'] ?? j['content']) as String?,
        priority: Priority.fromJson(j['priority']),
        dueDate: parseDate(j['due_date']),
        isCompleted: j['is_completed'] != null
            ? (j['is_completed'] == true)
            : (j['completed'] != null ? j['completed'] == true : null),
      );

  Map<String, dynamic> toJson() {
    final m = compact({
      'title': title,
      'content': description ?? '',
      'description': description,
      'priority': priority.toJson(),
      'due_date': dateToJson(dueDate),
      'completed': isCompleted,
      'is_completed': isCompleted,
    });
    if (dueDate == null && clearDueDate) m['due_date'] = null;
    return m;
  }
}

class SubtaskCreate {
  final String title;
  const SubtaskCreate({required this.title});
  factory SubtaskCreate.fromJson(Map<String, dynamic> j) =>
      SubtaskCreate(title: j['title'] as String);
  Map<String, dynamic> toJson() => {'title': title, 'content': ''};
}

class SubtaskResponse {
  final int id;
  final int taskId;
  final String title;
  final bool isCompleted;

  const SubtaskResponse({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  factory SubtaskResponse.fromJson(Map<String, dynamic> j) => SubtaskResponse(
        id: j['id'] as int,
        taskId: (j['task_id'] ?? 0) as int,
        title: (j['title'] ?? '') as String,
        isCompleted: (j['is_completed'] == true || j['completed'] == true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_id': taskId,
        'title': title,
        'is_completed': isCompleted,
        'completed': isCompleted,
      };

  SubtaskResponse copyWith({String? title, bool? isCompleted}) =>
      SubtaskResponse(
        id: id,
        taskId: taskId,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

/// Body for PUT /tasks/subtasks/{subtask_id}.
class SubtaskUpdate {
  final String? title;
  final bool? isCompleted;
  const SubtaskUpdate({this.title, this.isCompleted});
  Map<String, dynamic> toJson() => compact({
        'title': title,
        'completed': isCompleted,
        'is_completed': isCompleted,
      });
}
