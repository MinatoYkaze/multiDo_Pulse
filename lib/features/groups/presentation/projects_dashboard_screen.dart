import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import 'create_group_dialog.dart';
import 'groups_controller.dart';

class ProjectsDashboardScreen extends ConsumerWidget {
  const ProjectsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final groupsAsync = ref.watch(groupsControllerProvider);
    final pendingInvitesCount = ref.watch(
      invitationsControllerProvider.select(
        (async) =>
            async.valueOrNull
                ?.where(
                    (i) => i.status == InvitationStatus.pending && !i.isExpired)
                .length ??
            0,
      ),
    );

    return Scaffold(
      backgroundColor: p.base,
      appBar: AppBar(
        backgroundColor: p.base,
        elevation: 0,
        title: Text(
          'PROJECTS',
          style: t.labelLarge?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Invitations',
            onPressed: () => context.push('/invitations'),
            icon: Badge(
              isLabelVisible: pendingInvitesCount > 0,
              label: Text('$pendingInvitesCount'),
              child: Icon(Icons.mail_outline_rounded, color: p.textPrimary),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: p.accent),
            tooltip: 'New Project',
            onPressed: () => CreateGroupDialog.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 60 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          icon: const Icon(Icons.add),
          label: const Text('NEW PROJECT'),
          onPressed: () => CreateGroupDialog.show(context),
        ),
      ),
      body: groupsAsync.when(
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
                  'Failed to load projects',
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
                  onPressed: () =>
                      ref.read(groupsControllerProvider.notifier).refresh(),
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
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
                      child: Icon(Icons.folder_open_outlined,
                          size: 48, color: p.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No projects yet',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a collaborative project workspace or accept an invitation to get started.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('CREATE PROJECT'),
                      onPressed: () => CreateGroupDialog.show(context),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.mail_outline_rounded),
                      label: Text(
                        pendingInvitesCount > 0
                            ? 'VIEW INVITATIONS ($pendingInvitesCount)'
                            : 'VIEW INVITATIONS',
                      ),
                      onPressed: () => context.push('/invitations'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: p.accent,
            onRefresh: () =>
                ref.read(groupsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 140 + MediaQuery.paddingOf(context).bottom),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final group = groups[idx];
                return _buildProjectCard(ctx, ref, group);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, WidgetRef ref, Group group) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(p.cardRadius),
        onTap: () {
          context.go('/projects/${group.id}');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecor.card(p),
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
                    child: Icon(Icons.folder_special,
                        color: p.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        if (group.description != null &&
                            group.description!.isNotEmpty)
                          Text(
                            group.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(color: p.textMuted),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.textMuted, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress',
                      style: t.bodySmall?.copyWith(
                          color: p.textMuted, fontSize: 11)),
                  Text(
                    '${(group.progress * 100).toInt()}%',
                    style: t.labelSmall?.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: group.progress,
                  minHeight: 4,
                  backgroundColor: p.surface3,
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
              const SizedBox(height: 14),
              // Bottom badges
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 13, color: p.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} / 3 members',
                          style: t.labelSmall?.copyWith(
                            color: p.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist, size: 13, color: p.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${group.completedTaskCount}/${group.taskCount} tasks',
                          style: t.labelSmall?.copyWith(
                            color: p.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
