import 'json_helpers.dart';

class AIChatRequest {
  final String threadId;
  final String? message;
  final String? decision; // 'accept' or 'reject' for HITL confirmation

  const AIChatRequest({
    required this.threadId,
    this.message,
    this.decision,
  });

  factory AIChatRequest.fromJson(Map<String, dynamic> j) => AIChatRequest(
        threadId: (j['thread_id'] ?? '').toString(),
        message: j['message'] as String?,
        decision: j['decision'] as String?,
      );

  Map<String, dynamic> toJson() => compact({
        'thread_id': threadId,
        'message': message,
        'decision': decision,
      });
}

class AIApproval {
  final String action;
  final Map<String, dynamic> details;
  final String? message;

  const AIApproval({
    required this.action,
    this.details = const {},
    this.message,
  });

  factory AIApproval.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> detailsMap = const {};
    if (j['details'] is Map) {
      detailsMap = Map<String, dynamic>.from(j['details'] as Map);
    } else if (j['args'] is Map) {
      detailsMap = Map<String, dynamic>.from(j['args'] as Map);
    } else if (j['parameters'] is Map) {
      detailsMap = Map<String, dynamic>.from(j['parameters'] as Map);
    }

    return AIApproval(
      action: (j['action'] ?? j['tool'] ?? j['name'] ?? 'action') as String,
      details: detailsMap,
      message: j['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'details': details,
        'message': message,
      };
}

class AIChatResponse {
  final String status; // 'completed' or 'pending_approval'
  final String? message;
  final String? threadId;
  final AIApproval? approval;

  const AIChatResponse({
    required this.status,
    this.message,
    this.threadId,
    this.approval,
  });

  bool get isPendingApproval =>
      status == 'pending_approval' || approval != null;

  factory AIChatResponse.fromJson(Map<String, dynamic> j) {
    AIApproval? approvalObj;
    if (j['approval'] != null && j['approval'] is Map) {
      approvalObj =
          AIApproval.fromJson(Map<String, dynamic>.from(j['approval'] as Map));
    }

    return AIChatResponse(
      status: (j['status'] ?? 'completed') as String,
      message: (j['message'] ?? j['response'] ?? j['reply'] ?? j['content'])
          as String?,
      threadId: (j['thread_id'] ?? j['threadId'])?.toString(),
      approval: approvalObj,
    );
  }

  Map<String, dynamic> toJson() => compact({
        'status': status,
        'message': message,
        'thread_id': threadId,
        'approval': approval?.toJson(),
      });
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
