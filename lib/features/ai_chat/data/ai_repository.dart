import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class ChatReply {
  const ChatReply(this.text, this.threadId);
  final String text;
  final String? threadId;
}

/// `/ai/*` endpoints. The reply shape isn't fixed by the schema names, so the
/// parsers accept the common variants.
class AiRepository {
  AiRepository(this._api);
  final ApiClient _api;

  static const _replyKeys = ['reply', 'response', 'message', 'answer', 'content', 'text'];

  /// POST /ai/chat
  Future<ChatReply> chat(AIChatRequest req) => _api.post(
        Api.aiChat,
        body: req.toJson(),
        parse: (d) {
          if (d is String) return ChatReply(d, null);
          if (d is Map) {
            for (final k in _replyKeys) {
              final v = d[k];
              if (v is String && v.isNotEmpty) {
                return ChatReply(v, d['thread_id']?.toString());
              }
            }
          }
          return const ChatReply('Done.', null);
        },
      );

  /// GET /ai/conversation → past threads
  Future<List<AIConversationResponse>> conversations() =>
      _api.get(Api.aiConversation, parse: (d) {
        Iterable? list;
        if (d is List) list = d;
        if (d is Map) {
          list = (d['conversations'] ?? d['threads'] ?? d['items']) as Iterable?;
          if (list == null && (d['thread_id'] != null || d['id'] != null)) list = [d];
        }
        return (list ?? const [])
            .map((e) => AIConversationResponse.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  /// POST /ai/conversation → new thread (thread_id)
  Future<AIConversationResponse> createConversation() => _api.post(
        Api.aiConversation,
        body: <String, dynamic>{},
        parse: (d) => ApiClient.obj(d, AIConversationResponse.fromJson),
      );
}

final aiRepositoryProvider =
    Provider<AiRepository>((ref) => AiRepository(ref.watch(apiClientProvider)));
