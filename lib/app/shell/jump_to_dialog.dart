import 'package:flutter/material.dart';

import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../../l10n/l10n.dart';

/// "Jump to…": filter the workspace's collections by name and open one.
/// Resolves to the picked collection's id, or null when dismissed.
///
/// [collections] is shown in the given order (pinned first is the caller's
/// call); Enter opens the first match.
Future<String?> showJumpToDialog(
  BuildContext context,
  List<Collection> collections,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _JumpToDialog(collections: collections),
  );
}

class _JumpToDialog extends StatefulWidget {
  const _JumpToDialog({required this.collections});

  final List<Collection> collections;

  @override
  State<_JumpToDialog> createState() => _JumpToDialogState();
}

class _JumpToDialogState extends State<_JumpToDialog> {
  String _query = '';

  List<Collection> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.collections;
    return [
      for (final c in widget.collections)
        if (c.name.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matches = _matches;
    return Dialog(
      alignment: const Alignment(0, -0.5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.shellJumpHint,
                  prefixIcon: const Icon(MorkvaIcons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (_) {
                  if (matches.isNotEmpty) {
                    Navigator.of(context).pop(matches.first.id);
                  }
                },
              ),
              const SizedBox(height: Spacing.xs),
              Flexible(
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Text(
                          context.l10n.shellJumpNoMatch(_query.trim()),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final c in matches)
                            ListTile(
                              shape: const RoundedRectangleBorder(
                                borderRadius: Radii.mdAll,
                              ),
                              leading: CollectionGlyph(
                                iconKey: c.icon,
                                tintSeed: c.id,
                                size: 32,
                                iconSize: 18,
                              ),
                              title: Text(c.name),
                              onTap: () => Navigator.of(context).pop(c.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
