import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../data/invitation_repository.dart';
import 'groups_controller.dart';

enum _InviteState { idle, loading, success, error }

/// Review screen for group invitations received via Android deep link or Flutter Web.
/// Displays project preview information and requires explicit user acceptance.
class InviteAcceptScreen extends ConsumerStatefulWidget {
  const InviteAcceptScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  _InviteState _state = _InviteState.idle;
  String _message = '';
  InvitationPreview? _preview;
  bool _loadingPreview = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _loadingPreview = true);
    final prev =
        await ref.read(invitationRepositoryProvider).getPreview(widget.token);
    if (mounted) {
      setState(() {
        _preview = prev;
        _loadingPreview = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _state = _InviteState.loading);
    try {
      final res =
          await ref.read(invitationRepositoryProvider).accept(widget.token);
      ref.read(groupsControllerProvider.notifier).refresh();
      ref.read(hapticsProvider).success();
      ref.invalidate(groupsControllerProvider);
      if (mounted) {
        setState(() {
          _state = _InviteState.success;
          _message = res.message.isEmpty
              ? 'You joined ${_preview?.groupName ?? 'the project'}.'
              : res.message;
        });
      }
    } catch (e) {
      ref.read(hapticsProvider).heavy();
      if (mounted) {
        setState(() {
          _state = _InviteState.error;
          _message = ApiException.from(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final ok = _state == _InviteState.success;
    final err = _state == _InviteState.error;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: AppDecor.card(p, glowing: ok),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      ok
                          ? Icons.check_circle_rounded
                          : err
                              ? Icons.error_outline_rounded
                              : Icons.folder_shared_rounded,
                      key: ValueKey(_state),
                      size: 48,
                      color: err
                          ? p.warning
                          : ok
                              ? p.accent
                              : p.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ok
                        ? 'Invitation Accepted'
                        : err
                            ? 'Could Not Join Project'
                            : _preview != null
                                ? _preview!.groupName
                                : 'Project Invitation',
                    textAlign: TextAlign.center,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Project description and invitation details preview
                  if (!ok && !err) ...[
                    if (_loadingPreview)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Loading project preview…',
                          style: t.bodySmall?.copyWith(color: p.textMuted),
                        ),
                      )
                    else if (_preview != null &&
                        _preview!.groupDescription != null &&
                        _preview!.groupDescription!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(
                          _preview!.groupDescription!,
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(color: p.textPrimary),
                        ),
                      ),
                    Text(
                      _preview?.inviterEmail != null &&
                              _preview!.inviterEmail!.isNotEmpty
                          ? 'Invited by ${_preview!.inviterEmail}'
                          : 'You have been invited to collaborate on this project.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: p.textMuted),
                    ),
                  ] else ...[
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        color: err ? p.warning : p.textPrimary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _state == _InviteState.loading
                          ? null
                          : ok
                              ? () => context.go('/projects')
                              : _accept,
                      child: _state == _InviteState.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              ok
                                  ? 'OPEN PROJECTS'
                                  : err
                                      ? 'TRY AGAIN'
                                      : 'ACCEPT INVITATION',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  // Secondary Button
                  if (!ok) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/today'),
                      child: Text(
                        err ? 'BACK TO TODAY' : 'NOT NOW',
                        style: TextStyle(color: p.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
