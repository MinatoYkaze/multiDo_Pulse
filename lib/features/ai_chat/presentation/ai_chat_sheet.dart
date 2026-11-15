import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import 'ai_chat_controller.dart';

/// Pulse AI: natural-language task management in a bottom sheet.
class AiChatSheet extends ConsumerStatefulWidget {
  const AiChatSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => const AiChatSheet(),
      );

  @override
  ConsumerState<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends ConsumerState<AiChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _history = false;

  static const _suggestions = [
    "What's due today?",
    'Add a task: review pull requests',
    'Summarize my open tasks',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final v = (text ?? _input.text).trim();
    if (v.isEmpty) return;
    _input.clear();
    ref.read(hapticsProvider).light();
    ref.read(aiChatControllerProvider.notifier).send(v);
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final chat = ref.watch(aiChatControllerProvider);
    ref.listen(aiChatControllerProvider.select((s) => s.messages.length), (_, __) => _toBottom());
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: AppDecor.sheet(p),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: p.textMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 11),
                  border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 18, color: p.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pulse AI', style: t.titleMedium),
                  Text(chat.threadId == null ? 'New conversation' : 'Thread ${chat.threadId}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ]),
              ),
              IconButton(
                tooltip: 'History',
                onPressed: () {
                  ref.read(hapticsProvider).selection();
                  setState(() => _history = !_history);
                  if (_history) ref.invalidate(aiThreadsProvider);
                },
                icon: Icon(Icons.history_rounded, color: _history ? p.accent : null),
              ),
              IconButton(
                tooltip: 'New chat',
                onPressed: () {
                  ref.read(aiChatControllerProvider.notifier).newThread();
                  setState(() => _history = false);
                },
                icon: const Icon(Icons.edit_square),
              ),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Divider(color: p.border),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _history ? _HistoryList(onPicked: () => setState(() => _history = false)) : _messages(chat, p, t),
            ),
          ),
          // input dock
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                decoration: BoxDecoration(
                  color: p.surface1,
                  borderRadius: BorderRadius.circular(p.usesGlass ? 22 : p.controlRadius),
                  border: Border.all(color: p.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Ask or tell Pulse AI…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _input,
                    builder: (_, __) {
                      final on = _input.text.trim().isNotEmpty && !chat.sending;
                      return GestureDetector(
                        onTap: on ? _send : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: on ? p.accent : const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(p.usesGlass ? 19 : 4),
                          ),
                          child: Icon(Icons.arrow_upward_rounded,
                              size: 20, color: on ? p.onAccent : p.textMuted),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _messages(ChatState chat, AppPalette p, TextTheme t) {
    if (chat.messages.isEmpty) {
      return ListView(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.auto_awesome_rounded, size: 40, color: p.accent),
          const SizedBox(height: 14),
          Text('How can I help?', textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text('Manage tasks in plain language — create, find, complete and plan.',
              textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: p.textMuted)),
          const SizedBox(height: 22),
          for (final s in _suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _send(s),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecor.card(p),
                  child: Row(children: [
                    Expanded(child: Text(s, style: t.bodyMedium)),
                    Icon(Icons.north_east_rounded, size: 16, color: p.textMuted),
                  ]),
                ),
              ),
            ),
        ],
      );
    }
    return ListView(
      key: const ValueKey('chat'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        for (final m in chat.messages) _Bubble(m: m),
        if (chat.sending) const _Typing(),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final ChatMessage m;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final user = m.fromUser;
    final r = p.isTerminal ? 6.0 : 18.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
          opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child)),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          decoration: BoxDecoration(
            color: user
                ? p.accent.withValues(alpha: 0.14)
                : m.error
                    ? p.warningBg
                    : p.surface1,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r),
              topRight: Radius.circular(r),
              bottomLeft: Radius.circular(user ? r : 4),
              bottomRight: Radius.circular(user ? 4 : r),
            ),
            border: Border.all(
                color: user
                    ? p.accent.withValues(alpha: 0.35)
                    : m.error
                        ? p.warningBorder.withValues(alpha: 0.5)
                        : p.border),
          ),
          child: SelectableText(m.text,
              style: t.bodyMedium?.copyWith(
                  height: 1.45, color: m.error ? p.warning : p.textPrimary)),
        ),
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(
                      alpha: 0.3 + 0.7 * (0.5 + 0.5 * (1 - ((_c.value * 3 - i) % 3).clamp(0.0, 1.0)))),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.onPicked});
  final VoidCallback onPicked;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(aiThreadsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AiChatController.friendly(e),
              textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: p.warning)),
        ),
      ),
      data: (threads) => threads.isEmpty
          ? Center(child: Text('No past conversations yet.', style: t.bodyMedium?.copyWith(color: p.textMuted)))
          : ListView(
              key: const ValueKey('history'),
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in threads)
                  GestureDetector(
                    onTap: () {
                      ref.read(hapticsProvider).selection();
                      ref.read(aiChatControllerProvider.notifier).openThread(c);
                      onPicked();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecor.card(p),
                      child: Row(children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 18, color: p.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.title ?? 'Conversation ${c.threadId}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge),
                            if (c.lastMessage != null)
                              Text(c.lastMessage!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}
