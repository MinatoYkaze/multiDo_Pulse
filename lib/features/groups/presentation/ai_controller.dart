import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/ai_repository.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AIApproval? approval;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.approval,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AIState {
  final String? threadId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final AIApproval? pendingApproval;
  final String? error;

  const AIState({
    this.threadId,
    this.messages = const [],
    this.isLoading = false,
    this.pendingApproval,
    this.error,
  });

  AIState copyWith({
    String? threadId,
    List<ChatMessage>? messages,
    bool? isLoading,
    AIApproval? pendingApproval,
    bool clearApproval = false,
    String? error,
    bool clearError = false,
  }) {
    return AIState(
      threadId: threadId ?? this.threadId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      pendingApproval:
          clearApproval ? null : (pendingApproval ?? this.pendingApproval),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AIController extends StateNotifier<AIState> {
  AIController(this._repo) : super(const AIState());
  final AIRepository _repo;

  Future<void> initConversation([String? existingThreadId]) async {
    if (existingThreadId != null && existingThreadId.isNotEmpty) {
      state = state.copyWith(threadId: existingThreadId);
      return;
    }
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final conv = await _repo.createConversation();
      state = state.copyWith(
        threadId: conv.threadId,
        isLoading: false,
        messages: [
          ChatMessage(
            id: 'welcome',
            text:
                "Hello! I am your Project Assistant. I can help create tasks, assign members, organize priorities, and answer questions. How can I help you today?",
            isUser: false,
          ),
        ],
      );
    } catch (e) {
      // Fallback thread id if server conversation create fails or isn't required first
      final fallbackId = 'thread_${DateTime.now().millisecondsSinceEpoch}';
      state = state.copyWith(
        threadId: fallbackId,
        isLoading: false,
        messages: [
          ChatMessage(
            id: 'welcome',
            text:
                "Hello! I am your Project Assistant. I can help create tasks, assign members, and manage your workflow. What would you like to do?",
            isUser: false,
          ),
        ],
      );
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    String threadId = state.threadId ?? '';
    if (threadId.isEmpty) {
      try {
        final conv = await _repo.createConversation();
        threadId = conv.threadId;
        state = state.copyWith(threadId: threadId);
      } catch (_) {
        threadId = 'thread_${DateTime.now().millisecondsSinceEpoch}';
        state = state.copyWith(threadId: threadId);
      }
    }

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      text: text.trim(),
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );

    try {
      final res = await _repo.chat(AIChatRequest(
        threadId: threadId,
        message: text.trim(),
      ));

      final aiMsg = ChatMessage(
        id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
        text: res.message ??
            (res.isPendingApproval
                ? "Approval required for action: ${res.approval?.action}"
                : "Action completed."),
        isUser: false,
        approval: res.approval,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        pendingApproval: res.approval,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'err_${DateTime.now().microsecondsSinceEpoch}',
            text: "Sorry, I encountered an error processing your request. Please try again.",
            isUser: false,
          ),
        ],
      );
    }
  }

  Future<void> submitApproval({required bool accept}) async {
    final threadId = state.threadId;
    if (threadId == null || threadId.isEmpty) return;

    final decisionStr = accept ? 'accept' : 'reject';
    final userMsg = ChatMessage(
      id: 'decision_${DateTime.now().microsecondsSinceEpoch}',
      text: accept ? "✓ Approved action" : "✗ Rejected action",
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearApproval: true,
      clearError: true,
    );

    try {
      final res = await _repo.chat(AIChatRequest(
        threadId: threadId,
        decision: decisionStr,
      ));

      final aiMsg = ChatMessage(
        id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
        text: res.message ??
            (accept ? "Action was confirmed and executed." : "Action was cancelled."),
        isUser: false,
        approval: res.approval,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        pendingApproval: res.approval,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'err_${DateTime.now().microsecondsSinceEpoch}',
            text: "Failed to submit approval decision: ${e.toString()}",
            isUser: false,
          ),
        ],
      );
    }
  }
}

final aiControllerProvider =
    StateNotifierProvider.autoDispose<AIController, AIState>((ref) {
  final repo = ref.watch(aiRepositoryProvider);
  final controller = AIController(repo);
  controller.initConversation();
  return controller;
});
