import 'package:flutter/material.dart';

import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';

/// The assistant's answer: plain paragraphs with `**bold**` spans and line
/// breaks — there is no markdown renderer. While streaming it repaints from
/// the item's own `live` listenable (one paragraph, not the list) and ends
/// in a carrot caret.
class AssistantText extends StatelessWidget {
  const AssistantText({super.key, required this.item});

  final AssistantTextItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scope = AssistantScope.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontSize: scope.messageSize,
      height: 1.55,
      color: scheme.onSurface,
    );
    final live = item.live;

    Widget paragraph(String text) => Text.rich(
      TextSpan(
        style: style,
        children: [
          ...boldSpans(text),
          if (item.streaming)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                key: const ValueKey('assistant-caret'),
                width: 8,
                height: 16,
                margin: const EdgeInsetsDirectional.only(start: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );

    final note = item.stopped
        ? 'Stopped'
        : item.cutShort
        ? 'Cut short — ask me to continue'
        : null;

    return Semantics(
      // Announced once, when the answer is complete — never token by token.
      liveRegion: !item.streaming,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(
            child: live == null || !item.streaming
                ? paragraph(item.currentText)
                : ValueListenableBuilder<String>(
                    valueListenable: live,
                    builder: (context, text, _) => paragraph(text),
                  ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Splits [text] on `**` into plain and bold spans. An unclosed `**` (a
/// streaming answer mid-span) bolds the rest; the markers never show.
List<TextSpan> boldSpans(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
  ];
}
