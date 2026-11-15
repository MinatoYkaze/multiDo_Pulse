import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';

typedef GroupDraft = ({String name, String? description});

/// Create / rename workspace sheet.
class GroupEditorSheet extends StatefulWidget {
  const GroupEditorSheet({super.key, this.group});
  final Group? group;

  static Future<GroupDraft?> show(BuildContext context, {Group? group}) =>
      showModalBottomSheet<GroupDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => GroupEditorSheet(group: group),
      );

  @override
  State<GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends State<GroupEditorSheet> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _desc = TextEditingController(text: widget.group?.description ?? '');
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final d = _desc.text.trim();
    Navigator.of(context).pop((name: n, description: d.isEmpty ? null : d));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final editing = widget.group != null;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: AppDecor.sheet(p),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: p.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text(editing ? 'Edit workspace' : 'New workspace', style: t.titleMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: p.isTerminal ? '> workspace name' : 'Workspace name',
                  errorText: _showError && _name.text.trim().isEmpty
                      ? 'Give it a name.'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _desc,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Description (optional)'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _save,
                    child: Text(editing ? 'SAVE CHANGES' : 'CREATE WORKSPACE')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
