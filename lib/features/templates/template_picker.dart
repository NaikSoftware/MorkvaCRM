import 'package:flutter/material.dart';

import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../../l10n/l10n.dart';
import 'template_catalog.dart';

/// Shows the bundled templates; "Add to workspace" runs [onAdd] (with a
/// spinner on that button) and closes the dialog with the added template.
Future<WorkspaceTemplate?> showTemplatePicker(
  BuildContext context, {
  required Future<void> Function(WorkspaceTemplate template) onAdd,
  Future<List<WorkspaceTemplate>> Function()? load,
}) => showDialog<WorkspaceTemplate>(
  context: context,
  builder: (_) => TemplatePicker(
    onAdd: onAdd,
    load:
        load ??
        () => loadBundledTemplates(
          null,
          Localizations.localeOf(context).languageCode,
        ),
  ),
);

class TemplatePicker extends StatefulWidget {
  const TemplatePicker({super.key, required this.onAdd, required this.load});

  final Future<void> Function(WorkspaceTemplate template) onAdd;
  final Future<List<WorkspaceTemplate>> Function() load;

  @override
  State<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePicker> {
  late final Future<List<WorkspaceTemplate>> _templates = widget.load();
  String? _adding;
  String? _error;

  Future<void> _add(WorkspaceTemplate template) async {
    setState(() {
      _adding = template.id;
      _error = null;
    });
    try {
      await widget.onAdd(template);
      if (mounted) Navigator.of(context).pop(template);
    } catch (_) {
      if (mounted) {
        setState(() {
          _adding = null;
          _error = context.l10n.templatesAddFailed(template.name);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      backgroundColor: scheme.surfaceContainerLowest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.sm,
                Spacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.templatesTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          context.l10n.templatesSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: const Icon(MorkvaIcons.close),
                    onPressed: _adding == null
                        ? () => Navigator.of(context).pop()
                        : null,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Flexible(
              child: FutureBuilder<List<WorkspaceTemplate>>(
                future: _templates,
                builder: (context, snapshot) {
                  final templates = snapshot.data;
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text(context.l10n.templatesLoadFailed),
                    );
                  }
                  if (templates == null) {
                    return const Padding(
                      padding: EdgeInsets.all(Spacing.xl),
                      child: Center(child: LoadingIndicator()),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(Spacing.lg),
                    children: [
                      for (final t in templates) ...[
                        _TemplateCard(
                          template: t,
                          adding: _adding == t.id,
                          onAdd: _adding == null ? () => _add(t) : null,
                        ),
                        const SizedBox(height: Spacing.md),
                      ],
                      if (_error != null)
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        )
                      else
                        Text(
                          context.l10n.templatesSampleHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.adding,
    required this.onAdd,
  });

  final WorkspaceTemplate template;
  final bool adding;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collections = template.collections.length;
    final cards = template.objects.length;
    return Container(
      padding: const EdgeInsets.all(Spacing.md + Spacing.xxs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CollectionGlyph(iconKey: template.icon),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: Spacing.xxs / 2),
                    Text(
                      template.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.xxs,
            runSpacing: Spacing.xxs,
            children: [
              for (final name in template.collectionNames)
                Chip(
                  label: Text(name),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: scheme.surfaceContainerHigh,
                  labelStyle: theme.textTheme.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.templatesContents(collections, cards),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SecondaryButton(
                label: context.l10n.templatesAdd,
                icon: MorkvaIcons.add,
                loading: adding,
                onPressed: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
