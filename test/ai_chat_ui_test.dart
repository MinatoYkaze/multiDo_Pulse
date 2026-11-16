import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';
import 'package:obsidian_todo/features/ai/presentation/widgets/hitl_approval_card.dart';
import 'package:obsidian_todo/features/ai/presentation/widgets/markdown_message_view.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.build(AppThemeVariant.obsidianPulse),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('MarkdownMessageView', () {
    testWidgets('Renders headings, bold text, bullet points, and code blocks',
        (tester) async {
      const markdown = '''
# Task Plan
Here is your plan:
- Review PR #42
- Deploy release
```dart
void main() => runApp(App());
```
Status is **URGENT** and needs attention.
''';

      await tester.pumpWidget(wrapWidget(const MarkdownMessageView(text: markdown)));
      await tester.pump();

      expect(find.byType(MarkdownMessageView), findsOneWidget);
      expect(find.textContaining('Task Plan'), findsOneWidget);
      expect(find.textContaining('Review PR #42'), findsOneWidget);
      expect(find.textContaining('void main() => runApp(App());'), findsOneWidget);
    });
  });

  group('HITLApprovalCard', () {
    testWidgets('Renders action, parameters, and fires approval decisions',
        (tester) async {
      const approval = AIApproval(
        action: 'delete_group_task',
        details: {'task_id': 123, 'title': 'Legacy Cleanup'},
        message: 'Are you sure you want to delete this task?',
      );

      bool approved = false;
      bool rejected = false;

      await tester.pumpWidget(wrapWidget(
        HITLApprovalCard(
          approval: approval,
          isLoading: false,
          onApprove: () => approved = true,
          onReject: () => rejected = true,
        ),
      ));
      await tester.pump();

      expect(find.byType(HITLApprovalCard), findsOneWidget);
      expect(find.text('APPROVAL REQUIRED (HITL)'), findsOneWidget);
      expect(find.text('Delete Group Task'), findsOneWidget);
      expect(find.textContaining('Legacy Cleanup'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
      expect(find.text('APPROVE & EXECUTE'), findsOneWidget);

      // Tap Approve
      await tester.tap(find.text('APPROVE & EXECUTE'));
      await tester.pump();
      expect(approved, true);

      // Tap Reject
      await tester.tap(find.text('REJECT'));
      await tester.pump();
      expect(rejected, true);
    });
  });
}
