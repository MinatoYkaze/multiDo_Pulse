import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

/// Floating "Add a new task..." dock. Border + glow turn accent on focus
/// (`focus-within:` styles in today_tasks_2); the + button fills when there
/// is text to submit.
class QuickAddDock extends StatefulWidget {
  const QuickAddDock({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSubmit,
    required this.onExpand,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSubmit;

  /// Opens the full editor pre-filled with the typed title.
  final VoidCallback onExpand;

  @override
  State<QuickAddDock> createState() => _QuickAddDockState();
}

class _QuickAddDockState extends State<QuickAddDock> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(p.isTerminal ? 4 : 16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: p.usesGlass
            ? Color.alphaBlend(
                _focused ? const Color(0x0D39FF94) : Colors.transparent,
                const Color(0xE6191C20))
            : p.surface2,
        borderRadius: radius,
        border: Border.all(
            color: _focused
                ? p.accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: p.usesGlass ? 0.08 : 0.0),
            width: 1),
        boxShadow: [
          BoxShadow(
              color: _focused ? p.accentGlow : const Color(0x66000000),
              blurRadius: 24,
              offset: _focused ? Offset.zero : const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: !widget.busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onSubmit(),
            style: t.bodyLarge?.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Add a new task...',
              hintStyle: t.bodyLarge
                  ?.copyWith(fontSize: 15, color: p.textMuted),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (_, v, __) {
            final has = v.text.trim().isNotEmpty;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              _DockButton(
                icon: Icons.tune_rounded,
                active: false,
                onTap: widget.busy ? null : widget.onExpand,
              ),
              const SizedBox(width: 6),
              _DockButton(
                icon: Icons.add_rounded,
                active: has,
                busy: widget.busy,
                onTap: widget.busy ? null : widget.onSubmit,
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton(
      {required this.icon, required this.active, this.busy = false, this.onTap});
  final IconData icon;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: const Cubic(0.34, 1.56, 0.64, 1),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? p.accent : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(p.isTerminal ? 4 : 17),
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: p.onAccent))
              : Icon(icon,
                  size: 18, color: active ? p.onAccent : p.textPrimary),
        ),
      ),
    );
  }
}
