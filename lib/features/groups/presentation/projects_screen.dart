import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sliding_segmented.dart';
import '../../tasks/presentation/tasks_controller.dart' show richMotionProvider;
import '../../tasks/presentation/widgets/motion_widgets.dart';
import 'groups_providers.dart';
import 'widgets/group_editor_sheet.dart';

const _icons = <IconData>[
  Icons.cloud_done_outlined,
  Icons.flag_outlined,
  Icons.rocket_launch_outlined,
  Icons.palette_outlined,
  Icons.code_rounded,
  Icons.science_outlined,
  Icons.work_outline_rounded,
  Icons.bolt_rounded,
];
IconData groupIcon(int id) => _icons[id.abs() % _icons.length];

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  void _err(Object e) => showAppSnack(context, ApiException.from(e).message, error: true);

  Future<void> _create() async {
    ref.read(hapticsProvider).medium();
    final d = await GroupEditorSheet.show(context);
    if (d == null) return;
    try {
      await ref
          .read(groupsControllerProvider.notifier)
          .create(GroupPost(name: d.name, description: d.description));
      ref.read(hapticsProvider).success();
    } catch (e) {
      if (mounted) _err(e);
    }
  }

  Future<void> _edit(Group g) async {
    final d = await GroupEditorSheet.show(context, group: g);
    if (d == null) return;
    try {
      await ref
          .read(groupsControllerProvider.notifier)
          .edit(g, UpdateGroup(name: d.name, description: d.description));
      ref.invalidate(groupDetailProvider(g.id));
    } catch (e) {
      if (mounted) _err(e);
    }
  }

  /// Confirms, then deletes; resolves true when the row should collapse away.
  Future<bool> _delete(Group g) async {
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
    if (!ok || !mounted) return false;
    ref.read(hapticsProvider).heavy();
    try {
      await ref.read(groupsControllerProvider.notifier).remove(g.id);
      return true;
    } catch (e) {
      if (mounted) _err(e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(groupsControllerProvider);
    final filter = ref.watch(groupFilterProvider);
    final pinned = ref.watch(pinnedGroupsProvider);
    final rich = ref.watch(richMotionProvider);
    final navPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(title: 'Pulse', subtitle: 'Projects'),
          Expanded(
            child: async.when(
              loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SkeletonList(count: 4, height: 96)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorRetry(
                      message: ApiException.from(e).message,
                      onRetry: () => ref.invalidate(groupsControllerProvider)),
                ),
              ),
              data: (all) {
                // filter (stats-based; groups whose tasks haven't loaded count as active)
                final shown = all.where((g) {
                  final s = ref.watch(groupStatsProvider(g.id));
                  final complete = s?.complete ?? false;
                  return switch (filter) {
                    GroupFilter.all => true,
                    GroupFilter.active => !complete,
                    GroupFilter.completed => complete,
                  };
                }).toList()
                  ..sort((a, b) {
                    final pa = pinned.contains(a.id) ? 0 : 1;
                    final pb = pinned.contains(b.id) ? 0 : 1;
                    return pa != pb ? pa.compareTo(pb) : b.id.compareTo(a.id);
                  });

                return RefreshIndicator(
                  color: p.accent,
                  backgroundColor: p.surface2,
                  onRefresh: () => ref.read(groupsControllerProvider.notifier).reload(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, navPad + 110),
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: 'Workspaces ', style: t.headlineMedium),
                            TextSpan(
                                text: '${all.length}',
                                style: t.headlineSmall?.copyWith(
                                    color: p.textMuted, fontWeight: FontWeight.w400)),
                          ])),
                        ),
                        _NewButton(onTap: _create),
                      ]),
                      const SizedBox(height: 14),
                      SlidingSegmented(
                        labels: const ['All', 'Active', 'Completed'],
                        index: filter.index,
                        onChanged: (i) {
                          ref.read(hapticsProvider).selection();
                          ref.read(groupFilterProvider.notifier).state = GroupFilter.values[i];
                        },
                      ),
                      const SizedBox(height: 14),
                      if (shown.isEmpty)
                        EmptyState(
                          icon: Icons.folder_open_rounded,
                          title: all.isEmpty
                              ? 'No workspaces yet'
                              : 'Nothing in this tab',
                          subtitle: all.isEmpty
                              ? 'Create one to collaborate on tasks with your team.'
                              : null,
                        )
                      else
                        for (var i = 0; i < shown.length; i++)
                          _GroupCard(
                            key: ValueKey('group-${shown[i].id}'),
                            group: shown[i],
                            index: i,
                            rich: rich,
                            pinned: pinned.contains(shown[i].id),
                            onOpen: () => context.push('/projects/${shown[i].id}'),
                            onPin: () {
                              ref.read(hapticsProvider).light();
                              ref.read(pinnedGroupsProvider.notifier).toggle(shown[i].id);
                            },
                            onEdit: () => _edit(shown[i]),
                            onDelete: () => _delete(shown[i]),
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _NewButton extends StatefulWidget {
  const _NewButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_NewButton> createState() => _NewButtonState();
}

class _NewButtonState extends State<_NewButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
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
            Text('New', style: t.labelLarge?.copyWith(color: p.onAccent, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────── card ─────────────────────────────

class _GroupCard extends ConsumerStatefulWidget {
  const _GroupCard({
    super.key,
    required this.group,
    required this.index,
    required this.rich,
    required this.pinned,
    required this.onOpen,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
  });
  final Group group;
  final int index;
  final bool rich, pinned;
  final VoidCallback onOpen, onPin, onEdit;
  final Future<bool> Function() onDelete;

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slide = SlidableController(this);
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    // light tick when the actions layer opens (swipe haptics)
    _slide.actionPaneType.addListener(() {
      if (_slide.actionPaneType.value != ActionPaneType.none) {
        ref.read(hapticsProvider).light();
      }
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await widget.onDelete();
    if (ok && mounted) setState(() => _removing = true);
    if (!ok) _slide.close();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final g = widget.group;
    final stats = ref.watch(groupStatsProvider(g.id));
    final tasksAsync = ref.watch(groupTasksProvider(g.id));
    final total = stats?.total ?? g.taskCount;
    final done = stats?.done ?? g.completedTaskCount;
    final progress = stats?.progress ?? g.progress;
    final complete = stats?.complete ?? false;
    final radius = BorderRadius.circular(p.isTerminal ? 4 : 20);
    final accent = complete ? p.accent : (progress > 0.5 ? p.accent : p.textPrimary.withValues(alpha: 0.4));

    final subtitleParts = <String>[
      if (g.description?.trim().isNotEmpty ?? false) g.description!.trim(),
      if (stats != null || g.taskCount > 0) '$done of $total tasks' else if (tasksAsync.isLoading) 'Loading…' else 'No tasks yet',
    ];

    final card = Slidable(
      key: ValueKey('slide-g-${g.id}'),
      controller: _slide,
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.52,
        children: [
          _Act(
            icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            tint: p.textPrimary,
            radius: radius,
            onTap: widget.onPin,
          ),
          _Act(
            icon: Icons.edit_outlined,
            tint: p.textPrimary,
            radius: radius,
            onTap: widget.onEdit,
          ),
          _Act(
            icon: Icons.delete_outline_rounded,
            tint: Theme.of(context).colorScheme.error,
            danger: true,
            radius: radius,
            onTap: _delete,
          ),
        ],
      ),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecor.card(p),
          child: Column(children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: complete ? p.accent.withValues(alpha: 0.10) : p.surface3,
                  borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
                  border: Border.all(
                      color: complete ? p.accent.withValues(alpha: 0.2) : p.border),
                ),
                child: Icon(complete ? Icons.check_circle_outline_rounded : groupIcon(g.id),
                    size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (widget.pinned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin, size: 13, color: p.accent),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitleParts.join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ]),
              ),
              const SizedBox(width: 8),
              complete
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('DONE',
                          style: t.labelSmall?.copyWith(
                              color: p.accent, fontWeight: FontWeight.w700)),
                    )
                  : Text('${(progress * 100).round()}%',
                      style: t.labelLarge?.copyWith(
                          color: progress > 0.5 ? p.accent : p.textMuted,
                          fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            ShimmerProgressBar(
              value: progress,
              color: progress > 0.5 || complete ? p.accent : p.textPrimary.withValues(alpha: 0.4),
              glow: progress > 0.5 || complete,
            ),
          ]),
        ),
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _removing
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Entrance(
                index: widget.index,
                enabled: widget.rich,
                child: ClipRRect(borderRadius: radius, child: card),
              ),
            ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.icon,
    required this.tint,
    required this.radius,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final Color tint;
  final BorderRadius radius;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return CustomSlidableAction(
      onPressed: (_) => onTap(),
      backgroundColor: p.surface2,
      padding: EdgeInsets.zero,
      autoClose: !danger,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: danger ? scheme.errorContainer : p.surface3,
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
        ),
        child: Icon(icon, size: 18, color: danger ? scheme.error : tint.withValues(alpha: 0.85)),
      ),
    );
  }
}
