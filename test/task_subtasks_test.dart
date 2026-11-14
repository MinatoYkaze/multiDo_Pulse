import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';

void main() {
  group('Subtask Models', () {
    test('SubtaskResponse parses from backend response JSON correctly', () {
      final json = {
        'id': 101,
        'title': 'Subtask Title',
        'content': 'Subtask Content',
        'completed': false,
        'due_date': '2026-11-14T10:00:00Z',
        'task_id': 42,
      };
      final sub = SubtaskResponse.fromJson(json);
      expect(sub.id, 101);
      expect(sub.taskId, 42);
      expect(sub.title, 'Subtask Title');
      expect(sub.isCompleted, false);
    });

    test('SubtaskCreate serialization produces required title', () {
      const create = SubtaskCreate(title: 'New Subtask');
      final json = create.toJson();
      expect(json['title'], 'New Subtask');
      expect(json.containsKey('title'), isTrue);
    });

    test('SubtaskUpdate serialization supports partial updates', () {
      // Partial update: only completed
      const updateCompleted = SubtaskUpdate(isCompleted: true);
      final json1 = updateCompleted.toJson();
      expect(json1['completed'], isTrue);
      expect(json1.containsKey('title'), isFalse);

      // Partial update: only title
      const updateTitle = SubtaskUpdate(title: 'Renamed');
      final json2 = updateTitle.toJson();
      expect(json2['title'], 'Renamed');
      expect(json2.containsKey('completed'), isFalse);
    });

    test('Tasks model initializes with empty subtask list by default', () {
      const task = Tasks(id: 1, title: 'Parent Task');
      expect(task.subtasks, isEmpty);
      expect(task.subtasks.length, 0);

      final withSubs = task.copyWith(subtasks: [
        const SubtaskResponse(id: 1, taskId: 1, title: 'Child 1'),
      ]);
      expect(withSubs.subtasks.length, 1);
    });
  });
}
