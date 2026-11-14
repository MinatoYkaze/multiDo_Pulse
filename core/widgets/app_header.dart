import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import 'pulse_mark.dart';
import 'user_avatar.dart';

/// Top bar shared by the main tabs (brand mark, title, avatar → Settings).
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, required this.title, this.subtitle, this.actions});
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        const PulseMark(size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            if (subtitle != null)
              Text(subtitle!.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: p.textMuted)),
          ]),
        ),
        ...?actions,
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            ref.read(hapticsProvider).light();
            context.push('/settings');
          },
          child: Hero(tag: 'avatar', child: UserAvatar(user: user, size: 36)),
        ),
      ]),
    );
  }
}
