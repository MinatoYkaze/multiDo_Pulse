import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class InvitationRepository {
  InvitationRepository(this._api);
  final ApiClient _api;

  /// GET /groups/invitations/{token}/accept
  Future<MessageResponse> accept(String token) => _api.get(
        Api.acceptInvitation(token),
        parse: (d) => ApiClient.obj(d, MessageResponse.fromJson),
      );
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
    (ref) => InvitationRepository(ref.watch(apiClientProvider)));
