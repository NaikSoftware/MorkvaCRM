import 'package:flutter/material.dart';

import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../bloc/modules_cubit.dart';
import '../widgets/radio_row.dart';
import '../widgets/reason_copy.dart';
import 'automations_page.dart';
import 'code_viewer.dart';

/// A dialog sheet's fill: white in light (DESIGN.md), one step up from the
/// canvas in dark. Not M3's `surfaceContainerHigh` default: the change
/// summary box and the action row's tint are that colour and vanished.
Color sheetSurface(ThemeData theme) => theme.brightness == Brightness.light
    ? theme.colorScheme.surfaceContainerLowest
    : theme.colorScheme.surfaceContainer;

/// Consent, import and test-run sheets: a centered dialog 560 wide
/// (`Radii.lg`) on wide layouts, a full-height bottom sheet with a drag
/// handle on phones.
Future<T?> showAutomationSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (automationsExpanded(context)) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: sheetSurface(Theme.of(context)),
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        insetPadding: const EdgeInsets.all(Spacing.lg),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: builder(context),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Keeps the paste field and test-run inputs above the keyboard.
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// The frame of a sheet: [header], a scrolling [body] and a [footer] row.
class AutomationSheetFrame extends StatelessWidget {
  const AutomationSheetFrame({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
  });

  final Widget header;
  final List<Widget> body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.sm,
          ),
          child: header,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xs,
              Spacing.lg,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Padding(padding: const EdgeInsets.all(Spacing.md), child: footer),
      ],
    );
  }
}

/// A sheet's button row: an optional muted [hint] (a disabled button's
/// reason) at the left, the [buttons] at the right; stacked when narrow.
class SheetFooter extends StatelessWidget {
  const SheetFooter({super.key, this.hint, required this.buttons});

  final String? hint;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = hint == null
        ? null
        : Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
    final row = Wrap(
      alignment: WrapAlignment.end,
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: buttons,
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 480
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (text != null) ...[text, const SizedBox(height: Spacing.xs)],
                Align(alignment: Alignment.centerRight, child: row),
              ],
            )
          : Row(
              children: [
                Expanded(child: text ?? const SizedBox.shrink()),
                row,
              ],
            ),
    );
  }
}

/// A sheet title with an icon tile and a subtitle.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: Radii.mdAll,
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A capability's icon (consent sheet, module details).
IconData capabilityIcon(String cap) => switch (cap) {
  'schema:read' => Icons.table_chart_outlined,
  'data:read' => Icons.visibility_outlined,
  'data:write' => Icons.edit_outlined,
  'data:delete' => Icons.delete_outline,
  'schema:write' => Icons.build_outlined,
  'schema:delete' => Icons.delete_forever_outlined,
  'views:write' => Icons.view_column_outlined,
  'ui:navigate' => Icons.link,
  _ => Icons.shield_outlined,
};

/// "On a card" / "On a collection" / "Card or collection".
String scopeTag(ActionScope scope) => switch (scope) {
  ActionScope.card => 'On a card',
  ActionScope.collection => 'On a collection',
  ActionScope.any => 'Card or collection',
};

/// One capability row: icon, title, explanation, an optional trailing tag;
/// [removed] strikes it through.
class CapabilityRow extends StatelessWidget {
  const CapabilityRow({
    super.key,
    required this.cap,
    this.extra,
    this.trailing,
    this.removed = false,
  });

  final String cap;

