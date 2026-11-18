import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    // Fresh GET /auth/me every time Settings opens.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(authControllerProvider.notifier).refreshProfile());
  }

  Future<void> _confirmLogout() async {
    ref.read(hapticsProvider).medium();
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => const _LogoutDialog(),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
    // Router redirect → /login. Nothing else to do.
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final prefs = ref.watch(prefsProvider);
    final ctl = ref.read(prefsProvider.notifier);
    final haptics = ref.read(hapticsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── header ─────────────────────────────────────────────
            Row(children: [
              _IconSquare(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/today'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Settings', style: t.titleMedium),
                  Text('SYSTEM PREFERENCES',
                      style: t.labelSmall?.copyWith(color: p.textMuted)),
                ]),
              ),
              TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/today'),
                child: const Text('DONE'),
              ),
            ]),
            const SizedBox(height: 16),

            // ── profile (GET /auth/me) ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppDecor.card(p),
              child: Row(children: [
                Hero(tag: 'avatar', child: UserAvatar(user: user, size: 56)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.displayName ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.verified_user_outlined, size: 14, color: p.accent),
                      const SizedBox(width: 6),
                      Text('Signed in with Google',
                          style: t.labelSmall?.copyWith(color: p.accent)),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── appearance ─────────────────────────────────────────
            const _SectionLabel('Appearance', trailing: 'THEME'),
            _Group(children: [
              _SwitchRow(
                icon: prefs.isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                title: 'Dark Mode',
                subtitle: prefs.isDarkMode
                    ? (prefs.variant == AppThemeVariant.obsidianApplePrecision
                        ? 'Pure OLED pitch black (#000000)'
                        : 'Technical dark terminal (#0D150E)')
                    : 'Clean light appearance',
                value: prefs.isDarkMode,
                onChanged: (v) {
                  haptics.selection();
                  ctl.setDarkMode(v);
                },
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final v in AppThemeVariant.values) ...[
                Expanded(
                  child: _ThemeOption(
                    variant: v,
                    isDark: prefs.isDarkMode,
                    selected: prefs.variant == v,
                    onTap: () {
                      haptics.selection();
                      ctl.setVariant(v);
                    },
                  ),
                ),
                if (v != AppThemeVariant.values.last) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 24),

            // ── focus engine ───────────────────────────────────────
            const _SectionLabel('Focus & Timer Engine', trailing: 'POMODORO'),
            _Group(children: [
              _SegmentRow(
                icon: Icons.timer_outlined,
                label: 'Work Interval',
                options: const [25, 45, 60],
                value: prefs.workMinutes,
                color: p.accent,
                onChanged: (v) {
                  haptics.selection();
                  ctl.setWorkMinutes(v);
                },
              ),
              _SegmentRow(
                icon: Icons.coffee_outlined,
                label: 'Rest Interval',
                options: const [5, 10, 15],
                value: prefs.breakMinutes,
                color: p.isTerminal ? p.accent : const Color(0xFF88D89E),
                onChanged: (v) {
                  haptics.selection();
                  ctl.setBreakMinutes(v);
                },
              ),
              _SwitchRow(
                icon: Icons.autorenew_rounded,
                title: 'Auto-start Breaks',
                subtitle: 'Seamless cycle transition',
                value: prefs.autoStartBreaks,
                onChanged: (v) {
                  haptics.light();
                  ctl.setAutoStartBreaks(v);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // ── experience & haptics ───────────────────────────────
            const _SectionLabel('Experience & Haptics', trailing: 'TACTILE'),
            _Group(children: [
              _SwitchRow(
                icon: Icons.vibration_rounded,
                title: 'Tactile Taptic Engine',
                subtitle: 'Mechanical clicks on completion',
                value: prefs.hapticsEnabled,
                onChanged: (v) {
                  ctl.setHaptics(v);
                  if (v) {
                    // Confirm the engine is on (bypasses the gate on purpose).
                    ref.read(hapticsProvider).medium();
                  }
                },
              ),
              _SwitchRow(
                icon: Icons.volume_up_rounded,
                title: 'Audio Reactive FX',
                subtitle: 'High-pitch completion chime',
                value: prefs.audioFx,
                onChanged: (v) {
                  haptics.light();
                  ctl.setAudioFx(v);
                  if (v) {
                    ref.read(audioFxProvider).playChime();
                  }
                },
              ),
            ]),
            const SizedBox(height: 28),

            // ── logout (POST /auth/Logout) ─────────────────────────
            _DestructiveButton(
              label: _loggingOut ? 'SIGNING OUT…' : 'LOG OUT',
              icon: Icons.logout_rounded,
              onTap: _loggingOut ? null : _confirmLogout,
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(children: [
                Icon(Icons.terminal_rounded, size: 16, color: p.textMuted),
                const SizedBox(height: 4),
                Text('Pulse build 1.0.0', style: t.bodySmall),
                Text(Api.baseUrl, style: t.bodySmall),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── building blocks ─────────────────────────

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.onTap});
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
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});
  final String text;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(text.toUpperCase(),
            style: t.labelSmall?.copyWith(color: p.textMuted, letterSpacing: 1.4)),
        if (trailing != null)
          Text(trailing!, style: t.labelSmall?.copyWith(color: p.accent)),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: AppDecor.card(p),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(p.cardRadius),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: p.border.withValues(alpha: 0.7)),
          ],
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: value ? p.accent : p.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.bodyMedium),
              Text(subtitle, style: t.bodySmall),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow(
      {required this.icon,
      required this.label,
      required this.options,
      required this.value,
      required this.color,
      required this.onChanged});
  final IconData icon;
  final String label;
  final List<int> options;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: t.bodyMedium)),
          Text('$value min', style: t.labelMedium?.copyWith(color: color)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 14),
          ),
          child: Row(children: [
            for (final o in options)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o == value ? p.surface3 : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(p.isTerminal ? 2 : 10),
                      border: Border.all(
                          color: o == value
                              ? color.withValues(alpha: 0.4)
                              : Colors.transparent),
                    ),
                    child: Text('${o}m',
                        style: t.labelMedium?.copyWith(
                            color: o == value ? color : p.textMuted,
                            fontWeight:
                                o == value ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption(
      {required this.variant,
      this.isDark = true,
      required this.selected,
      required this.onTap});
  final AppThemeVariant variant;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.palette;
    final v = AppPalette.of(variant, isDark: isDark); // preview uses *that* theme's tokens
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: current.surface1,
          borderRadius: BorderRadius.circular(current.cardRadius.clamp(4, 20)),
          border: Border.all(
              color: selected ? current.accent : current.border,
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(color: current.accentGlow, blurRadius: 18)]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // mini preview
          Container(
            height: 64,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: v.base,
              borderRadius: BorderRadius.circular(v.cardRadius.clamp(4, 14)),
              border: Border.all(color: v.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: v.surface1,
                  borderRadius: BorderRadius.circular(v.checkboxIsCircle ? 7 : 2),
                  border: Border.all(color: v.border),
                ),
                child: Row(children: [
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: v.accent,
                        shape: v.checkboxIsCircle
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                        borderRadius:
                            v.checkboxIsCircle ? null : BorderRadius.circular(1)),
                  ),
                ]),
              ),
              const Spacer(),
              Container(
                  height: 5,
                  width: 34,
                  decoration: BoxDecoration(
                      color: v.accent,
                      borderRadius: BorderRadius.circular(3))),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(variant.label,
                  maxLines: 2,
                  style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Icon(Icons.check_circle_rounded,
                      key: const ValueKey('on'), size: 16, color: current.accent)
                  : const SizedBox(key: ValueKey('off'), width: 16),
            ),
          ]),
          const SizedBox(height: 2),
          Text(variant.subtitle, style: t.bodySmall),
        ]),
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: p.warningBg,
          borderRadius:
              BorderRadius.circular(p.usesGlass ? 999 : p.controlRadius),
          border: Border.all(color: p.warningBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: p.warning),
          const SizedBox(width: 8),
          Text(label,
              style: t.labelLarge?.copyWith(
                  color: p.warning, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Confirmation modal in the style of `projects_lists_with_delete_confirmation_modal`.
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 390),
        decoration: BoxDecoration(
          color: p.surface2.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(p.usesGlass ? 28 : 8),
          border: Border.all(color: p.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0xA6000000), blurRadius: 54, offset: Offset(0, 24))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: p.warningBg,
              borderRadius: BorderRadius.circular(p.usesGlass ? 16 : 4),
              border: Border.all(color: p.warningBorder.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.logout_rounded, color: p.warning),
          ),
          const SizedBox(height: 12),
          Text('Log out?', style: t.titleMedium),
          const SizedBox(height: 6),
          Text('You will need to sign in with Google again to access your tasks.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: p.warning,
                    foregroundColor:
                        p.usesGlass ? Colors.white : const Color(0xFF3C2F00)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('LOG OUT'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
