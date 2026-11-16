import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import 'groups_controller.dart';

class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({
    super.key,
    required this.groupId,
    required this.currentMemberCount,
  });

  final int groupId;
  final int currentMemberCount;

  static Future<bool?> show(
    BuildContext context, {
    required int groupId,
    required int currentMemberCount,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => InviteMemberDialog(
        groupId: groupId,
        currentMemberCount: currentMemberCount,
      ),
    );
  }

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // Prevent duplicate submissions
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final cleanEmail = _emailController.text.trim().toLowerCase();
    try {
      final res = await ref
          .read(groupMembersControllerProvider(widget.groupId).notifier)
          .invite(cleanEmail);

      if (mounted) {
        setState(() {
          _loading = false;
          _success = res.isResend
              ? 'Invitation re-sent! An email with the join link was dispatched to $cleanEmail.'
              : 'Invitation sent! An email with the join link was dispatched to $cleanEmail.';
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final apiErr = ApiException.from(e);
        String message = apiErr.message;
        final rawLower = message.toLowerCase();
        if (apiErr.isConnectionTimeout) {
          message =
              'Connection timed out. The server took too long to connect (it may be waking up). Please retry in a few moments.';
        } else if (apiErr.isReceiveTimeout) {
          message =
              'The server took too long to respond. The invitation status is unknown. Please check your project members list before retrying.';
        } else if (rawLower.contains('email delivery failed') ||
            rawLower.contains('failed to send invitation')) {
          message =
              'Could not dispatch the invitation email (SMTP error). Please check your email configuration on the server or try again later.';
        } else if (rawLower.contains('does not exist') ||
            rawLower.contains("dosen't exist") ||
            rawLower.contains('user does not exists')) {
          message =
              'No registered account found with this email. MultiDo requires collaborators to create an account before being invited to a project.';
        } else if (rawLower.contains('not validate') ||
            rawLower.contains('nnot loggined') ||
            rawLower.contains('not authorized')) {
          message = 'Only the project owner has permission to invite members.';
        } else if (rawLower.contains('cannot invite yourself')) {
          message = 'You cannot invite yourself to your own project.';
        } else if (rawLower.contains('already sent')) {
          message = 'An invitation has already been sent to this email address.';
        } else if (rawLower.contains('already exists in the group')) {
          message = 'This user is already a member of this project.';
        } else if (rawLower.contains('only group of 3') ||
            rawLower.contains('limit of 3')) {
          message = 'This project has reached the maximum limit of 3 members.';
        } else if (apiErr.statusCode == 403) {
          message =
              'Permission denied: only the project owner can invite registered members.';
        } else if (apiErr.statusCode == 500 &&
            rawLower.contains('failed to send invitation')) {
          message =
              'The server could not deliver the email: SMTP network connection issue. Please check server email settings.';
        }
        setState(() {
          _loading = false;
          _error = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final isFull = widget.currentMemberCount >= 3;

    return Dialog(
      backgroundColor: p.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(p.cardRadius),
        side: BorderSide(color: p.border),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add_alt_1_outlined,
                        color: p.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Invite Collaborator',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: p.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Member count indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFull
                      ? p.warningBg
                      : p.surface3.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: isFull ? p.warningBorder : p.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFull ? Icons.warning_amber_rounded : Icons.info_outline,
                      size: 16,
                      color: isFull ? p.warning : p.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFull
                            ? 'Maximum limit of 3 members reached.'
                            : 'Project capacity: ${widget.currentMemberCount} / 3 members',
                        style: t.bodySmall?.copyWith(
                          color: isFull ? p.warning : p.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.warningBg,
                    border: Border.all(color: p.warningBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: p.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: t.bodySmall?.copyWith(color: p.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_success != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.15),
                    border: Border.all(color: p.accent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: p.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _success!,
                          style: t.bodySmall?.copyWith(color: p.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text('INVITEE EMAIL',
                  style: t.labelSmall?.copyWith(color: p.textMuted)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                enabled: !isFull && !_loading,
                autofocus: !isFull,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                style: t.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'user@example.com',
                  helperText:
                      'Note: The user must already have a registered account.',
                  helperStyle: t.bodySmall?.copyWith(color: p.textMuted),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: (isFull || _loading) ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('SEND INVITATION'),
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