  /// Appended to the explanation (" · In Orders").
  final String? extra;
  final Widget? trailing;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final copy = kCapabilityCopy[cap];
    final strike = removed
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: Radii.smAll,
            ),
            child: Icon(
              capabilityIcon(cap),
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy?.title ?? cap,
                  style: theme.textTheme.titleSmall
                      ?.merge(strike)
                      .copyWith(
                        color: removed ? scheme.onSurfaceVariant : null,
                      ),
                ),
                Text(
                  [copy?.explanation ?? '', ?extra].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.merge(strike)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// What the consent sheet does.
enum ConsentMode {
  /// An import: "Allow and install".
  install,

  /// First consent or re-consent of an installed module: "Allow".
  allow,

  /// Change access: only "Where" is editable; "Save".
  edit,
}

/// The consent sheet (UX §2): what the module can do, its actions, and
/// where it may work. Returns the chosen scope, or null when cancelled; the
/// caller hands it to the cubit with the [ConsentView] it showed.
Future<ConsentScope?> showConsentSheet(
  BuildContext context, {
  required ConsentView view,
  required List<Collection> collections,
  required ConsentScope initial,
  required ConsentMode mode,
  required String source,
}) => showAutomationSheet<ConsentScope>(
  context,
  builder: (_) => ConsentSheet(
    view: view,
    collections: collections,
    initial: initial,
    mode: mode,
    source: source,
  ),
);

class ConsentSheet extends StatefulWidget {
  const ConsentSheet({
    super.key,
    required this.view,
    required this.collections,
    required this.initial,
    required this.mode,
    required this.source,
  });

  final ConsentView view;
  final List<Collection> collections;
  final ConsentScope initial;
  final ConsentMode mode;

  /// "Imported" / "Made by Ask Morkva".
  final String source;

  @override
  State<ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<ConsentSheet> {
  late ConsentScope _scope = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final manifest = view.bundle.manifest;
    final bytes = view.bundle.codeBytes;
    final edit = widget.mode == ConsentMode.edit;
    final label = theme.textTheme.titleSmall;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final semantic = theme.extension<MorkvaSemanticColors>()!;

    Widget box(List<Widget> rows) => Container(
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            r,
          ],
        ],
      ),
    );

    final body = <Widget>[
      if (!edit && view.reconsent) ...[
        Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: Radii.mdAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The same bundle again: nothing changed to compare.
              if (view.codeChanged)
                MetaLine(
                  icon: Icons.code,
                  text:
                      'Code changed: v${view.fromVersion} → '
                      'v${manifest.version} · '
                      '${kbLabel(view.fromBytes ?? 0)} → ${kbLabel(bytes)}',
                )
              else
                const MetaLine(
                  icon: Icons.check_circle_outline,
                  text: 'This version is already installed.',
                ),
              // Installing writes a fresh consent, auto-apply off.
              if (view.autoApplyTurnsOff) ...[
                const SizedBox(height: Spacing.xxs),
                MetaLine(
                  icon: Icons.bolt_outlined,
                  text: view.codeChanged
                      ? 'Auto-apply turns off for the new version. Turn it '
                            'on again in module details.'
                      : 'Auto-apply turns off when you install it again. '
                            'Turn it on again in module details.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
      ],
      if (!edit) ...[
        Text('It can:', style: label),
        const SizedBox(height: Spacing.xs),
        box([
          // What it will be able to do first; what it gives up last.
          for (final c in [
            ...view.caps.where((c) => c.change != CapChange.removed),
            ...view.caps.where((c) => c.change == CapChange.removed),
          ])
            CapabilityRow(
              cap: c.cap,
              removed: c.change == CapChange.removed,
              trailing: switch (c.change) {
                CapChange.added => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: Radii.fullAll,
                    border: Border.all(color: semantic.warning, width: 1.5),
                  ),
                  child: Text(
                    'New',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantic.onWarningContainer,
                    ),
                  ),
                ),
                CapChange.removed => Text('Removed', style: muted),
                CapChange.kept => null,
              },
            ),
        ]),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(child: Text('Actions:', style: label)),
            TextActionButton(
              label: 'View code',
              icon: Icons.code,
              onPressed: () => showCodeViewer(
                context,
                code: view.bundle.code,
                hash: bundleHashOf(view.bundle.manifestJson, view.bundle.code),
              ),
            ),
          ],
        ),
        for (final a in manifest.actions)
          Container(
            margin: const EdgeInsets.only(top: Spacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              // One step above the sheet: in dark the sheet itself is
              // surfaceContainer.
              color: theme.brightness == Brightness.light
                  ? scheme.surfaceContainer
                  : scheme.surfaceContainerHigh,
              borderRadius: Radii.mdAll,
            ),
            child: Row(
              children: [
                Icon(
                  CollectionIcons.byKey(a.icon),
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),
                Flexible(child: Text(a.label, style: label)),
                const SizedBox(width: Spacing.xs),
                HugChip(label: scopeTag(a.scope), tone: CopyTone.neutral),
              ],
            ),
          ),
        const SizedBox(height: Spacing.md),
      ],
      Text('Where', style: label),
      const SizedBox(height: Spacing.xs),
      RadioGroup<bool>(
        groupValue: _scope.all,
        onChanged: (all) => setState(
          () => _scope = all == true
              ? const ConsentScope.all()
              : ConsentScope.only(_scope.only),
        ),
        child: Column(
          children: [
            _ScopeOption(
              value: true,
              title: 'All collections',
              subtitle: 'Every collection, including new ones.',
            ),
            _ScopeOption(
              value: false,
              title: 'Only these',
              subtitle: 'Pick the collections it may read and change.',
            ),
          ],
        ),
      ),
      if (!_scope.all)
        Padding(
          padding: const EdgeInsets.only(left: RadioRow.inset),
          child: Wrap(
            children: [
              for (final c in widget.collections)
                SizedBox(
                  width: 220,
                  child: CheckboxListTile(
                    value: _scope.only.contains(c.id),
                    onChanged: (_) =>
                        setState(() => _scope = _scope.toggle(c.id)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Row(
                      children: [
                        CollectionGlyph(
                          iconKey: c.icon,
                          tintSeed: c.id,
                          size: 24,
                          iconSize: 14,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Flexible(
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: Spacing.md),
      MetaLine(
        icon: Icons.shield_outlined,
        text:
            "Modules can't reach the internet, your account or other apps. "
            'You can change or revoke this later in module details.',
      ),
    ];

    final confirm = switch (widget.mode) {
      ConsentMode.install => 'Allow and install',
      ConsentMode.allow => 'Allow',
      ConsentMode.edit => 'Save',
    };
    return AutomationSheetFrame(
      header: SheetHeader(
        icon: Icons.shield_outlined,
        title: edit
            ? 'Change access for "${manifest.name}"'
            : 'Allow "${manifest.name}"?',
        subtitle: 'v${manifest.version} · ${widget.source} · ${kbLabel(bytes)}',
      ),
      body: body,
      footer: SheetFooter(
        hint: _scope.chosen ? null : 'Choose where it can work',
        buttons: [
          TextActionButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Semantics(
            hint: _scope.chosen ? null : 'Choose where it can work',
            child: PrimaryButton(
              label: confirm,
              onPressed: _scope.chosen
                  ? () => Navigator.of(context).pop(_scope)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => RadioRow(
    value: value,
    title: title,
    hint: subtitle,
    titleStyle: Theme.of(context).textTheme.titleSmall,
  );
}
