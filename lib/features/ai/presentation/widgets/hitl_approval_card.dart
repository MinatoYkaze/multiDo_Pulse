import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_palette.dart';

class HITLApprovalCard extends StatelessWidget {
  const HITLApprovalCard({
    super.key,
    required this.approval,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  final AIApproval approval;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(p.cardRadius),
        border: Border.all(color: p.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: p.accentGlow.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.gavel_rounded, color: p.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APPROVAL REQUIRED (HITL)',
                      style: t.labelSmall?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _formatActionTitle(approval.action),
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (approval.message != null && approval.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              approval.message!,
              style: t.bodyMedium?.copyWith(color: p.textMuted),
            ),
          ],
          if (approval.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in approval.details.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.key}: ',
                            style: t.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.textMuted,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${entry.value}',
                              style: t.bodySmall?.copyWith(
                                color: p.textPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.warning,
                  side: BorderSide(color: p.warning),
                ),
                onPressed: isLoading ? null : onReject,
                child: const Text('REJECT'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: isLoading ? null : onApprove,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('APPROVE & EXECUTE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatActionTitle(String action) {
    switch (action) {
      case 'create_group_tasks':
        return 'Create Group Task';
      case 'delete_group_task':
        return 'Delete Group Task';
      case 'update_group_task':
        return 'Update Group Task';
      case 'create_task':
        return 'Create Personal Task';
      case 'delete_task':
        return 'Delete Personal Task';
      case 'create_group':
        return 'Create New Project';
      case 'delete_group':
        return 'Delete Project';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }
}
