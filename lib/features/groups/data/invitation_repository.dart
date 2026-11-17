import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class InvitationRepository {
  InvitationRepository(this._api);
  final ApiClient _api;

  /// POST /groups/invitations/{token}/accept
  Future<MessageResponse> accept(String token) => _api.post(
        Api.acceptInvitation(token),
        parse: (d) => ApiClient.obj(d, MessageResponse.fromJson),
      );

  /// GET /groups/invitations/{token}/preview
  Future<InvitationPreview?> getPreview(String token) async {
    try {
      return await _api.get(
        Api.invitationPreview(token),
        parse: (d) => ApiClient.obj(d, InvitationPreview.fromJson),
      );
    } catch (_) {
      return null;
    }
  }
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
    (ref) => InvitationRepository(ref.watch(apiClientProvider)));
