import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../tasks/presentation/widgets/priority_badge.dart';
import '../domain/group_permission_policy.dart';
import 'ai_controller.dart';
import 'group_task_editor_sheet.dart';
import 'groups_controller.dart';
import 'invite_member_dialog.dart';

class GroupWorkspaceScreen extends ConsumerStatefulWidget {
  const GroupWorkspaceScreen({super.key, required this.groupId});
  final int groupId;

  @override
  ConsumerState<GroupWorkspaceScreen> createState() =>
      _GroupWorkspaceScreenState();
}

class _GroupWorkspaceScreenState extends ConsumerState<GroupWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);
  String _taskFilter = 'all'; // 'all', 'me', 'done'
  final Set<int> _expandedTasks = {};
  final Map<int, TextEditingController> _subtaskControllers = {};
  final TextEditingController _chatInputController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _chatInputController.dispose();
    for (final c in _subtaskControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getSubtaskController(int taskId) {
    return _subtaskControllers.putIfAbsent(
        taskId, () => TextEditingController());
  }

  void _showDeleteGroupDialog(Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This action cannot be undone and will delete all shared tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.palette.warning,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(groupsControllerProvider.notifier)
                    .deleteGroup(group.id);
                if (mounted) context.go('/projects');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiException.from(e).message)),
                  );
                }
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Project?'),
        content: Text(
          'Are you sure you want to leave "${group.name}"? You will lose access to its shared tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.palette.warning,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(groupsControllerProvider.notifier)
                    .leaveGroup(group.id);
                if (mounted) context.go('/projects');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiException.from(e).message)),
                  );
                }
              }
            },
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync =
        ref.watch(groupMembersControllerProvider(widget.groupId));
    final currentUserId =
        int.tryParse(ref.watch(currentUserProvider.select((u) => u?.id)) ?? '');

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: p.base,
        appBar: AppBar(backgroundColor: p.base, elevation: 0),
        body: Center(child: CircularProgressIndicator(color: p.accent)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: p.base,
        appBar: AppBar(
          backgroundColor: p.base,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/projects'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: p.warning),
              const SizedBox(height: 12),
              Text(
                'Could not load project',
                style: t.titleMedium?.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                ApiException.from(e).message,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.refresh(groupDetailProvider(widget.groupId)),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
      data: (group) {
        final isOwner = group.ownerId == currentUserId;
        final myMember = membersAsync.valueOrNull?.firstWhere(
          (m) => m.userId == currentUserId,
          orElse: () => GroupMemberResponse(
            userId: currentUserId ?? -1,
            role: isOwner ? Role.owner : Role.member,
          ),
        );
        final userRole = myMember?.role ?? (isOwner ? Role.owner : Role.member);
        final policy = GroupPermissionPolicy(
          currentUserId: currentUserId,
          group: group,
          userRole: userRole,
        );

        return Scaffold(
          backgroundColor: p.base,
          appBar: AppBar(
            backgroundColor: p.surface1,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/projects'),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.name,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    if (policy.isOwner) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: p.accent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'OWNER',
                          style: t.labelSmall?.copyWith(
                            color: p.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (policy.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.surface3,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(
                          'ADMIN',
                          style: t.labelSmall?.copyWith(
                            color: p.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
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
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: p.textMuted),
                color: p.surface2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: p.border),
                ),
                onSelected: (val) {
                  if (val == 'delete') {
                    _showDeleteGroupDialog(group);
                  } else if (val == 'leave') {
                    _showLeaveGroupDialog(group);
                  } else if (val == 'invite') {
                    final memberCount =
                        membersAsync.valueOrNull?.length ?? group.memberCount;
                    InviteMemberDialog.show(
                      context,
                      groupId: group.id,
                      currentMemberCount: memberCount,
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  if (policy.canInviteMembers)
                    const PopupMenuItem(
                      value: 'invite',
                      child: Row(
                        children: [
                          Icon(Icons.person_add_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Invite Member'),
                        ],
                      ),
                    ),
                  if (!policy.isOwner)
                    PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app,
                              size: 18, color: p.warning),
                          const SizedBox(width: 8),
                          Text('Leave Project',
                              style: TextStyle(color: p.warning)),
                        ],
                      ),
                    ),
                  if (policy.canDeleteGroup)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: p.warning),
                          const SizedBox(width: 8),
                          Text('Delete Project',
                              style: TextStyle(color: p.warning)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: p.accent,
              indicatorWeight: 2,
              labelColor: p.accent,
              unselectedLabelColor: p.textMuted,
              labelStyle: t.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'OVERVIEW'),
                Tab(icon: Icon(Icons.checklist_rounded), text: 'TASKS'),
                Tab(icon: Icon(Icons.group_outlined), text: 'MEMBERS'),
                Tab(icon: Icon(Icons.auto_awesome), text: 'AI ASSISTANT'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(group, membersAsync, policy),
              _buildTasksTab(group, membersAsync, currentUserId, policy),
              _buildMembersTab(group, membersAsync, currentUserId, policy),
              _buildAIAssistantTab(group),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab(
    Group group,
    AsyncValue<List<GroupMemberResponse>> membersAsync,
    GroupPermissionPolicy policy,
  ) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tasksAsync =
        ref.watch(groupTasksControllerProvider(widget.groupId));

    final tasks = tasksAsync.valueOrNull ?? const [];
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final pendingTasks = totalTasks - completedTasks;
    final progress =
        totalTasks == 0 ? 0.0 : (completedTasks / totalTasks).clamp(0.0, 1.0);

    return RefreshIndicator(
      color: p.accent,
      onRefresh: () async {
        ref.invalidate(groupDetailProvider(widget.groupId));
        await ref
            .read(groupTasksControllerProvider(widget.groupId).notifier)
            .refresh();
        await ref
            .read(groupMembersControllerProvider(widget.groupId).notifier)
            .refresh();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 100 + MediaQuery.paddingOf(context).bottom),
        children: [
          // Project Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecor.card(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_special_outlined,
                        color: p.accent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.name,
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (group.description != null &&
                    group.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description!,
                    style: t.bodyMedium?.copyWith(color: p.textMuted),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Completion Rate',
                        style: t.bodySmall?.copyWith(color: p.textMuted)),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: t.labelLarge?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: p.surface3,
                    valueColor: AlwaysStoppedAnimation(p.accent),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatPill('TOTAL', '$totalTasks', Icons.task_alt),
                    const SizedBox(width: 12),
                    _buildStatPill('PENDING', '$pendingTasks', Icons.pending_actions),
                    const SizedBox(width: 12),
                    _buildStatPill('DONE', '$completedTasks', Icons.done_all),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Quick Actions
          Text('QUICK ACTIONS',
              style: t.labelSmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (policy.canCreateTask) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Add Task'),
                    onPressed: () {
                      _tabController.animateTo(1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (policy.canInviteMembers) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Invite'),
                    onPressed: () {
                      final memberCount =
                          membersAsync.valueOrNull?.length ?? group.memberCount;
                      InviteMemberDialog.show(
                        context,
                        groupId: group.id,
                        currentMemberCount: memberCount,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.smart_toy_outlined, size: 18),
                  label: const Text('Ask AI'),
                  onPressed: () {
                    _tabController.animateTo(3);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Collaborators snippet
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COLLABORATORS',
                  style: t.labelSmall?.copyWith(color: p.textMuted)),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          membersAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: p.accent)),
            error: (e, _) => Text(ApiException.from(e).message,
                style: TextStyle(color: p.warning)),
            data: (members) {
              if (members.isEmpty) {
                return Text('No collaborators yet.',
                    style: t.bodyMedium?.copyWith(color: p.textMuted));
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: AppDecor.card(p),
                child: Column(
                  children: members
                      .map((m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: p.surface3,
                              child: Text(
                                m.initials,
                                style: t.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: p.accent),
                              ),
                            ),
                            title: Text(m.displayName, style: t.bodyMedium),
                            subtitle: Text(m.email ?? '',
                                style:
                                    t.bodySmall?.copyWith(color: p.textMuted)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: m.role == Role.owner
                                    ? p.accent.withValues(alpha: 0.15)
                                    : p.surface3,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.role.name.toUpperCase(),
                                style: t.labelSmall?.copyWith(
                                  color: m.role == Role.owner
                                      ? p.accent
                                      : p.textMuted,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, IconData icon) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: p.accent),
            const SizedBox(height: 4),
            Text(
              value,
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: p.textPrimary,
              ),
            ),
            Text(
              label,
              style: t.labelSmall?.copyWith(
                color: p.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: TASKS
  // ---------------------------------------------------------------------------

  Widget _buildTasksTab(
    Group group,
    AsyncValue<List<GroupMemberResponse>> membersAsync,
    int? currentUserId,
    GroupPermissionPolicy policy,
  ) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tasksAsync =
        ref.watch(groupTasksControllerProvider(widget.groupId));
    final memberList = membersAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: policy.canCreateTask
          ? Padding(
              padding: EdgeInsets.only(
                bottom: 60 + MediaQuery.paddingOf(context).bottom,
              ),
              child: FloatingActionButton.extended(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                icon: const Icon(Icons.add),
                label: const Text('ADD TASK'),
                onPressed: () {
                  GroupTaskEditorSheet.show(
                    context,
                    groupId: group.id,
                    members: memberList,
                    canAssign: policy.canAssignTask,
                  );
                },
              ),
            )
          : null,
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: p.surface1.withValues(alpha: 0.5),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Tasks'),
                const SizedBox(width: 8),
                _buildFilterChip('me', 'Assigned to Me'),
                const SizedBox(width: 8),
                _buildFilterChip('done', 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: p.accent)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 36, color: p.warning),
                    const SizedBox(height: 8),
                    Text(ApiException.from(e).message,
                        style: TextStyle(color: p.warning)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref
                          .read(groupTasksControllerProvider(widget.groupId)
                              .notifier)
                          .refresh(),
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
              data: (tasks) {
                // Apply filters
                final filtered = tasks.where((task) {
                  if (_taskFilter == 'me') {
                    return task.assignedTo == currentUserId;
                  } else if (_taskFilter == 'done') {
                    return task.isCompleted;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist, size: 48, color: p.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _taskFilter == 'me'
                              ? 'No tasks assigned to you.'
                              : _taskFilter == 'done'
                                  ? 'No completed tasks yet.'
                                  : 'No tasks in this project yet.',
                          style: t.bodyMedium?.copyWith(color: p.textMuted),
                        ),
                        if (policy.canCreateTask) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('CREATE FIRST TASK'),
                            onPressed: () {
                              GroupTaskEditorSheet.show(
                                context,
                                groupId: group.id,
                                members: memberList,
                                canAssign: policy.canAssignTask,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: p.accent,
                  onRefresh: () => ref
                      .read(groupTasksControllerProvider(widget.groupId).notifier)
                      .refresh(),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, 140 + MediaQuery.paddingOf(context).bottom),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final task = filtered[idx];
                      return _buildTaskCard(task, group, memberList, policy);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final isSelected = _taskFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _taskFilter = value),
      selectedColor: p.accent,
      backgroundColor: p.surface2,
      labelStyle: t.labelSmall?.copyWith(
        color: isSelected ? p.onAccent : p.textMuted,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTaskCard(
    GroupTaskResponse task,
    Group group,
    List<GroupMemberResponse> members,
    GroupPermissionPolicy policy,
  ) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final isExpanded = _expandedTasks.contains(task.id);

    // Find assignee name
    final assignee = members.firstWhere(
      (m) => m.userId == task.assignedTo,
      orElse: () => GroupMemberResponse(
        userId: task.assignedTo ?? -1,
        name: task.assigneeName ?? (task.assignedTo != null ? 'User ${task.assignedTo}' : 'Unassigned'),
      ),
    );

    return Container(
      decoration: AppDecor.card(p, dimmed: task.isCompleted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion Checkbox
                Builder(builder: (ctx) {
                  final canToggle = policy.canToggleTaskStatus(task);
                  return InkWell(
                    onTap: canToggle
                        ? () {
                            ref
                                .read(groupTasksControllerProvider(widget.groupId).notifier)
                                .toggleTask(task);
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only the project owner or assignee can change task status.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      decoration: BoxDecoration(
                        color: task.isCompleted ? p.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: task.isCompleted
                              ? p.accent
                              : (canToggle ? p.border : p.border.withValues(alpha: 0.3)),
                          width: 1.5,
                        ),
                      ),
                      child: task.isCompleted
                          ? Icon(Icons.check, size: 16, color: p.onAccent)
                          : null,
                    ),
                  );
                }),
                // Task Title and Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: t.titleMedium?.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? p.textMuted
                              : p.textPrimary,
                        ),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: t.bodySmall?.copyWith(color: p.textMuted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          PriorityBadge(priority: task.priority),
                          // Assignee Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.surface3,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 12, color: p.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  assignee.displayName,
                                  style: t.labelSmall?.copyWith(
                                    color: p.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Due Date
                          if (task.dueDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event,
                                    size: 12, color: p.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d').format(task.dueDate!),
                                  style: t.labelSmall?.copyWith(
                                    color: p.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions (Edit, Delete, Subtasks toggle)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: p.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTasks.remove(task.id);
                      } else {
                        _expandedTasks.add(task.id);
                        ref
                            .read(groupTasksControllerProvider(widget.groupId)
                                .notifier)
                            .fetchSubtasks(task.id);
                      }
                    });
                  },
                ),
                Builder(builder: (ctx) {
                  final canEdit = policy.canEditTask(task);
                  final canDelete = policy.canDeleteTask;
                  if (!canEdit && !canDelete) return const SizedBox.shrink();

                  return PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: p.textMuted),
                    color: p.surface2,
                    onSelected: (val) {
                      if (val == 'edit') {
                        GroupTaskEditorSheet.show(
                          context,
                          groupId: group.id,
                          task: task,
                          members: members,
                          canAssign: policy.canAssignTask,
                        );
                      } else if (val == 'delete') {
                        ref
                            .read(groupTasksControllerProvider(widget.groupId)
                                .notifier)
                            .deleteTask(task.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Task'),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Task',
                              style: TextStyle(color: p.warning)),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
          // Subtasks Accordion
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: p.surface2.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUBTASKS',
                      style: t.labelSmall?.copyWith(color: p.textMuted)),
                  const SizedBox(height: 8),
                  if (task.subtasks.isEmpty)
                    Text('No subtasks yet.',
                        style: t.bodySmall?.copyWith(color: p.textMuted))
                  else
                    ...task.subtasks.map((st) {
                      final canToggleSt = policy.canToggleTaskStatus(task);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: canToggleSt
                                  ? () {
                                      ref
                                          .read(groupTasksControllerProvider(
                                                  widget.groupId)
                                              .notifier)
                                          .toggleSubtask(task.id, st);
                                    }
                                  : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Only the project owner or assignee can change subtask status.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: st.isCompleted
                                      ? p.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color:
                                        st.isCompleted ? p.accent : p.border,
                                    width: 1.2,
                                  ),
                                ),
                                child: st.isCompleted
                                    ? Icon(Icons.check,
                                        size: 14, color: p.onAccent)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                st.title,
                                style: t.bodySmall?.copyWith(
                                  decoration: st.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: st.isCompleted
                                      ? p.textMuted
                                      : p.textPrimary,
                                ),
                              ),
                            ),
                            if (policy.canDeleteSubtask)
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 14, color: p.textMuted),
                                onPressed: () {
                                  ref
                                      .read(groupTasksControllerProvider(
                                              widget.groupId)
                                          .notifier)
                                      .deleteSubtask(task.id, st.id);
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                  if (policy.canCreateSubtask(task)) ...[
                    const SizedBox(height: 8),
                    // Add Subtask Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _getSubtaskController(task.id),
                            style: t.bodySmall,
                            decoration: InputDecoration(
                              hintText: 'Add a subtask...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: p.border),
                              ),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                ref
                                    .read(groupTasksControllerProvider(
                                            widget.groupId)
                                        .notifier)
                                    .createSubtask(task.id, val.trim());
                                _getSubtaskController(task.id).clear();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () {
                            final c = _getSubtaskController(task.id);
                            if (c.text.trim().isNotEmpty) {
                              ref
                                  .read(groupTasksControllerProvider(
                                          widget.groupId)
                                      .notifier)
                                  .createSubtask(task.id, c.text.trim());
                              c.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: MEMBERS
  // ---------------------------------------------------------------------------

  Widget _buildMembersTab(
    Group group,
    AsyncValue<List<GroupMemberResponse>> membersAsync,
    int? currentUserId,
    GroupPermissionPolicy policy,
  ) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: policy.canInviteMembers
          ? Padding(
              padding: EdgeInsets.only(
                bottom: 60 + MediaQuery.paddingOf(context).bottom,
              ),
              child: FloatingActionButton.extended(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('INVITE MEMBER'),
                onPressed: () {
                  final count =
                      membersAsync.valueOrNull?.length ?? group.memberCount;
                  InviteMemberDialog.show(
                    context,
                    groupId: group.id,
                    currentMemberCount: count,
                  );
                },
              ),
            )
          : null,
      body: membersAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: p.accent)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 36, color: p.warning),
              const SizedBox(height: 8),
              Text(ApiException.from(e).message,
                  style: TextStyle(color: p.warning)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref
                    .read(groupMembersControllerProvider(widget.groupId).notifier)
                    .refresh(),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
        data: (members) {
          final memberCount = members.length;
          final isMaxReached = memberCount >= 3;

          return RefreshIndicator(
            color: p.accent,
            onRefresh: () => ref
                .read(groupMembersControllerProvider(widget.groupId).notifier)
                .refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 140 + MediaQuery.paddingOf(context).bottom),
              children: [
                // Capacity banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMaxReached
                        ? p.warningBg
                        : p.surface1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMaxReached ? p.warningBorder : p.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isMaxReached
                            ? Icons.warning_amber_rounded
                            : Icons.people_outline,
                        color: isMaxReached ? p.warning : p.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isMaxReached
                              ? 'Project is at maximum limit of 3 members.'
                              : '$memberCount of 3 member slots used.',
                          style: t.bodySmall?.copyWith(
                            color: isMaxReached ? p.warning : p.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('MEMBERS (${members.length})',
                    style: t.labelSmall?.copyWith(color: p.textMuted)),
                const SizedBox(height: 8),
                ...members.map((m) {
                  final isThisMemberOwner = m.role == Role.owner;
                  final isMe = m.userId == currentUserId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppDecor.card(p),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: p.surface3,
                        radius: 20,
                        child: Text(
                          m.initials,
                          style: t.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: p.accent,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.displayName,
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isMe)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: p.surface3,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'YOU',
                                style: t.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: p.textMuted,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isThisMemberOwner
                                  ? p.accent.withValues(alpha: 0.15)
                                  : p.surface3,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              m.role.name.toUpperCase(),
                              style: t.labelSmall?.copyWith(
                                color: isThisMemberOwner
                                    ? p.accent
                                    : p.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.email != null) Text(m.email!, style: t.bodySmall),
                          if (m.joinedAt != null)
                            Text(
                              'Joined ${DateFormat('MMM d, y').format(m.joinedAt!)}',
                              style: t.bodySmall?.copyWith(
                                color: p.textMuted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      trailing: policy.canRemoveMember(m)
                          ? IconButton(
                              icon: Icon(Icons.person_remove_outlined,
                                  color: p.warning, size: 20),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Remove Member?'),
                                    content: Text(
                                      'Are you sure you want to remove ${m.displayName} from this project?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('CANCEL'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: p.warning,
                                        ),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          ref
                                              .read(
                                                  groupMembersControllerProvider(
                                                          widget.groupId)
                                                      .notifier)
                                              .removeMember(m.userId);
                                        },
                                        child: const Text('REMOVE'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: AI ASSISTANT (Phase 4 Human-in-the-Loop)
  // ---------------------------------------------------------------------------

  Widget _buildAIAssistantTab(Group group) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final aiState = ref.watch(aiControllerProvider);

    return Column(
      children: [
        // AI Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: p.surface1.withValues(alpha: 0.6),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: p.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Powered by LangGraph · Autonomous Assistant for ${group.name}',
                  style: t.labelSmall?.copyWith(color: p.accent),
                ),
              ),
              if (aiState.threadId != null)
                Text(
                  'Thread: ${aiState.threadId!.substring(0, aiState.threadId!.length > 8 ? 8 : aiState.threadId!.length)}',
                  style: t.labelSmall?.copyWith(color: p.textMuted),
                ),
            ],
          ),
        ),
        // Chat Messages List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: aiState.messages.length,
            itemBuilder: (ctx, idx) {
              final msg = aiState.messages[idx];
              return _buildChatMessageItem(msg);
            },
          ),
        ),
        // HITL Pending Approval Card (Human-in-the-Loop decision required)
        if (aiState.pendingApproval != null) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(p.cardRadius),
              border: Border.all(color: p.accent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: p.accentGlow.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.gavel, color: p.accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'APPROVAL REQUIRED',
                      style: t.labelLarge?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Action: ${aiState.pendingApproval!.action}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (aiState.pendingApproval!.details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surface3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      aiState.pendingApproval!.details.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                      style: t.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.warning,
                        side: BorderSide(color: p.warning),
                      ),
                      onPressed: aiState.isLoading
                          ? null
                          : () {
                              ref
                                  .read(aiControllerProvider.notifier)
                                  .submitApproval(accept: false);
                            },
                      child: const Text('REJECT'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: aiState.isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(aiControllerProvider.notifier)
                                  .submitApproval(accept: true);
                              // Refresh project tasks after action approved
                              ref
                                  .read(groupTasksControllerProvider(
                                          widget.groupId)
                                      .notifier)
                                  .refresh();
                            },
                      child: const Text('APPROVE & EXECUTE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Input bar (elevated upward above the glass nav bar with safe area support)
        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + 60 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: p.surface1,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  enabled: !aiState.isLoading,
                  style: t.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Ask AI or request a project action...',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: p.border),
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      ref
                          .read(aiControllerProvider.notifier)
                          .sendMessage(val.trim());
                      _chatInputController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: aiState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.arrow_upward),
                onPressed: aiState.isLoading
                    ? null
                    : () {
                        if (_chatInputController.text.trim().isNotEmpty) {
                          ref.read(aiControllerProvider.notifier).sendMessage(
                              _chatInputController.text.trim());
                          _chatInputController.clear();
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessageItem(ChatMessage msg) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              backgroundColor: p.accent.withValues(alpha: 0.2),
              radius: 16,
              child: Icon(Icons.auto_awesome, color: p.accent, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser ? p.accent : p.surface2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: msg.isUser ? p.accent : p.border,
                ),
              ),
              child: Text(
                msg.text,
                style: t.bodyMedium?.copyWith(
                  color: msg.isUser ? p.onAccent : p.textPrimary,
                ),
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 24),
        ],
      ),
    );
  }
}
