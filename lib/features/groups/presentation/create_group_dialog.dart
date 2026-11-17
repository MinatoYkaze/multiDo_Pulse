import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import 'groups_controller.dart';

class CreateGroupDialog extends ConsumerStatefulWidget {
  const CreateGroupDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );
  }

  @override
  ConsumerState<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(groupsControllerProvider.notifier).createGroup(
            _nameController.text.trim(),
            _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ApiException.from(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: p.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(p.cardRadius),
        side: BorderSide(color: p.border),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.create_new_folder_outlined,
                        color: p.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('New Project',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: p.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.warningBg,
                    border: Border.all(color: p.warningBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: p.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: t.bodySmall?.copyWith(color: p.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text('PROJECT NAME', style: t.labelSmall?.copyWith(color: p.textMuted)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: t.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'e.g. Mobile App Redesign',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a project name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('DESCRIPTION (OPTIONAL)',
                  style: t.labelSmall?.copyWith(color: p.textMuted)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                style: t.bodyMedium,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What is this project about?',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('CREATE PROJECT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
