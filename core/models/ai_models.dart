import 'json_helpers.dart';

class AIChatRequest {
  final String message;
  final String? threadId;
  const AIChatRequest({required this.message, this.threadId});

  factory AIChatRequest.fromJson(Map<String, dynamic> j) => AIChatRequest(
      message: j['message'] as String, threadId: j['thread_id'] as String?);

  Map<String, dynamic> toJson() =>
      compact({'message': message, 'thread_id': threadId});
}

class AIConversationResponse {
  final String threadId;
  final String? title;
  final String? lastMessage;
  final String? reply;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> messages;

  const AIConversationResponse({
    required this.threadId,
    this.title,
    this.lastMessage,
    this.reply,
    this.createdAt,
    this.messages = const [],
  });

  factory AIConversationResponse.fromJson(Map<String, dynamic> j) =>
      AIConversationResponse(
        threadId: (j['thread_id'] ?? j['id']).toString(),
        title: j['title'] as String?,
        lastMessage: j['last_message'] as String?,
        reply: (j['reply'] ?? j['response']) as String?,
        createdAt: parseDate(j['created_at']),
        messages: (j['messages'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );

  Map<String, dynamic> toJson() => compact({
        'thread_id': threadId,
        'title': title,
        'last_message': lastMessage,
        'reply': reply,
        'created_at': dateToJson(createdAt),
        'messages': messages,
      });
}
