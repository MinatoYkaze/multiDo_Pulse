import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_palette.dart';
import 'ai_controller.dart';
import 'widgets/conversation_drawer.dart';
import 'widgets/hitl_approval_card.dart';
import 'widgets/markdown_message_view.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key, this.initialThreadId});
  final String? initialThreadId;

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialThreadId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(aiControllerProvider.notifier)
            .initConversation(widget.initialThreadId);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(aiControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final aiState = ref.watch(aiControllerProvider);

    // Scroll to bottom when message count changes
    ref.listen(aiControllerProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });

    final title = aiState.title ?? 'AI Assistant';

    return Scaffold(
      backgroundColor: p.base,
      drawer: const ConversationDrawer(),
      appBar: AppBar(
        backgroundColor: p.surface1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/today');
            }
          },
        ),
        title: Builder(
          builder: (ctx) => InkWell(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: p.textMuted),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Conversation History',
            onPressed: () {},
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.add_comment_outlined, color: p.accent),
              tooltip: 'New Chat',
              onPressed: () =>
                  ref.read(aiControllerProvider.notifier).newConversation(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: p.surface2.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: p.accent, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'MultiDo Pulse · TaskFlow Intelligence',
                    style: t.labelSmall?.copyWith(color: p.accent),
                  ),
                  const Spacer(),
                  if (aiState.threadId != null)
                    Text(
                      'ID: ${aiState.threadId!.substring(0, aiState.threadId!.length > 6 ? 6 : aiState.threadId!.length)}',
                      style: t.labelSmall?.copyWith(
                        color: p.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
            // Chat history
            Expanded(
              child: aiState.messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: aiState.messages.length,
                      itemBuilder: (ctx, idx) {
                        final msg = aiState.messages[idx];
                        return _buildMessageRow(msg);
                      },
                    ),
            ),
            // Rate Limit (429) & Error Banner
            if (aiState.error != null) _buildErrorBanner(aiState),
            // Human-in-the-Loop pending approval card
            if (aiState.pendingApproval != null)
              HITLApprovalCard(
                approval: aiState.pendingApproval!,
                isLoading: aiState.isLoading,
                onApprove: () => ref
                    .read(aiControllerProvider.notifier)
                    .submitApproval(accept: true),
                onReject: () => ref
                    .read(aiControllerProvider.notifier)
                    .submitApproval(accept: false),
              ),
            // Input bar
            _buildInputBar(aiState),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 40, color: p.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'How can I help you today?',
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about tasks, priorities, deadlines, or collaborative projects.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPromptChip("What tasks do I have today?"),
                _buildPromptChip("Which task is most urgent?"),
                _buildPromptChip("Create a task for project"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return ActionChip(
      label: Text(prompt),
      backgroundColor: p.surface2,
      side: BorderSide(color: p.border),
      labelStyle: t.bodySmall?.copyWith(color: p.textPrimary),
      onPressed: () {
        _inputController.text = prompt;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageRow(ChatMessage msg) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              backgroundColor: p.accent.withValues(alpha: 0.15),
              radius: 16,
              child: Icon(Icons.auto_awesome_rounded,
                  color: p.accent, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isUser ? p.accent : p.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                      bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: msg.isUser
                          ? p.accent
                          : p.border.withValues(alpha: 0.8),
                    ),
                  ),
                  child: MarkdownMessageView(
                    text: msg.text,
                    isUser: msg.isUser,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(msg.timestamp.toLocal()),
                  style: t.labelSmall?.copyWith(
                    fontSize: 9,
                    color: p.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(AIState aiState) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.warningBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: p.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              aiState.error!,
              style: t.bodySmall?.copyWith(color: p.warning),
            ),
          ),
          if (aiState.lastFailedMessage != null)
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('RETRY'),
              style: TextButton.styleFrom(foregroundColor: p.warning),
              onPressed: aiState.isLoading
                  ? null
                  : () => ref
                      .read(aiControllerProvider.notifier)
                      .retryLastMessage(),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AIState aiState) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: p.surface1,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              enabled: !aiState.isLoading,
              style: t.bodyMedium,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask AI or request an action...',
                hintStyle: t.bodyMedium?.copyWith(color: p.textMuted),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
            ),
            icon: aiState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
            onPressed: aiState.isLoading ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
