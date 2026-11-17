import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/theme/app_palette.dart';
import 'package:obsidian_todo/core/theme/app_theme.dart';
import 'package:obsidian_todo/features/tasks/presentation/widgets/floating_ai_button.dart';

void main() {
  testWidgets('FloatingAIAssistantButton renders and displays auto_awesome icon',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(AppThemeVariant.obsidianPulse),
          home: const Scaffold(
            body: Center(
              child: FloatingAIAssistantButton(visible: true),
            ),
          ),
        ),
      ),
    );

    // Pump a single frame for the infinite pulse animation
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FloatingAIAssistantButton), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });
}
