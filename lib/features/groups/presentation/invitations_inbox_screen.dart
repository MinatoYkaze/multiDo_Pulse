import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import 'groups_controller.dart';

/// In-app invitation inbox showing invitations received by the authenticated user.
class InvitationsInboxScreen extends ConsumerStatefulWidget {
  const InvitationsInboxScreen({super.key});

  @override
  ConsumerState<InvitationsInboxScreen> createState() =>
      _InvitationsInboxScreenState();
}

class _InvitationsInboxScreenState
    extends ConsumerState<InvitationsInboxScreen> {
  final Set<int> _processingIds = <int>{};

  Future<void> _respond(
    InGroupInvitationResponse inv,
    InvitationStatus status,
  ) async {
    if (_processingIds.contains(inv.id)) return;
    setState(() => _processingIds.add(inv.id));

    try {
      final updated = await ref
          .read(invitationsControllerProvider.notifier)
          .respond(inv.id, status);
      ref.read(hapticsProvider).success();

      if (!mounted) return;
      final groupLabel = updated.groupName ?? 'Project #${updated.groupId}';
      if (status == InvitationStatus.accepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined $groupLabel.')),
        );
        context.go('/projects/${updated.groupId}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation to $groupLabel rejected.')),
        );
      }
    } catch (e) {
      ref.read(hapticsProvider).heavy();
      if (!mounted) return;
      final apiErr = ApiException.from(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErr.message),
          backgroundColor: context.palette.warning,
        ),
      );
      if (apiErr.isNotFound ||
          apiErr.message.toLowerCase().contains('expired')) {
        ref.read(invitationsControllerProvider.notifier).refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(inv.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final invitationsAsync = ref.watch(invitationsControllerProvider);

    return Scaffold(
      backgroundColor: p.base,
      appBar: AppBar(
        backgroundColor: p.base,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects');
            }
          },
        ),
        title: Text(
          'INVITATIONS',
          style: t.labelLarge?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: p.textMuted),
            tooltip: 'Refresh invitations',
            onPressed: () =>
                ref.read(invitationsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: invitationsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: p.accent),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: p.warning),
                const SizedBox(height: 16),
                Text(
                  'Failed to load invitations',
                  style: t.titleMedium?.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  ApiException.from(e).message,
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref
                      .read(invitationsControllerProvider.notifier)
                      .refresh(),
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
        data: (invitations) {
          if (invitations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.surface2,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.border),
                      ),
                      child: Icon(Icons.mail_outline_rounded,
                          size: 48, color: p.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No invitations',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When someone invites you to collaborate on a project, it will appear here.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: p.accent,
            onRefresh: () =>
                ref.read(invitationsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) =>
                  _buildInvitationCard(ctx, invitations[idx]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvitationCard(
      BuildContext context, InGroupInvitationResponse inv) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final isProcessing = _processingIds.contains(inv.id);
    final isExpired = inv.isExpired;
    final isPending = inv.status == InvitationStatus.pending && !isExpired;
    final effectiveStatus =
        isExpired ? InvitationStatus.expired : inv.status;

    final groupTitle = inv.groupName ?? 'Project #${inv.groupId}';
    final inviterLabel = inv.inviterName ??
        inv.inviterEmail ??
        'User #${inv.invitedBy}';
    final expiryText =
        DateFormat.yMMMd().add_jm().format(inv.expiresAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecor.card(p, glowing: isPending),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border),
                ),
                child: Icon(Icons.folder_shared_outlined,
                    color: p.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupTitle,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invited by $inviterLabel',
                      style: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
              _statusBadge(context, effectiveStatus),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: p.textMuted),
              const SizedBox(width: 6),
              Text(
                isExpired ? 'Expired $expiryText' : 'Expires $expiryText',
                style: t.bodySmall?.copyWith(
                  color: isExpired ? p.warning : p.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _respond(inv, InvitationStatus.rejected),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('REJECT'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isProcessing
                        ? null
                        : () => _respond(inv, InvitationStatus.accepted),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ACCEPT'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, InvitationStatus status) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    late final Color color;
    switch (status) {
      case InvitationStatus.pending:
        color = p.accent;
      case InvitationStatus.accepted:
        color = Colors.green;
      case InvitationStatus.rejected:
      case InvitationStatus.expired:
        color = p.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: t.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
