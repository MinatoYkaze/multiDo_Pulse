import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/network/api_client.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';
import 'package:obsidian_todo/features/groups/data/group_repository.dart';
import 'package:obsidian_todo/features/groups/data/invitation_repository.dart';
import 'package:obsidian_todo/features/groups/presentation/groups_controller.dart';
import 'package:obsidian_todo/features/groups/presentation/invitations_inbox_screen.dart';

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
          '''{
            "id": 15,
            "group_id": 5,
            "invited_user_id": 9,
            "invited_by": 6,
            "status": "accepted",
            "created_at": "2026-11-16T12:00:00Z",
            "responded_at": "2026-11-17T12:00:00Z",
            "expires_at": "2026-11-23T12:00:00Z"
          }''',
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
  group('In-App Group Invitation Models & Repositories', () {
    test('GroupInvitationBase serializes email', () {
      const invite = GroupInvitationBase(email: 'user@example.com');
      expect(invite.toJson(), {'email': 'user@example.com'});
    });

    test('GroupInvitationRespond serializes accepted and rejected', () {
      expect(
        const GroupInvitationRespond(status: InvitationStatus.accepted)
            .toJson(),
        {'status': 'accepted'},
      );
      expect(
        const GroupInvitationRespond(status: InvitationStatus.rejected)
            .toJson(),
        {'status': 'rejected'},
      );
    });

    test('InGroupInvitationResponse parses OpenAPI schema', () {
      final json = {
        'id': 15,
        'group_id': 5,
        'invited_user_id': 9,
        'invited_by': 6,
        'status': 'pending',
        'created_at': '2026-11-16T12:00:00Z',
        'responded_at': null,
        'expires_at': '2099-11-23T12:00:00Z',
      };
      final res = InGroupInvitationResponse.fromJson(json);
      expect(res.id, 15);
      expect(res.groupId, 5);
      expect(res.invitedUserId, 9);
      expect(res.invitedBy, 6);
      expect(res.status, InvitationStatus.pending);
      expect(res.respondedAt, isNull);
      expect(res.isExpired, isFalse);
    });

    test('InGroupInvitationResponse detects past expiresAt as expired', () {
      final res = InGroupInvitationResponse(
        id: 1,
        groupId: 2,
        invitedUserId: 3,
        invitedBy: 4,
        status: InvitationStatus.pending,
        createdAt: DateTime.utc(2020, 1, 1),
        expiresAt: DateTime.utc(2020, 1, 8),
      );
      expect(res.isExpired, isTrue);
    });

    test('GroupRepository.invite sends POST /groups/{group_id}/invite',
        () async {
      final adapter = _CapturingAdapter();
      adapter.responseToReturn = ResponseBody.fromString(
        '''{
          "id": 21,
          "group_id": 5,
          "invited_user_id": 11,
          "invited_by": 6,
          "status": "pending",
          "created_at": "2026-11-16T12:00:00Z",
          "responded_at": null,
          "expires_at": "2099-11-23T12:00:00Z"
        }''',
        201,
        headers: {
          'content-type': ['application/json'],
        },
      );
      final dio = Dio(
          BaseOptions(baseUrl: 'https://taskflow-api-v1-225t.onrender.com'));
      dio.httpClientAdapter = adapter;

      final repo = GroupRepository(ApiClient(dio));
      final res = await repo.invite(5, 'collab@example.com');

      expect(res.id, 21);
      expect(res.status, InvitationStatus.pending);
      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/groups/5/invite');
      expect(adapter.lastRequest?.data, {'email': 'collab@example.com'});
    });

    test('InvitationRepository.getInvitations sends GET /groups/invitations',
        () async {
      final adapter = _CapturingAdapter();
      adapter.responseToReturn = ResponseBody.fromString(
        '''[
          {
            "id": 10,
            "group_id": 3,
            "invited_user_id": 9,
            "invited_by": 2,
            "status": "pending",
            "created_at": "2026-11-16T12:00:00Z",
            "responded_at": null,
            "expires_at": "2099-11-23T12:00:00Z"
          }
        ]''',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
      final dio = Dio(
          BaseOptions(baseUrl: 'https://taskflow-api-v1-225t.onrender.com'));
      dio.httpClientAdapter = adapter;

      final repo = InvitationRepository(ApiClient(dio));
      final list = await repo.getInvitations();

      expect(list, hasLength(1));
      expect(list.first.id, 10);
      expect(list.first.groupId, 3);
      expect(adapter.lastRequest?.method, 'GET');
      expect(adapter.lastRequest?.path, '/groups/invitations');
    });

    test(
        'InvitationRepository.respond sends PATCH /groups/invitations/{id}/respond',
        () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(
          BaseOptions(baseUrl: 'https://taskflow-api-v1-225t.onrender.com'));
      dio.httpClientAdapter = adapter;

      final repo = InvitationRepository(ApiClient(dio));
      final res = await repo.respond(15, InvitationStatus.accepted);

      expect(res.id, 15);
      expect(res.status, InvitationStatus.accepted);
      expect(adapter.lastRequest?.method, 'PATCH');
      expect(adapter.lastRequest?.path, '/groups/invitations/15/respond');
      expect(adapter.lastRequest?.data, {'status': 'accepted'});
    });
  });

  group('InvitationsInboxScreen Widget Tests', () {
    testWidgets('renders pending and expired invitations with actions',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invitationsControllerProvider
                .overrideWith(() => _MockInvitationsController()),
          ],
          child: MaterialApp(
            theme: AppTheme.build(AppThemeVariant.obsidianApplePrecision),
            home: const InvitationsInboxScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('INVITATIONS'), findsOneWidget);
      expect(find.text('Project #10'), findsOneWidget);
      expect(find.text('Project #11'), findsOneWidget);
      expect(find.text('ACCEPT'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('EXPIRED'), findsOneWidget);
    });
  });
}

class _MockInvitationsController extends InvitationsController {
  @override
  Future<List<InGroupInvitationResponse>> build() async => [
        InGroupInvitationResponse(
          id: 1,
          groupId: 10,
          invitedUserId: 5,
          invitedBy: 2,
          status: InvitationStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20),
          expiresAt: DateTime.utc(2099, 11, 27),
        ),
        InGroupInvitationResponse(
          id: 2,
          groupId: 11,
          invitedUserId: 5,
          invitedBy: 3,
          status: InvitationStatus.pending,
          createdAt: DateTime.utc(2020, 1, 1),
          expiresAt: DateTime.utc(2020, 1, 8),
        ),
      ];
}
