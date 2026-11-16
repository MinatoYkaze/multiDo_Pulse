import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';

void main() {
  group('Group Model', () {
    test('Group.fromJson parses correctly and computes progress', () {
      final json = {
        'id': 10,
        'name': 'Alpha Project',
        'description': 'Main roadmap',
        'owner_id': 42,
        'created_at': '2026-11-14T10:00:00Z',
        'member_count': 3,
        'task_count': 4,
        'completed_task_count': 2,
      };

      final g = Group.fromJson(json);
      expect(g.id, 10);
      expect(g.name, 'Alpha Project');
      expect(g.description, 'Main roadmap');
      expect(g.ownerId, 42);
      expect(g.memberCount, 3);
      expect(g.taskCount, 4);
      expect(g.completedTaskCount, 2);
      expect(g.progress, 0.5);
    });

    test('Group.fromJson parses owners_id from backend schema', () {
      final json = {
        'id': 5,
        'name': 'Coderepo',
        'description': 'Main repo',
        'owners_id': 6,
      };
      final g = Group.fromJson(json);
      expect(g.id, 5);
      expect(g.ownerId, 6);
    });

    test('Group.progress handles 0 tasks gracefully', () {
      const g = Group(id: 1, name: 'Empty', taskCount: 0, completedTaskCount: 0);
      expect(g.progress, 0.0);
    });
  });

  group('Group Member Model', () {
    test('GroupMemberResponse parses user object with username and email', () {
      final json = {
        'user_id': 5,
        'group_id': 10,
        'role': 'owner',
        'user': {
          'id': 5,
          'username': 'anirudh',
          'email': 'anirudh@example.com',
        },
        'created_at': '2026-11-14T12:00:00Z',
      };

      final m = GroupMemberResponse.fromJson(json);
      expect(m.userId, 5);
      expect(m.role, Role.owner);
      expect(m.name, 'anirudh');
      expect(m.displayName, 'anirudh');
      expect(m.email, 'anirudh@example.com');
      expect(m.initials, 'AN');
    });

    test('GroupMemberResponse falls back to email or user id if name is missing', () {
      final json = {
        'user_id': 8,
        'role': 'member',
        'user': {
          'id': 8,
          'email': 'test@domain.com',
        },
      };

      final m = GroupMemberResponse.fromJson(json);
      expect(m.displayName, 'test@domain.com');
    });
  });

  group('Group Invitation Base', () {
    test('GroupInvitationBase only serializes email matching FastAPI schema', () {
      const inv = GroupInvitationBase(email: 'collab@team.io');
      final j = inv.toJson();
      expect(j.length, 1);
      expect(j['email'], 'collab@team.io');
      expect(j.containsKey('role'), false);
    });
  });

  group('Group Tasks and Subtasks', () {
    test('GroupTasksCreate serializes assigned_to and priority correctly', () {
      final create = GroupTasksCreate(
        title: 'Design API Gateway',
        description: 'Set up rate limiting',
        priority: Priority.urgent,
        dueDate: DateTime.utc(2026, 12, 1),
        assignedTo: 7,
      );

      final j = create.toJson();
      expect(j['title'], 'Design API Gateway');
      expect(j['description'], 'Set up rate limiting');
      expect(j['priority'], 'urgent');
      expect(j['assigned_to'], 7);
      expect(j.containsKey('due_date'), true);
    });

    test('GroupTaskUpdate sends completed instead of is_completed for backend compatibility', () {
      const update = GroupTaskUpdate(
        title: 'Updated title',
        isCompleted: true,
      );

      final j = update.toJson();
      expect(j['title'], 'Updated title');
      expect(j['completed'], true);
      expect(j.containsKey('is_completed'), false);
    });

    test('GroupSubtaskResponse parses group_task_id and completed', () {
      final json = {
        'id': 101,
        'group_task_id': 45,
        'title': 'Add tests',
        'completed': true,
      };

      final st = GroupSubtaskResponse.fromJson(json);
      expect(st.id, 101);
      expect(st.taskId, 45);
      expect(st.title, 'Add tests');
      expect(st.isCompleted, true);
    });

    test('GroupSubtaskUpdate sends completed to backend', () {
      const update = GroupSubtaskUpdate(title: 'Done', isCompleted: true);
      final j = update.toJson();
      expect(j['title'], 'Done');
      expect(j['completed'], true);
      expect(j.containsKey('is_completed'), false);
    });
  });
}
