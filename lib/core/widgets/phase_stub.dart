import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'app_header.dart';

/// Temporary body for tabs built in later phases (keeps navigation testable).
class PhaseStub extends StatelessWidget {
  const PhaseStub(
      {super.key,
      required this.title,
      required this.icon,
      required this.phase});
  final String title;
  final IconData icon;
  final int phase;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(title: title),
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: AppDecor.card(p),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 36, color: p.accent),
                  const SizedBox(height: 12),
                  Text('$title ships in Phase $phase', style: t.titleMedium),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 96),
        ]),
      ),
    );
  }
}
