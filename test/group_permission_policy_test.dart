import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/features/groups/domain/group_permission_policy.dart';

void main() {
  const testGroup = Group(
    id: 10,
    name: 'Apollo Project',
    ownerId: 1,
    memberCount: 3,
  );

  const ownerMember = GroupMemberResponse(
    userId: 1,
    role: Role.owner,
    name: 'Alice Owner',
    email: 'alice@example.com',
  );

  const adminMember = GroupMemberResponse(
    userId: 2,
    role: Role.admin,
    name: 'Bob Admin',
    email: 'bob@example.com',
  );

  const regularMember = GroupMemberResponse(
    userId: 3,
    role: Role.member,
    name: 'Charlie Member',
    email: 'charlie@example.com',
  );

  const assignedTask = GroupTaskResponse(
    id: 101,
    title: 'Assigned to Charlie',
    groupId: 10,
    assignedTo: 3,
    priority: Priority.high,
  );

  const otherTask = GroupTaskResponse(
    id: 102,
    title: 'Assigned to Bob',
    groupId: 10,
    assignedTo: 2,
    priority: Priority.medium,
  );

  group('GroupPermissionPolicy - Owner Permissions', () {
    const ownerPolicy = GroupPermissionPolicy(
      currentUserId: 1,
      group: testGroup,
      userRole: Role.owner,
    );

    test('Owner has full management capabilities', () {
      expect(ownerPolicy.isOwner, true);
      expect(ownerPolicy.canInviteMembers, true);
      expect(ownerPolicy.canDeleteGroup, true);
      expect(ownerPolicy.canEditGroup, true);
      expect(ownerPolicy.canCreateTask, true);
      expect(ownerPolicy.canDeleteTask, true);
      expect(ownerPolicy.canAssignTask, true);
      expect(ownerPolicy.canDeleteSubtask, true);
    });

    test('Owner can edit and toggle any task', () {
      expect(ownerPolicy.canEditTask(assignedTask), true);
      expect(ownerPolicy.canEditTask(otherTask), true);
      expect(ownerPolicy.canToggleTaskStatus(assignedTask), true);
      expect(ownerPolicy.canToggleTaskStatus(otherTask), true);
      expect(ownerPolicy.canCreateSubtask(assignedTask), true);
    });

    test('Owner can remove admin or regular members, but not self or another owner', () {
      expect(ownerPolicy.canRemoveMember(adminMember), true);
      expect(ownerPolicy.canRemoveMember(regularMember), true);
      expect(ownerPolicy.canRemoveMember(ownerMember), false); // Cannot remove self
    });
  });

  group('GroupPermissionPolicy - Member & Assignee Permissions', () {
    const memberPolicy = GroupPermissionPolicy(
      currentUserId: 3,
      group: testGroup,
      userRole: Role.member,
    );

    test('Regular member has restricted permissions strictly matching backend', () {
      expect(memberPolicy.isOwner, false);
      expect(memberPolicy.canInviteMembers, false);
      expect(memberPolicy.canDeleteGroup, false);
      expect(memberPolicy.canCreateTask, false);
      expect(memberPolicy.canDeleteTask, false);
      expect(memberPolicy.canAssignTask, false);
      expect(memberPolicy.canDeleteSubtask, false);
    });

    test('Assignee can edit and toggle own task, but not others', () {
      expect(memberPolicy.canEditTask(assignedTask), true);
      expect(memberPolicy.canToggleTaskStatus(assignedTask), true);
      expect(memberPolicy.canCreateSubtask(assignedTask), true);

      expect(memberPolicy.canEditTask(otherTask), false);
      expect(memberPolicy.canToggleTaskStatus(otherTask), false);
      expect(memberPolicy.canCreateSubtask(otherTask), false);
    });

    test('Member cannot remove any member', () {
      expect(memberPolicy.canRemoveMember(adminMember), false);
      expect(memberPolicy.canRemoveMember(regularMember), false);
      expect(memberPolicy.canRemoveMember(ownerMember), false);
    });
  });

  group('GroupMemberResponse - Flat Backend Serialization', () {
    test('Parses flat FastAPI schema response correctly', () {
      final json = {
        'id': 7,
        'username': 'dave_dev',
        'email': 'dave@team.com',
        'role': 'admin',
        'joined_at': '2026-11-14T15:30:00Z',
      };

      final member = GroupMemberResponse.fromJson(json);
      expect(member.userId, 7);
      expect(member.name, 'dave_dev');
      expect(member.displayName, 'dave_dev');
      expect(member.email, 'dave@team.com');
      expect(member.role, Role.admin);
      expect(member.joinedAt, isNotNull);
    });

    test('Handles String id values gracefully', () {
      final json = {
        'id': '42',
        'username': 'string_user',
        'email': 'string@team.com',
        'role': 'member',
      };

      final member = GroupMemberResponse.fromJson(json);
      expect(member.userId, 42);
      expect(member.displayName, 'string_user');
      expect(member.role, Role.member);
    });
  });
}
