import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../data/invitation_repository.dart';

enum _InviteState { idle, loading, success, error }

/// Target of deep links like https://your.app/invite/<token>.
class InviteAcceptScreen extends ConsumerStatefulWidget {
  const InviteAcceptScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  _InviteState _state = _InviteState.idle;
  String _message = '';

  Future<void> _accept() async {
    setState(() => _state = _InviteState.loading);
    try {
      final res =
          await ref.read(invitationRepositoryProvider).accept(widget.token);
      ref.read(hapticsProvider).success();
      setState(() {
        _state = _InviteState.success;
        _message = res.message.isEmpty ? 'You joined the project.' : res.message;
      });
    } catch (e) {
      ref.read(hapticsProvider).heavy();
      setState(() {
        _state = _InviteState.error;
        _message = ApiException.from(e).message;
      });
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
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: AppDecor.card(p, glowing: ok),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  ok
                      ? Icons.check_circle_rounded
                      : err
                          ? Icons.error_outline_rounded
                          : Icons.mail_outline_rounded,
                  key: ValueKey(_state),
                  size: 44,
                  color: err ? p.warning : p.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                  ok
                      ? 'Invitation accepted'
                      : err
                          ? 'Could not accept'
                          : 'Project invitation',
                  style: t.titleMedium),
              const SizedBox(height: 8),
              Text(
                  _state == _InviteState.idle || _state == _InviteState.loading
                      ? 'You have been invited to collaborate on a project.'
                      : _message,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: p.textMuted)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _state == _InviteState.loading
                      ? null
                      : ok
                          ? () => context.go('/projects')
                          : _accept,
                  child: Text(_state == _InviteState.loading
                      ? 'JOINING…'
                      : ok
                          ? 'OPEN PROJECTS'
                          : err
                              ? 'TRY AGAIN'
                              : 'ACCEPT INVITATION'),
                ),
              ),
              if (!ok)
                TextButton(
                    onPressed: () => context.go('/today'),
                    child: const Text('NOT NOW')),
            ]),
          ),
        ),
      ),
    );
  }
}
