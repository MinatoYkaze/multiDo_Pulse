import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

/// Lightweight, theme-aware Markdown renderer for AI assistant responses.
/// Supports:
/// - Headings (#, ##, ###)
/// - Bold (**text** or __text__)
/// - Italics (*text* or _text_)
/// - Inline code (`code`)
/// - Code blocks (```code```)
/// - Numbered lists (1. Item)
/// - Bulleted lists (- Item or * Item)
/// - Task highlights (Priority badges, Due dates)
class MarkdownMessageView extends StatelessWidget {
  const MarkdownMessageView({
    super.key,
    required this.text,
    this.isUser = false,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    if (isUser) {
      return Text(
        text,
        style: t.bodyMedium?.copyWith(
          color: p.onAccent,
          height: 1.45,
        ),
      );
    }

    final blocks = _parseBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          _buildBlock(context, blocks[i]),
          if (i < blocks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, _MdBlock block) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    switch (block.type) {
      case _BlockType.codeBlock:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.surface3.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border.withValues(alpha: 0.5)),
          ),
          child: SelectableText(
            block.content,
            style: t.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: p.accent,
              height: 1.4,
            ),
          ),
        );

      case _BlockType.heading:
        final level = block.level ?? 1;
        final style = level == 1
            ? t.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: p.textPrimary)
            : level == 2
                ? t.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: p.accent)
                : t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: p.textPrimary);

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: _renderInlineSpans(context, block.content, baseStyle: style),
        );

      case _BlockType.bulletItem:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 8),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _renderInlineSpans(context, block.content),
              ),
            ],
          ),
        );

      case _BlockType.numberedItem:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${block.number}.',
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.accent,
                  ),
                ),
              ),
              Expanded(
                child: _renderInlineSpans(context, block.content),
              ),
            ],
          ),
        );

      case _BlockType.paragraph:
        return _renderInlineSpans(context, block.content);
    }
  }

  Widget _renderInlineSpans(BuildContext context, String content, {TextStyle? baseStyle}) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final defaultStyle = baseStyle ?? t.bodyMedium?.copyWith(color: p.textPrimary, height: 1.45);

    final spans = _parseInline(content, defaultStyle, p);

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  List<InlineSpan> _parseInline(String content, TextStyle? baseStyle, AppPalette p) {
    final spans = <InlineSpan>[];
    // Regex matching bold, italics, inline code, and priority keywords
    final regex = RegExp(r'(\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`|\b(URGENT|HIGH|MEDIUM|LOW)\b)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: p.textPrimary,
          ),
        ));
      } else if (matchedText.startsWith('__') && matchedText.endsWith('__')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: p.textPrimary,
          ),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: p.surface3,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: p.border.withValues(alpha: 0.5)),
            ),
            child: Text(
              matchedText.substring(1, matchedText.length - 1),
              style: baseStyle?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                color: p.accent,
              ),
            ),
          ),
        ));
      } else if (matchedText == 'URGENT' || matchedText == 'HIGH' || matchedText == 'MEDIUM' || matchedText == 'LOW') {
        final color = matchedText == 'URGENT'
            ? const Color(0xFFFF3366)
            : matchedText == 'HIGH'
                ? const Color(0xFFFF8800)
                : matchedText == 'MEDIUM'
                    ? const Color(0xFF39FF94)
                    : p.textMuted;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              matchedText,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ));
      } else if ((matchedText.startsWith('*') && matchedText.endsWith('*')) ||
          (matchedText.startsWith('_') && matchedText.endsWith('_'))) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: baseStyle?.copyWith(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(text: matchedText, style: baseStyle));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  List<_MdBlock> _parseBlocks(String raw) {
    final blocks = <_MdBlock>[];
    final lines = raw.replaceAll(r'\n', '\n').split('\n');

    bool inCodeBlock = false;
    final codeBuffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          blocks.add(_MdBlock(_BlockType.codeBlock, codeBuffer.toString().trim()));
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('### ')) {
        blocks.add(_MdBlock(_BlockType.heading, trimmed.substring(4), level: 3));
      } else if (trimmed.startsWith('## ')) {
        blocks.add(_MdBlock(_BlockType.heading, trimmed.substring(3), level: 2));
      } else if (trimmed.startsWith('# ')) {
        blocks.add(_MdBlock(_BlockType.heading, trimmed.substring(2), level: 1));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(trimmed);
        if (match != null) {
          blocks.add(_MdBlock(
            _BlockType.numberedItem,
            match.group(2)!,
            number: int.tryParse(match.group(1)!),
          ));
        } else {
          blocks.add(_MdBlock(_BlockType.paragraph, trimmed));
        }
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add(_MdBlock(_BlockType.bulletItem, trimmed.substring(2)));
      } else {
        blocks.add(_MdBlock(_BlockType.paragraph, trimmed));
      }
    }

    if (inCodeBlock && codeBuffer.isNotEmpty) {
      blocks.add(_MdBlock(_BlockType.codeBlock, codeBuffer.toString().trim()));
    }

    return blocks;
  }
}

enum _BlockType { paragraph, heading, bulletItem, numberedItem, codeBlock }

class _MdBlock {
  final _BlockType type;
  final String content;
  final int? level;
  final int? number;

  const _MdBlock(this.type, this.content, {this.level, this.number});
}
