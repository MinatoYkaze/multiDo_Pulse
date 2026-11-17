import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_palette.dart';
import '../ai_controller.dart';

class ConversationDrawer extends ConsumerWidget {
  const ConversationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final conversationsAsync = ref.watch(conversationsListProvider);
    final activeThreadId =
        ref.watch(aiControllerProvider.select((s) => s.threadId));

    return Drawer(
      backgroundColor: p.surface2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: p.accent, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'CONVERSATIONS',
                    style: t.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: p.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: p.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('NEW CONVERSATION'),
                onPressed: () {
                  ref.read(aiControllerProvider.notifier).newConversation();
                  Navigator.of(context).pop();
                },
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: conversationsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: p.accent),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load conversations',
                      style: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No past conversations found.',
                          style: t.bodySmall?.copyWith(color: p.textMuted),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, idx) {
                      final item = list[idx];
                      final isActive = item.threadId == activeThreadId;

                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isActive ? p.accent : Colors.transparent,
                          ),
                        ),
                        tileColor: isActive
                            ? p.accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        leading: Icon(
                          isActive
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: isActive ? p.accent : p.textMuted,
                        ),
                        title: Text(
                          item.title != null && item.title!.isNotEmpty
                              ? item.title!
                              : 'Chat ${item.threadId.substring(0, 8)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium?.copyWith(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? p.accent : p.textPrimary,
                          ),
                        ),
                        subtitle: item.createdAt != null
                            ? Text(
                                DateFormat('MMM d, h:mm a')
                                    .format(item.createdAt!.toLocal()),
                                style: t.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: p.textMuted,
                                ),
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(aiControllerProvider.notifier)
                              .selectConversation(item);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
