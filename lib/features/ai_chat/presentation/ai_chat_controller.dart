import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../groups/presentation/groups_providers.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../data/ai_repository.dart';

class ChatMessage {
  const ChatMessage(this.fromUser, this.text, {this.error = false});
  final bool fromUser;
  final String text;
  final bool error;
}

class ChatState {
  const ChatState({this.threadId, this.messages = const [], this.sending = false});
  final String? threadId;
  final List<ChatMessage> messages;
  final bool sending;
  ChatState copyWith(
          {String? threadId,
          bool clearThread = false,
          List<ChatMessage>? messages,
          bool? sending}) =>
      ChatState(
        threadId: clearThread ? null : (threadId ?? this.threadId),
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

class AiChatController extends Notifier<ChatState> {
  AiRepository get _repo => ref.read(aiRepositoryProvider);

  @override
  ChatState build() => const ChatState();

  void newThread() => state = const ChatState();

  void openThread(AIConversationResponse c) {
    final msgs = <ChatMessage>[
      for (final m in c.messages)
        ChatMessage(
          (m['role'] ?? m['sender'] ?? 'assistant').toString() == 'user',
          (m['content'] ?? m['message'] ?? m['text'] ?? '').toString(),
        ),
    ];
    state = ChatState(
      threadId: c.threadId,
      messages: msgs.isEmpty
          ? [const ChatMessage(false, 'Conversation resumed. What would you like to do next?')]
          : msgs,
    );
  }

  static String friendly(Object e) {
    final ex = ApiException.from(e);
    final c = ex.statusCode;
    if (c == 404 || c == 405 || c == 501) {
      return 'The AI assistant isn’t available on this server yet.';
    }
    return ex.message;
  }

  Future<void> send(String text) async {
    final q = text.trim();
    if (q.isEmpty || state.sending) return;
    state = state.copyWith(messages: [...state.messages, ChatMessage(true, q)], sending: true);
    try {
      var tid = state.threadId;
      if (tid == null) {
        try {
          tid = (await _repo.createConversation()).threadId;
        } catch (_) {
          // let /ai/chat create the thread itself
        }
      }
      final r = await _repo.chat(AIChatRequest(message: q, threadId: tid ?? ''));
      state = state.copyWith(
        threadId: tid ?? r.threadId,
        messages: [...state.messages, ChatMessage(false, r.text)],
        sending: false,
      );
      _resync(); // the assistant may have created / changed tasks
    } catch (e) {
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(false, friendly(e), error: true)],
        sending: false,
      );
    }
  }

  Future<void> _resync() async {
    try {
      await ref.read(tasksControllerProvider.notifier).refresh();
    } catch (_) {}
    try {
      await ref.read(groupsControllerProvider.notifier).reload();
    } catch (_) {}
  }
}

final aiChatControllerProvider =
    NotifierProvider<AiChatController, ChatState>(AiChatController.new);

/// Past threads (GET /ai/conversation).
final aiThreadsProvider = FutureProvider.autoDispose<List<AIConversationResponse>>(
    (ref) => ref.read(aiRepositoryProvider).conversations());
