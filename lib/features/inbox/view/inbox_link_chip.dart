import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/domain.dart';
import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../views/view_link.dart';

/// The workspace collections by id, live; null until the first snapshot.
/// `DataRepository` sits above the app's navigator, so this works in root
/// dialogs and sheets too (unlike the shell's `CollectionsListCubit`).
/// [InboxLinkChip]s below it read its map instead of each opening a
/// listener of their own.
///
/// A failed listener leaves the map null (chips keep their stored label);
/// [errorBuilder], when given, replaces [builder] then, with a retry that
/// listens again.
class CollectionsWatcher extends StatefulWidget {
  const CollectionsWatcher({
    super.key,
    required this.builder,
    this.errorBuilder,
  });

  final Widget Function(BuildContext context, Map<String, Collection>? byId)
  builder;
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;

  @override
  State<CollectionsWatcher> createState() => _CollectionsWatcherState();
}

class _CollectionsWatcherState extends State<CollectionsWatcher> {
  StreamSubscription<List<Collection>>? _sub;
  Map<String, Collection>? _byId;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub = context.read<DataRepository>().watchCollections().listen(
      (list) => setState(() {
        _failed = false;
        _byId = {for (final c in list) c.id: c};
      }),
      // Unknown, not "deleted": chips keep their stored label.
      onError: (Object _) => setState(() => _failed = true),
    );
  }

  void _retry() {
    unawaited(_sub?.cancel());
    setState(() => _failed = false);
    _listen();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CollectionsScope(
    byId: _byId,
    child: Builder(
      builder: (context) => switch (widget.errorBuilder) {
        final onError? when _failed && _byId == null => onError(
          context,
          _retry,
        ),
        _ => widget.builder(context, _byId),
      },
    ),
  );
}

class _CollectionsScope extends InheritedWidget {
  const _CollectionsScope({required this.byId, required super.child});

  final Map<String, Collection>? byId;

  @override
  bool updateShouldNotify(_CollectionsScope old) => byId != old.byId;
}

/// An item's link to a card: the collection's tinted glyph and
/// "Collection · label" ([compact]: the label only, ≤ 112 px). Tapping it
/// opens the card; a card that no longer exists turns it muted with a
/// "Card deleted" snackbar, and a missing collection shows
/// "Collection deleted".
///
/// Collections come from the nearest [CollectionsWatcher]; without one the
/// chip watches them itself. [onClear] adds a ×; [onTap] replaces opening
/// the card.
class InboxLinkChip extends StatefulWidget {
  const InboxLinkChip({
    super.key,
    required this.link,
    this.compact = false,
    this.onClear,
    this.onTap,
  });

  final InboxLink link;
  final bool compact;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  @override
  State<InboxLinkChip> createState() => _InboxLinkChipState();
}

class _InboxLinkChipState extends State<InboxLinkChip> {
  /// Found missing on tap (this chip's lifetime).
  bool _cardDeleted = false;

  @override
  void didUpdateWidget(InboxLinkChip old) {
    super.didUpdateWidget(old);
    if (old.link != widget.link) _cardDeleted = false;
  }

  Future<void> _open(Collection collection) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cardDeleted = context.l10n.inboxCardDeleted;
    final link = widget.link;
    MorkvaObject? card;
    try {
      card = await context.read<DataRepository>().getObject(
        link.collectionId,
        link.cardId,
        schema: collection,
      );
    } on Object {
      // Offline or denied: let the collection page say what's wrong.
      router.go(collectionLink(link.collectionId, card: link.cardId));
      return;
    }
    if (card == null) {
      if (mounted) setState(() => _cardDeleted = true);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(cardDeleted),
          behavior: SnackBarBehavior.floating,
          persist: false,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    router.go(collectionLink(link.collectionId, card: link.cardId));
  }

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CollectionsScope>();
    if (scope != null) return _build(context, scope.byId);
    return CollectionsWatcher(builder: _build);
  }

  Widget _build(BuildContext context, Map<String, Collection>? collections) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link = widget.link;
    final collection = collections?[link.collectionId];
    final collectionDeleted = collections != null && collection == null;
    final muted = collectionDeleted || _cardDeleted;
    final l10n = context.l10n;
    final label = collectionDeleted
        ? l10n.inboxCollectionDeleted
        : widget.compact || collection == null
        ? link.label
        : '${collection.name} · ${link.label}';
    final ink = muted ? scheme.onSurfaceVariant : scheme.onSurface;

    final chip = Container(
      height: 28,
      padding: EdgeInsets.fromLTRB(
        Spacing.xxs,
        0,
        widget.onClear == null ? 10 : Spacing.xxs,
        0,
      ),
      decoration: BoxDecoration(
        color: muted ? Colors.transparent : scheme.surfaceContainer,
        borderRadius: Radii.smAll,
        border: muted ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted)
            SizedBox.square(
              dimension: 20,
              child: Icon(
                Icons.link_off,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            CollectionGlyph(
              iconKey: collection?.icon,
              tintSeed: link.collectionId,
              size: 20,
              iconSize: 13,
            ),
          const SizedBox(width: 6),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.compact ? 112 : double.infinity,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  decoration: _cardDeleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          if (widget.onClear case final clear?)
            SizedBox.square(
              dimension: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: l10n.inboxRemoveLink,
                color: scheme.onSurfaceVariant,
                onPressed: clear,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );

    final VoidCallback? onTap =
        widget.onTap ??
        (collection == null || muted ? null : () => _open(collection));
    return Semantics(
      button: onTap != null,
      label: muted ? label : l10n.inboxOpenLink(label),
      excludeSemantics: widget.onClear == null,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}
