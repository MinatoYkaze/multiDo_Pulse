import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AIRepository {
  AIRepository(this._api);
  final ApiClient _api;

  /// POST /ai/conversation
  Future<AIConversationResponse> createConversation() => _api.post(
        Api.aiConversation,
        parse: (d) => ApiClient.obj(d, AIConversationResponse.fromJson),
      );

  /// GET /ai/conversation
  Future<List<AIConversationResponse>> getConversations() => _api.get(
        Api.aiConversation,
        parse: (d) => ApiClient.list(d, AIConversationResponse.fromJson),
      );

  /// POST /ai/chat
  /// Long-running agentic LLM requests (LangGraph tool execution) can take 30-60+ seconds.
  /// Dedicated 90-second receiveTimeout prevents premature client-side aborts.
  Future<AIChatResponse> chat(AIChatRequest req) => _api.post(
        Api.aiChat,
        body: req.toJson(),
        receiveTimeout: const Duration(seconds: 90),
        parse: (d) => ApiClient.obj(d, AIChatResponse.fromJson),
      );
}

final aiRepositoryProvider = Provider<AIRepository>(
  (ref) => AIRepository(ref.watch(apiClientProvider)),
);
