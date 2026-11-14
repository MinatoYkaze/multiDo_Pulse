import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_palette.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 36});
  final UserPost? user;
  final double size;

  String get _initials {
    final n = user?.displayName.trim() ?? '?';
    final parts = n.split(RegExp(r'\s+'));
    final s = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'
        : n.substring(0, n.length.clamp(1, 2));
    return s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(p.isTerminal ? 4 : size * 0.34);
    final fallback = Container(
      color: p.surface3,
      alignment: Alignment.center,
      child: Text(_initials,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: p.accent,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700)),
    );
    final url = user?.picture;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          borderRadius: radius, border: Border.all(color: p.border)),
      child: ClipRRect(
        borderRadius: radius,
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, prog) =>
                    prog == null ? child : fallback),
      ),
    );
  }
}
