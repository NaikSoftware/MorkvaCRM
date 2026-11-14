import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'automations_page.dart';

/// The read-only code viewer (UX §2): a 900 × 80% dialog on wide layouts, a
/// full-screen route on phones. [hash] is the bundle hash shown in the
/// header ("sha256:3fa2…c91").
Future<void> showCodeViewer(
  BuildContext context, {
  required String code,
  String name = 'module.js',
  String? hash,
}) {
  final viewer = CodeViewer(code: code, name: name, hash: hash);
  if (!automationsExpanded(context)) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => viewer),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(Spacing.lg),
        child: SizedBox(width: 900, height: size.height * 0.8, child: viewer),
      );
    },
  );
}

class CodeViewer extends StatelessWidget {
  const CodeViewer({
    super.key,
    required this.code,
    required this.name,
    this.hash,
  });

  final String code;
  final String name;
  final String? hash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = MorkvaTypography.mono(
      theme.textTheme.bodyMedium!,
    ).copyWith(fontSize: 13, height: 20 / 13, color: scheme.onSurface);
    final lines = const LineSplitter().convert(code);
    final gutter = '${lines.length}'.length * 8.0 + Spacing.md;
    final longest = lines.fold(0, (n, l) => math.max(n, l.length));
    final l10n = context.l10n;
    final meta = [
      kbLabel(l10n, utf8.encode(code).length),
      if (hash != null) shortHash(hash!),
    ].join(' · ');

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.xs,
        Spacing.xs,
        Spacing.xs,
      ),
      child: Row(
        children: [
          Icon(MorkvaIcons.code, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.xs),
          Text(name, style: theme.textTheme.titleMedium),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconActionButton(
            icon: MorkvaIcons.copy,
            tooltip: l10n.commonCopy,
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          ),
          IconActionButton(
            icon: MorkvaIcons.close,
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    final body = LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          // shortcut: width from the longest line at ~8 px per mono glyph;
          // measure with a TextPainter if lines overflow.
          width: math.max(box.maxWidth, gutter + longest * 8.0 + Spacing.xl),
          child: SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              itemCount: lines.length,
              itemExtent: 20,
              itemBuilder: (context, i) => Row(
                children: [
                  SizedBox(
                    width: gutter,
                    child: SelectionContainer.disabled(
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.right,
                        style: style.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Text(lines[i], style: style, softWrap: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              Spacing.md,
              0,
              Spacing.md,
              Spacing.md,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: Radii.mdAll,
            ),
            clipBehavior: Clip.antiAlias,
            child: body,
          ),
        ),
      ],
    );
    if (automationsExpanded(context)) {
      return Material(color: scheme.surface, child: content);
    }
    return Scaffold(body: SafeArea(child: content));
  }
}
