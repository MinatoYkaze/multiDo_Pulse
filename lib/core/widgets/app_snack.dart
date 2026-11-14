import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Themed floating snackbar. [bottom] clears the glass nav bar on tab screens.
void showAppSnack(BuildContext context, String message,
    {bool error = false, double bottom = 88}) {
  final p = context.palette;
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
    backgroundColor: p.surface3,
    duration: const Duration(seconds: 3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(p.controlRadius),
      side: BorderSide(
          color: error ? p.warning.withValues(alpha: 0.6) : p.border),
    ),
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          size: 18, color: error ? p.warning : p.accent),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
  ));
}
