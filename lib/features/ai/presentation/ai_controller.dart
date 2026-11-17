import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../groups/data/ai_repository.dart';

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
  final String? title;
  final List<ChatMessage> messages;
  final bool isLoading;
  final AIApproval? pendingApproval;
  final String? error;
  final String? lastFailedMessage;
  final bool isRateLimited;

  const AIState({
    this.threadId,
    this.title,
    this.messages = const [],
    this.isLoading = false,
    this.pendingApproval,
    this.error,
    this.lastFailedMessage,
    this.isRateLimited = false,
  });

  AIState copyWith({
    String? threadId,
    String? title,
    List<ChatMessage>? messages,
    bool? isLoading,
    AIApproval? pendingApproval,
    bool clearApproval = false,
    String? error,
    bool clearError = false,
    String? lastFailedMessage,
    bool clearFailedMessage = false,
    bool? isRateLimited,
  }) {
    return AIState(
      threadId: threadId ?? this.threadId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      pendingApproval:
          clearApproval ? null : (pendingApproval ?? this.pendingApproval),
      error: clearError ? null : (error ?? this.error),
      lastFailedMessage: clearFailedMessage
          ? null
          : (lastFailedMessage ?? this.lastFailedMessage),
      isRateLimited: isRateLimited ?? this.isRateLimited,
    );
  }
}

final conversationsListProvider =
    FutureProvider.autoDispose<List<AIConversationResponse>>((ref) async {
  final repo = ref.watch(aiRepositoryProvider);
  return await repo.getConversations();
});

class AIController extends StateNotifier<AIState> {
  AIController(this._repo, this._ref) : super(const AIState());
  final AIRepository _repo;
  final Ref _ref;

  Future<void> initConversation([String? existingThreadId]) async {
    if (existingThreadId != null && existingThreadId.isNotEmpty) {
      state = state.copyWith(threadId: existingThreadId);
      return;
    }
    await newConversation();
  }

  Future<void> newConversation() async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearApproval: true,
        clearFailedMessage: true,
        isRateLimited: false,
      );

      final conv = await _repo.createConversation();
      _ref.invalidate(conversationsListProvider);

      state = state.copyWith(
        threadId: conv.threadId,
        title: conv.title ?? 'New chat',
        isLoading: false,
        messages: [
          ChatMessage(
            id: 'welcome',
            text:
                "Hello! I am your MultiDo AI assistant.\n\nI can help prioritize your day, manage personal tasks, organize group projects, and assign work to teammates. How can I help you?",
            isUser: false,
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiException.from(e).message,
        messages: [
          ChatMessage(
            id: 'welcome_fallback',
            text:
                "Hello! I am your MultiDo AI assistant. Start typing below to begin our session.",
            isUser: false,
          ),
        ],
      );
    }
  }

  void selectConversation(AIConversationResponse conv) {
    if (state.threadId == conv.threadId) return;

    state = state.copyWith(
      threadId: conv.threadId,
      title: conv.title,
      clearError: true,
      clearApproval: true,
      clearFailedMessage: true,
      isRateLimited: false,
      messages: [
        ChatMessage(
          id: 'resumed_${conv.threadId}',
          text:
              "Continuing conversation: **${conv.title ?? 'Chat'}**.\nAsk me to review your tasks or take an action.",
          isUser: false,
        ),
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (state.isLoading) return; // Prevent duplicate concurrent submissions

    String? currentThread = state.threadId;

    // Ensure thread exists before calling /ai/chat (preventing 404)
    if (currentThread == null || currentThread.isEmpty) {
      try {
        final conv = await _repo.createConversation();
        currentThread = conv.threadId;
        _ref.invalidate(conversationsListProvider);
        state = state.copyWith(threadId: currentThread, title: conv.title);
      } catch (e) {
        state = state.copyWith(
          error: ApiException.from(e).message,
          lastFailedMessage: trimmed,
        );
        return;
      }
    }

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
      clearFailedMessage: true,
      isRateLimited: false,
    );

    try {
      final res = await _repo.chat(AIChatRequest(
        threadId: currentThread,
        message: trimmed,
      ));

      final aiMsg = ChatMessage(
        id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
        text: res.message ??
            (res.isPendingApproval
                ? "Approval required for action: **${res.approval?.action}**"
                : "Action completed successfully."),
        isUser: false,
        approval: res.approval,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        pendingApproval: res.approval,
        clearFailedMessage: true,
      );
    } catch (e) {
      final apiErr = ApiException.from(e);
      final is429 = apiErr.statusCode == 429 ||
          apiErr.message.toLowerCase().contains('rate limit') ||
          apiErr.message.toLowerCase().contains('tpm');
      final isTimeout = apiErr.isReceiveTimeout;

      String displayMessage;
      String cardMessage;
      if (is429) {
        displayMessage =
            "The AI model is temporarily busy (Groq capacity limit reached). Please wait a few seconds and tap Retry.";
        cardMessage =
            "⚠️ **Capacity Limit Exceeded (429)**\n\nThe AI Assistant has reached its token throughput limit on Groq. Please tap **Retry** in a moment.";
      } else if (isTimeout) {
        displayMessage =
            "The AI request timed out. Complex operations may still be completing on the server. Please check your tasks or tap Retry.";
        cardMessage =
            "⏳ **Request Timed Out**\n\nThe AI assistant took longer than 90 seconds to respond. The server may still be completing your task operations in the background. Tap **Retry** if your request did not complete.";
      } else if (apiErr.isConnectionTimeout) {
        displayMessage =
            "Connection timed out. The server may be starting up. Please tap Retry.";
        cardMessage =
            "🔌 **Connection Timed Out**\n\nCould not connect to the server within 15 seconds. Please tap **Retry**.";
      } else {
        displayMessage = apiErr.message;
        cardMessage = "⚠️ **Error:** ${apiErr.message}";
      }

      state = state.copyWith(
        isLoading: false,
        error: displayMessage,
        lastFailedMessage: trimmed,
        isRateLimited: is429,
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'err_${DateTime.now().microsecondsSinceEpoch}',
            text: cardMessage,
            isUser: false,
          ),
        ],
      );
    }
  }

  Future<void> retryLastMessage() async {
    if (state.isLoading) return; // Prevent duplicate retry while loading
    final msg = state.lastFailedMessage;
    if (msg != null && msg.isNotEmpty) {
      await sendMessage(msg);
    }
  }

  Future<void> submitApproval({required bool accept}) async {
    if (state.isLoading) return; // Prevent duplicate approval submission
    final currentThread = state.threadId;
    if (currentThread == null || currentThread.isEmpty) return;

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
        threadId: currentThread,
        decision: decisionStr,
      ));

      final aiMsg = ChatMessage(
        id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
        text: res.message ??
            (accept
                ? "Action confirmed and executed successfully."
                : "Action cancelled."),
        isUser: false,
        approval: res.approval,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        pendingApproval: res.approval,
      );
    } catch (e) {
      final apiErr = ApiException.from(e);
      state = state.copyWith(
        isLoading: false,
        error: apiErr.message,
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'err_${DateTime.now().microsecondsSinceEpoch}',
            text: "Failed to submit decision: ${apiErr.message}",
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
  final controller = AIController(repo, ref);
  controller.initConversation();
  return controller;
});
