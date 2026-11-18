import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/sliding_segmented.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../tasks/presentation/task_format.dart';
import '../../tasks/presentation/tasks_controller.dart' show richMotionProvider;
import 'groups_providers.dart';
import 'projects_screen.dart' show groupIcon;
import 'widgets/group_editor_sheet.dart';
import 'widgets/group_task_editor_sheet.dart';
import 'widgets/group_task_row.dart';
import 'widgets/group_task_sheet.dart';
import 'widgets/members_sheet.dart';

enum _Status { open, done, all }

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key, required this.groupId});
  final int groupId;
  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  int _mode = 0; // 0 = All Group Tasks, 1 = My Assigned Tasks
  _Status _status = _Status.open;

  int get _id => widget.groupId;
  GroupTasksController get _tasks => ref.read(groupTasksProvider(_id).notifier);

  void _err(Object e) {
    if (mounted) showAppSnack(context, ApiException.from(e).message, error: true);
  }

  Future<void> _reloadAll() async {
    await _tasks.reload();
    await ref.read(groupMembersProvider(_id).notifier).reload();
  }

  Future<void> _addTask() async {
    ref.read(hapticsProvider).medium();
    final members = ref.read(groupMembersProvider(_id)).valueOrNull ?? const [];
    final me = ref.read(myUserIdProvider);
    final d = await GroupTaskEditorSheet.show(context,
        members: members, defaultAssignee: me);
    if (d == null) return;
    try {
      await _tasks.add(d.toCreate());
      ref.read(hapticsProvider).success();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _editTask(GroupTaskResponse t) async {
    final members = ref.read(groupMembersProvider(_id)).valueOrNull ?? const [];
    final d = await GroupTaskEditorSheet.show(context, members: members, task: t);
    if (d == null) return;
    try {
      await _tasks.edit(t, d.toUpdate(null));
    } catch (e) {
      _err(e);
    }
  }

  Future<bool> _deleteTask(GroupTaskResponse t) async {
    try {
      await _tasks.remove(t);
      ref.read(hapticsProvider).medium();
      return true;
    } catch (e) {
      _err(e);
      return false;
    }
  }

  void _toggle(GroupTaskResponse t) async {
    final h = ref.read(hapticsProvider);
    if (!t.isCompleted) {
      h.success();
      ref.read(audioFxProvider).playChime();
    } else {
      h.light();
    }
    try {
      await _tasks.toggle(t);
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _editGroup(Group g) async {
    final d = await GroupEditorSheet.show(context, group: g);
    if (d == null) return;
    try {
      await ref
          .read(groupsControllerProvider.notifier)
          .edit(g, UpdateGroup(name: d.name, description: d.description));
      ref.invalidate(groupDetailProvider(_id));
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _deleteGroup(Group g) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Workspace?',
      message: TextSpan(children: [
        const TextSpan(text: 'Are you sure you want to delete '),
        TextSpan(
            text: '"${g.name}"',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        const TextSpan(text: '? All of its tasks will be lost. This cannot be undone.'),
      ]),
      confirmLabel: 'Delete Workspace',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(groupsControllerProvider.notifier).remove(g.id);
      ref.read(hapticsProvider).heavy();
      if (mounted) context.pop();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _openMembers() async {
    final left = await MembersSheet.show(context, _id);
    if (left == true && mounted) {
      ref.read(groupsControllerProvider.notifier).dropLocal(_id);
      context.pop();
    }
  }

  void _openMenu(Group g, Role? role) {
    final p = context.palette;
    final canManage = role?.canManageMembers ?? false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        Widget item(IconData i, String l, VoidCallback f, {bool danger = false}) {
          final c = danger ? Theme.of(ctx).colorScheme.error : p.textPrimary;
          return ListTile(
            leading: Icon(i, color: c),
            title: Text(l, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: c)),
            onTap: () {
              Navigator.pop(ctx);
              f();
            },
          );
        }

        return Container(
          decoration: AppDecor.sheet(p),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              item(Icons.groups_2_outlined, 'Team & members', _openMembers),
              if (canManage) ...[
                item(Icons.person_add_alt_1_rounded, 'Invite people', () => InviteSheet.show(context, _id)),
                item(Icons.edit_outlined, 'Edit workspace', () => _editGroup(g)),
              ],
              if (role == Role.owner)
                item(Icons.delete_outline_rounded, 'Delete workspace', () => _deleteGroup(g), danger: true),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final groupAsync = ref.watch(groupDetailProvider(_id));
    final allAsync = ref.watch(groupTasksProvider(_id));
    final mineAsync = ref.watch(myGroupTasksProvider(_id));
    final members = ref.watch(groupMembersProvider(_id)).valueOrNull ?? const <GroupMemberResponse>[];
    final role = ref.watch(myRoleProvider(_id));
    final rich = ref.watch(richMotionProvider);
    final stats = ref.watch(groupStatsProvider(_id));
    final navPad = MediaQuery.paddingOf(context).bottom;
    final group = groupAsync.valueOrNull;

    // data source for the chosen tab (My tab merges optimistic edits from All)
    final all = allAsync.valueOrNull;
    final allById = {for (final x in all ?? const <GroupTaskResponse>[]) x.id: x};
    List<GroupTaskResponse>? source;
    AsyncValue<Object?> sourceState;
    if (_mode == 0) {
      source = all;
      sourceState = allAsync;
    } else {
      source = mineAsync.valueOrNull
          ?.where((x) => all == null || allById.containsKey(x.id))
          .map((x) => allById[x.id] ?? x)
          .toList();
      sourceState = mineAsync;
    }

    List<GroupTaskResponse> visible = const [];
    var openCount = 0, doneCount = 0;
    if (source != null) {
      openCount = source.where((x) => !x.isCompleted).length;
      doneCount = source.length - openCount;
      int prio(Priority x) => x == Priority.high ? 0 : (x == Priority.medium ? 1 : 2);
      visible = source
          .where((x) => switch (_status) {
                _Status.open => !x.isCompleted,
                _Status.done => x.isCompleted,
                _Status.all => true,
              })
          .toList()
        ..sort((a, b) {
          if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
          final c = prio(a.priority).compareTo(prio(b.priority));
          return c != 0 ? c : b.id.compareTo(a.id);
        });
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              _RoundBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WORKSPACE',
                      style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.4)),
                  Text(group?.name ?? '…',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                ]),
              ),
              _TaskButton(onTap: _addTask),
            ]),
          ),
          Expanded(
            child: groupAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16), child: SkeletonList(count: 4, height: 90)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorRetry(
                      message: ApiException.from(e).message,
                      onRetry: () => ref.invalidate(groupDetailProvider(_id))),
                ),
              ),
              data: (g) => RefreshIndicator(
                color: p.accent,
                backgroundColor: p.surface2,
                onRefresh: _reloadAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 4, 16, navPad + 110),
                  children: [
                    _Summary(
                      group: g,
                      stats: stats,
                      members: members,
                      lastSync: ref.read(groupTasksProvider(_id).notifier).lastSync,
                      onMenu: () => _openMenu(g, role),
                      onTeam: _openMembers,
                    ),
                    const SizedBox(height: 14),
                    SlidingSegmented(
                      labels: const ['All Group Tasks', 'My Assigned Tasks'],
                      index: _mode,
                      onChanged: (i) {
                        ref.read(hapticsProvider).selection();
                        setState(() => _mode = i);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      _Chip(
                          label: 'Open ($openCount)',
                          selected: _status == _Status.open,
                          onTap: () => setState(() => _status = _Status.open)),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Done ($doneCount)',
                          selected: _status == _Status.done,
                          onTap: () => setState(() => _status = _Status.done)),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'All',
                          selected: _status == _Status.all,
                          onTap: () => setState(() => _status = _Status.all)),
                      const Spacer(),
                      Text('Swipe for actions', style: t.labelSmall?.copyWith(color: p.textMuted)),
                    ]),
                    const SizedBox(height: 12),
                    if (source == null && sourceState.isLoading)
                      const SkeletonList(count: 3, height: 90)
                    else if (source == null)
                      ErrorRetry(
                        message: ApiException.from(sourceState.error ?? 'Failed to load').message,
                        onRetry: () {
                          ref.invalidate(myGroupTasksProvider(_id));
                          _tasks.reload();
                        },
                      )
                    else if (visible.isEmpty)
                      EmptyState(
                        icon: _mode == 1 ? Icons.assignment_ind_outlined : Icons.task_alt_rounded,
                        title: _mode == 1 ? 'Nothing assigned to you' : 'No tasks here',
                        subtitle: _status == _Status.open
                            ? 'Tap + Task to add one.'
                            : null,
                      )
                    else
                      for (var i = 0; i < visible.length; i++)
                        GroupTaskRow(
                          key: ValueKey('gtask-${visible[i].id}'),
                          task: visible[i],
                          index: i,
                          rich: rich,
                          assignee: members.firstWhereOrNull((m) => m.userId == visible[i].assignedTo),
                          onToggle: () => _toggle(visible[i]),
                          onOpen: () => GroupTaskSheet.show(context,
                              groupId: _id, taskId: visible[i].id),
                          onEdit: () => _editTask(visible[i]),
                          onDelete: () => _deleteTask(visible[i]),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── summary card ─────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({
    required this.group,
    required this.stats,
    required this.members,
    required this.lastSync,
    required this.onMenu,
    required this.onTeam,
  });
  final Group group;
  final GroupStats? stats;
  final List<GroupMemberResponse> members;
  final DateTime lastSync;
  final VoidCallback onMenu, onTeam;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final s = stats;
    final shown = members.take(4).toList();
    final names = members.take(3).map((m) => m.displayName.split(' ').first).join(', ');

    return Container(
      decoration: AppDecor.card(p),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(p.cardRadius),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.surface3,
                    borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 14),
                  ),
                  child: Icon(groupIcon(group.id), size: 26, color: p.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
                    const SizedBox(height: 3),
                    Row(children: [
                      _PulseDot(color: p.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (group.description?.trim().isNotEmpty ?? false)
                              ? group.description!.trim()
                              : '${members.length} member${members.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelSmall?.copyWith(color: p.accent),
                        ),
                      ),
                    ]),
                  ]),
                ),
                _RoundBtn(icon: Icons.more_horiz_rounded, onTap: onMenu),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Text('Execution Velocity', style: t.labelMedium?.copyWith(color: p.textMuted)),
                const Spacer(),
                Text(s == null ? '—' : '${s.percent}% Resolved ',
                    style: t.labelMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
                if (s != null)
                  Text('(${s.done}/${s.total})',
                      style: t.labelMedium?.copyWith(color: p.textMuted)),
              ]),
              const SizedBox(height: 8),
              Container(
                height: 8,
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                    color: p.surface3, borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.centerLeft,
                child: LayoutBuilder(
                  builder: (_, c) => AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    width: c.maxWidth * (s?.progress ?? 0),
                    decoration: BoxDecoration(
                        color: p.accent, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Metric(value: s?.pending, label: 'Pending')),
                const SizedBox(width: 8),
                Expanded(child: _Metric(value: s?.done, label: 'Closed', color: p.accent)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Metric(
                        value: s?.critical,
                        label: 'Critical',
                        highlight: (s?.critical ?? 0) > 0)),
              ]),
            ]),
          ),
          // live team strip
          GestureDetector(
            onTap: onTeam,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: p.isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                SizedBox(
                  height: 26,
                  width: shown.isEmpty ? 26 : 26.0 + (shown.length - 1) * 18 + (members.length > 4 ? 22 : 0),
                  child: Stack(children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * 18.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: p.surface1, width: 2),
                          ),
                          child: UserAvatar(user: memberAsUser(shown[i]), size: 22),
                        ),
                      ),
                    if (members.length > 4)
                      Positioned(
                        left: 4 * 18.0,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: p.surface3,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.surface1, width: 2)),
                          child: Text('+${members.length - 4}', style: t.labelSmall),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(members.isEmpty ? 'Team' : names,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall),
                ),
                Icon(Icons.sync_rounded, size: 13, color: p.accent),
                const SizedBox(width: 4),
                Text('Live ${TaskFmt.createdLabel(lastSync).toLowerCase()}', style: t.labelSmall),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 16, color: p.textMuted),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.color, this.highlight = false});
  final int? value;
  final String label;
  final Color? color;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final warn = highlight ? p.warning : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? p.warningBg : p.surface3,
        borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 10),
      ),
      child: Column(children: [
        Text(value?.toString() ?? '–',
            style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: warn ?? color ?? p.textPrimary)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: t.labelSmall?.copyWith(color: warn ?? p.textMuted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? p.accent.withValues(alpha: 0.12)
              : (p.isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000)),
          borderRadius: BorderRadius.circular(p.pillRadius),
          border: Border.all(color: selected ? p.accent.withValues(alpha: 0.6) : Colors.transparent),
        ),
        child: Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? p.accent : p.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

class _TaskButton extends StatelessWidget {
  const _TaskButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(p.usesGlass ? 999 : 4),
          boxShadow: [BoxShadow(color: p.accentGlow, blurRadius: 14)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, size: 18, color: p.onAccent),
          const SizedBox(width: 4),
          Text('Task',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: p.onAccent, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
