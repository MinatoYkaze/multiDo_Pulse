import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class InvitationRepository {
  InvitationRepository(this._api);
  final ApiClient _api;

  /// GET /groups/invitations
  Future<List<InGroupInvitationResponse>> getInvitations() => _api.get(
        Api.groupInvitations,
        parse: (d) => ApiClient.list(d, InGroupInvitationResponse.fromJson),
      );

  /// PATCH /groups/invitations/{invitation_id}/respond
  Future<InGroupInvitationResponse> respond(
    int invitationId,
    InvitationStatus status,
  ) =>
      _api.patch(
        Api.respondInvitation(invitationId),
        body: GroupInvitationRespond(status: status).toJson(),
        parse: (d) => ApiClient.obj(d, InGroupInvitationResponse.fromJson),
      );
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
    (ref) => InvitationRepository(ref.watch(apiClientProvider)));
