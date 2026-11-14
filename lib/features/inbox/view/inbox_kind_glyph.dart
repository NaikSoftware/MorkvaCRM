import 'package:flutter/material.dart';

import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';

/// A note's leading mark: a sand-tinted 24 px tile with a sticky-note glyph.
class InboxNoteGlyph extends StatelessWidget {
  const InboxNoteGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).brightness == Brightness.light
        ? CollectionTints.light[4]
        : CollectionTints.dark[4];
    return Semantics(
      label: 'Note',
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: tint.background,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.sticky_note_2_outlined,
          size: 15,
          color: tint.foreground,
        ),
      ),
    );
  }
}

/// A task's round checkbox mark (20 px, 2 px ring; filled with a check
/// when [done]).
class InboxTaskCircle extends StatelessWidget {
  const InboxTaskCircle({super.key, this.done = false});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MotionDurations.base,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: done ? scheme.primary : scheme.onSurfaceVariant,
          width: 2,
        ),
      ),
      child: done ? Icon(Icons.check, size: 14, color: scheme.onPrimary) : null,
    );
  }
}

/// The kind's mark: [InboxTaskCircle] or [InboxNoteGlyph].
class InboxKindGlyph extends StatelessWidget {
  const InboxKindGlyph({super.key, required this.kind});

  final InboxKind kind;

  @override
  Widget build(BuildContext context) => switch (kind) {
    InboxKind.task => const InboxTaskCircle(),
    InboxKind.note => const InboxNoteGlyph(),
  };
}
