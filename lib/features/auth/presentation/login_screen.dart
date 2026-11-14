import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/pulse_mark.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;
  int _secretTaps = 0;
  DateTime? _lastTapTime;

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _secretTaps = 1;
    } else {
      _secretTaps++;
    }
    _lastTapTime = now;

    if (_secretTaps >= 5) {
      _secretTaps = 0;
      ref.read(hapticsProvider).medium();
      _openTokenSheet();
    }
  }

  Future<void> _google() async {
    ref.read(hapticsProvider).medium();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      ref.read(hapticsProvider).success();
      // Router redirect takes over (to `from` deep link or /today).
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openTokenSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DebugTokenSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(children: [
        // ambient neon bloom
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          child: Container(
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                p.accent.withValues(alpha: 0.16),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                        offset: Offset(0, 24 * (1 - v)), child: child),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleLogoTap,
                        child: const PulseMark(size: 72, animate: true),
                      ),
                      const SizedBox(height: 28),
                      Text('PULSE', style: t.displaySmall),
                      const SizedBox(height: 8),
                      Text(
                        p.isTerminal
                            ? '> execute your day.'
                            : 'Focus. Finish. Repeat.',
                        style: t.bodyMedium?.copyWith(color: p.textMuted),
                      ),
                      const SizedBox(height: 48),
                      _GoogleButton(busy: _busy, onTap: _busy ? null : _google),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _error == null
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: p.warningBg,
                                  border: Border.all(color: p.warningBorder),
                                  borderRadius:
                                      BorderRadius.circular(p.controlRadius),
                                ),
                                child: Text(_error!,
                                    style: t.bodySmall
                                        ?.copyWith(color: p.warning)),
                              ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'By continuing you agree to the Terms & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall,
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _openTokenSheet,
                          child: const Text('DEV: SECRET KEY / ACCESS TOKEN'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _GoogleButton extends StatefulWidget {
  const _GoogleButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback? onTap;
  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
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
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.usesGlass ? const Color(0x0FFFFFFF) : p.surface1,
            borderRadius:
                BorderRadius.circular(p.usesGlass ? 999 : p.controlRadius),
            border: Border.all(color: widget.busy ? p.accent : p.border),
            boxShadow: widget.busy
                ? [BoxShadow(color: p.accentGlow, blurRadius: 16)]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.busy)
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.accent))
            else
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Text('G',
                    style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1)),
              ),
            const SizedBox(width: 12),
            Text(widget.busy ? 'CONNECTING…' : 'CONTINUE WITH GOOGLE',
                style: t.labelLarge),
          ]),
        ),
      ),
    );
  }
}

/// Developer debug access: sign in using the developer secret key or paste a JWT.
class _DebugTokenSheet extends ConsumerStatefulWidget {
  const _DebugTokenSheet();
  @override
  ConsumerState<_DebugTokenSheet> createState() => _DebugTokenSheetState();
}

class _DebugTokenSheetState extends ConsumerState<_DebugTokenSheet> {
  late final TextEditingController _secret;
  final _access = TextEditingController();
  final _refresh = TextEditingController();
  bool _showJwtSection = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _secret = TextEditingController(text: Api.devSecretKey);
  }

  @override
  void dispose() {
    _secret.dispose();
    _access.dispose();
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _submitSecret() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithSecretKey(_secret.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitJwt() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInWithTokens(
          _access.text.trim(),
          _refresh.text.trim().isEmpty ? null : _refresh.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: AppDecor.sheet(p),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Developer Access', style: t.titleMedium),
            const SizedBox(height: 4),
            Text('Bypass sign-in with secret key or paste JWT',
                style: t.bodySmall?.copyWith(color: p.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: _secret,
              decoration: const InputDecoration(
                labelText: 'Developer Secret Key',
                hintText: 'Enter secret key',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submitSecret,
                child: Text(_busy ? 'AUTHENTICATING…' : 'SIGN IN WITH SECRET KEY'),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _showJwtSection = !_showJwtSection),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showJwtSection ? 'Hide JWT token fields' : 'Or use manual JWT tokens',
                    style: t.labelSmall?.copyWith(color: p.accent),
                  ),
                  Icon(
                    _showJwtSection ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 18,
                    color: p.accent,
                  ),
                ],
              ),
            ),
            if (_showJwtSection) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _access,
                decoration: const InputDecoration(hintText: 'Access token'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _refresh,
                decoration:
                    const InputDecoration(hintText: 'Refresh token (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _submitJwt,
                  child: const Text('SIGN IN WITH JWT'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: t.bodySmall?.copyWith(color: p.warning)),
            ],
          ]),
        ),
      ),
    );
  }
}
