import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';

void main() {
  group('AI Models', () {
    test('AIChatRequest serializes threadId, message, and decision', () {
      const req = AIChatRequest(
        threadId: 'th_12345',
        message: 'Create task Deploy to Staging',
      );
      final j = req.toJson();
      expect(j['thread_id'], 'th_12345');
      expect(j['message'], 'Create task Deploy to Staging');
      expect(j.containsKey('decision'), false);

      const decisionReq = AIChatRequest(
        threadId: 'th_12345',
        decision: 'accept',
      );
      final j2 = decisionReq.toJson();
      expect(j2['thread_id'], 'th_12345');
      expect(j2['decision'], 'accept');
      expect(j2.containsKey('message'), false);
    });

    test('AIApproval parses action and parameters properly', () {
      final json = {
        'action': 'create_group_task',
        'details': {
          'title': 'Setup DB migration',
          'group_id': 10,
          'priority': 'high',
        },
        'message': 'Do you want me to create this task?',
      };

      final approval = AIApproval.fromJson(json);
      expect(approval.action, 'create_group_task');
      expect(approval.details['title'], 'Setup DB migration');
      expect(approval.details['group_id'], 10);
      expect(approval.message, 'Do you want me to create this task?');
    });

    test('AIChatResponse parses pending approval response', () {
      final json = {
        'status': 'pending_approval',
        'thread_id': 'th_abc',
        'approval': {
          'action': 'delete_group_task',
          'details': {'task_id': 99},
        },
      };

      final res = AIChatResponse.fromJson(json);
      expect(res.isPendingApproval, true);
      expect(res.status, 'pending_approval');
      expect(res.threadId, 'th_abc');
      expect(res.approval?.action, 'delete_group_task');
      expect(res.approval?.details['task_id'], 99);
    });

    test('AIChatResponse parses completed response', () {
      final json = {
        'status': 'completed',
        'thread_id': 'th_xyz',
        'message': 'I have created the task for you.',
      };

      final res = AIChatResponse.fromJson(json);
      expect(res.isPendingApproval, false);
      expect(res.status, 'completed');
      expect(res.message, 'I have created the task for you.');
    });
  });
}
