import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/models.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../groups_providers.dart';
import 'group_task_editor_sheet.dart' show memberAsUser;

Color roleColor(BuildContext c, Role r) => switch (r) {
      Role.owner => c.palette.accent,
      Role.admin => const Color(0xFFFFD166),
      Role.member => c.palette.textMuted,
    };

String _roleLabel(Role r) => r.name.toUpperCase();

/// Members list: roles, remove (managers only), invite, leave.
/// Resolves `true` when the current user left the workspace.
class MembersSheet extends ConsumerWidget {
  const MembersSheet({super.key, required this.groupId});
  final int groupId;

  static Future<bool?> show(BuildContext context, int groupId) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => MembersSheet(groupId: groupId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(groupMembersProvider(groupId));
    final role = ref.watch(myRoleProvider(groupId));
    final myId = ref.watch(myUserIdProvider);
    final canManage = role?.canManageMembers ?? false;

    Future<void> remove(GroupMemberResponse m) async {
      final ok = await showConfirmDialog(
        context,
        title: 'Remove Member?',
        message: TextSpan(children: [
          TextSpan(
              text: m.displayName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          const TextSpan(text: ' will lose access to this workspace.'),
        ]),
        confirmLabel: 'Remove Member',
        icon: Icons.person_remove_alt_1_rounded,
        confirmIcon: Icons.person_remove_outlined,
      );
      if (!ok || !context.mounted) return;
      try {
        await ref.read(groupMembersProvider(groupId).notifier).remove(m);
        ref.read(hapticsProvider).medium();
      } catch (e) {
        if (context.mounted) {
          showAppSnack(context, ApiException.from(e).message, error: true, bottom: 24);
        }
      }
    }

    Future<void> leave() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Leave Workspace?',
        message: const TextSpan(
            text: 'You will no longer see this workspace or its tasks.'),
        confirmLabel: 'Leave Workspace',
        icon: Icons.logout_rounded,
        confirmIcon: Icons.logout_rounded,
      );
      if (!ok || !context.mounted) return;
      try {
        await ref.read(groupMembersProvider(groupId).notifier).leave();
        ref.read(hapticsProvider).heavy();
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (context.mounted) {
          showAppSnack(context, ApiException.from(e).message, error: true, bottom: 24);
        }
      }
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      decoration: AppDecor.sheet(p),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: p.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(children: [
              Expanded(
                child: Text(
                    'Team${async.valueOrNull == null ? '' : ' · ${async.valueOrNull!.length}'}',
                    style: t.titleMedium),
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => InviteSheet.show(context, groupId),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('INVITE'),
                ),
            ]),
          ),
          Flexible(
            child: async.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(ApiException.from(e).message,
                    style: t.bodyMedium?.copyWith(color: p.warning)),
              ),
              data: (members) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  for (final m in members)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: AppDecor.card(p),
                      child: Row(children: [
                        UserAvatar(user: memberAsUser(m), size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(
                                child: Text(
                                    m.userId == myId ? '${m.displayName} (you)' : m.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            if (m.email != null)
                              Text(m.email!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: roleColor(context, m.role).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(p.isTerminal ? 2 : 999),
                          ),
                          child: Text(_roleLabel(m.role),
                              style: t.labelSmall?.copyWith(
                                  color: roleColor(context, m.role),
                                  fontWeight: FontWeight.w700)),
                        ),
                        // owners can't be removed; admins can't remove other admins
                        if (canManage &&
                            m.userId != myId &&
                            m.role != Role.owner &&
                            (role == Role.owner || m.role == Role.member))
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => remove(m),
                            icon: Icon(Icons.person_remove_outlined,
                                size: 20, color: Theme.of(context).colorScheme.error),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
          if (role != null && role != Role.owner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: leave,
                  icon: Icon(Icons.logout_rounded,
                      size: 18, color: Theme.of(context).colorScheme.error),
                  label: Text('LEAVE WORKSPACE',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

/// Invite by email + role; on success shows the acceptance link to share.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.groupId});
  final int groupId;

  static Future<void> show(BuildContext context, int groupId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => InviteSheet(groupId: groupId),
      );

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _email = TextEditingController();
  Role _role = Role.member;
  bool _busy = false;
  String? _error;
  GroupInvitationResponse? _sent;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _send() async {
    if (!_valid) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final inv = await ref
          .read(groupMembersProvider(widget.groupId).notifier)
          .invite(_email.text.trim(), _role);
      ref.read(hapticsProvider).success();
      if (mounted) setState(() => _sent = inv);
    } catch (e) {
      ref.read(hapticsProvider).heavy();
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final sent = _sent;
    final link = sent?.token;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: AppDecor.sheet(p),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: sent != null
                  ? Column(
                      key: const ValueKey('sent'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 40, color: p.accent),
                        const SizedBox(height: 12),
                        Text('Invitation sent', style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text('${sent.email} · ${_roleLabel(sent.role)}',
                            style: t.bodySmall?.copyWith(color: p.textMuted)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AppDecor.card(p),
                          child: Row(children: [
                            Icon(Icons.inbox_outlined, size: 18, color: p.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sent to collaborator. They can review and accept it in their Invitations inbox.',
                                style: t.bodySmall?.copyWith(color: p.textMuted),
                              ),
                            ),
                          ]),
                        ),
                        if (link != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: AppDecor.card(p),
                            child: Row(children: [
                              Expanded(
                                child: Text(link,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmall),
                              ),
                              IconButton(
                                tooltip: 'Copy link',
                                icon: Icon(Icons.copy_rounded, size: 18, color: p.accent),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: link));
                                  ref.read(hapticsProvider).light();
                                  if (context.mounted) {
                                    showAppSnack(context, 'Invite link copied', bottom: 24);
                                  }
                                },
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                                onPressed: () => setState(() {
                                      _sent = null;
                                      _email.clear();
                                    }),
                                child: const Text('INVITE ANOTHER')),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('DONE')),
                          ),
                        ]),
                      ],
                    )
                  : Column(
                      key: const ValueKey('form'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: p.textMuted.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2))),
                        ),
                        const SizedBox(height: 14),
                        Text('Invite to workspace', style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text('They will receive a link to join.',
                            style: t.bodySmall?.copyWith(color: p.textMuted)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _email,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                              hintText: 'name@company.com', errorText: _error),
                          onChanged: (_) => _error == null ? null : setState(() => _error = null),
                          onSubmitted: (_) => _send(),
                        ),
                        const SizedBox(height: 14),
                        Text('ROLE',
                            style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.4)),
                        const SizedBox(height: 8),
                        Row(children: [
                          for (final r in [Role.member, Role.admin]) ...[
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _role = r),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _role == r ? p.accent.withValues(alpha: 0.12) : p.surface1,
                                    borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 12),
                                    border: Border.all(color: _role == r ? p.accent : p.border),
                                  ),
                                  child: Text(_roleLabel(r),
                                      style: t.labelMedium?.copyWith(
                                          color: _role == r ? p.accent : p.textMuted,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            if (r == Role.member) const SizedBox(width: 8),
                          ],
                        ]),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: _busy ? null : _send,
                              child: Text(_busy ? 'SENDING…' : 'SEND INVITATION')),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
