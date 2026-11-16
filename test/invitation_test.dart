import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/network/api_client.dart';
import 'package:obsidian_todo/features/groups/data/invitation_repository.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  ResponseBody? responseToReturn;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return responseToReturn ??
        ResponseBody.fromString(
          '{"message": "Invitation accepted successfully."}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Group Invitation Tests', () {
    test('GroupInvitationBase serializes lowercase trimmed email', () {
      const invite = GroupInvitationBase(email: 'user@example.com');
      final json = invite.toJson();
      expect(json['email'], 'user@example.com');
    });

    test('GroupInvitationResponse parses backend response schema', () {
      final json = {
        'id': 15,
        'group_id': 5,
        'email': 'divyeshchiluveru2@gmail.com',
        'invited_by': 6,
        'token': 'secret-token-321',
        'status': 'pending',
        'expires_at': '2026-11-23T12:00:00Z',
        'created_at': '2026-11-16T12:00:00Z',
      };
      final res = GroupInvitationResponse.fromJson(json);
      expect(res.id, 15);
      expect(res.email, 'divyeshchiluveru2@gmail.com');
      expect(res.token, 'secret-token-321');
      expect(res.status, InvitationStatus.pending);
      expect(res.role, Role.member);
    });

    test('InvitationRepository.accept sends HTTP POST to accept endpoint', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://taskflow-api-v1-225t.onrender.com'));
      dio.httpClientAdapter = adapter;

      final apiClient = ApiClient(dio);
      final repo = InvitationRepository(apiClient);

      final res = await repo.accept('test-token-xyz');
      expect(res.message, 'Invitation accepted successfully.');
      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/groups/invitations/test-token-xyz/accept');
    });

    test('InvitationPreview parses from JSON schema', () {
      final json = {
        'group_id': 10,
        'group_name': 'Alpha Team',
        'group_description': 'Building next-gen Flutter experience',
        'inviter_email': 'owner@example.com',
        'inviter_name': 'Project Owner',
        'expires_at': '2026-11-23T12:00:00Z',
      };
      final preview = InvitationPreview.fromJson(json);
      expect(preview.groupId, 10);
      expect(preview.groupName, 'Alpha Team');
      expect(preview.groupDescription, 'Building next-gen Flutter experience');
      expect(preview.inviterEmail, 'owner@example.com');
    });

    test('InvitationRepository.getPreview sends HTTP GET to preview endpoint', () async {
      final adapter = _CapturingAdapter();
      adapter.responseToReturn = ResponseBody.fromString(
        '{"group_id": 10, "group_name": "Alpha Team", "group_description": "Test Desc", "inviter_email": "owner@example.com"}',
        200,
        headers: {'content-type': ['application/json']},
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://taskflow-api-v1-225t.onrender.com'));
      dio.httpClientAdapter = adapter;

      final apiClient = ApiClient(dio);
      final repo = InvitationRepository(apiClient);

      final preview = await repo.getPreview('preview-token-123');
      expect(preview, isNotNull);
      expect(preview!.groupName, 'Alpha Team');
      expect(adapter.lastRequest?.method, 'GET');
      expect(adapter.lastRequest?.path, '/groups/invitations/preview-token-123/preview');
    });
  });
}
