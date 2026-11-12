import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../assistant/bloc/chat_item.dart' show PlanChange;
import '../../assistant/view/widgets/object_chip.dart';
import '../../assistant/view/widgets/plan_card.dart' show DiffLine;
import '../bloc/module_details_cubit.dart';
import '../widgets/reason_copy.dart';
import 'automations_page.dart';
import 'consent_sheet.dart';

/// A card a test run can pick ("#1042 · Acme").
typedef TestCard = ({String id, String label});

/// The Test-run sheet (UX §2) for [action] of the [cubit]'s module, limited
/// to [collections] (the module's allowed ones). [loadCards] lists a
/// collection's cards for the card picker.
Future<void> showTestRunSheet(
  BuildContext context, {
  required ModuleDetailsCubit cubit,
  required ActionSpec action,
  required List<Collection> collections,
  required Future<List<TestCard>> Function(Collection collection) loadCards,
  String? collectionId,
}) async {
  await showAutomationSheet<void>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: TestRunSheet(
        action: action,
        collections: collections,
        loadCards: loadCards,
        collectionId: collectionId,
      ),
    ),
  );
  if (!cubit.isClosed) cubit.closeTestRun();
}

class TestRunSheet extends StatefulWidget {
  const TestRunSheet({
    super.key,
    required this.action,
    required this.collections,
    required this.loadCards,
    this.collectionId,
  });

  final ActionSpec action;
  final List<Collection> collections;
  final Future<List<TestCard>> Function(Collection collection) loadCards;
  final String? collectionId;

  @override
  State<TestRunSheet> createState() => _TestRunSheetState();
}

class _TestRunSheetState extends State<TestRunSheet> {
  late String? _collectionId =
      widget.collectionId ?? widget.collections.firstOrNull?.id;
  String? _cardId;
  String _query = '';
  List<TestCard> _cards = const [];
  bool _loadFailed = false;
  late final Map<String, Object?> _params = {
    for (final MapEntry(:key, :value)
        in (widget.action.input?.properties ?? const {}).entries)
      if (value.hasDefault) key: value.defaultValue,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Collection? get _collection => _collectionId == null
      ? null
      : collectionOf(widget.collections, _collectionId!);

  bool get _onCard => widget.action.scope.onCard;

  Future<void> _load() async {
    final collection = _collection;
    if (!_onCard || collection == null) return;
    try {
      final cards = await widget.loadCards(collection);
      if (mounted && _collection == collection) {
        setState(() {
          _cards = cards;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted && _collection == collection) {
        setState(() => _loadFailed = true);
      }
    }
  }

  bool get _ready =>
      _collectionId != null &&
      (widget.action.scope != ActionScope.card || _cardId != null) &&
      (widget.action.input?.required ?? const []).every(
        (k) => _params[k] != null && _params[k] != '',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.watch<ModuleDetailsCubit>();
    final state = cubit.state;
    final test = state.testRun;
    final moduleId = cubit.moduleId;
    final action = widget.action;
    final label = theme.textTheme.labelMedium;

    Widget field(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: label),
          const SizedBox(height: Spacing.xs),
          child,
        ],
      ),
    );

    final matches = [
      for (final c in _cards)
        if (_query.isEmpty ||
            c.label.toLowerCase().contains(_query.toLowerCase()))
          c,
    ].take(6);

    final body = <Widget>[
      Text(
        "Test runs never change data — you'll see what would change.",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: Spacing.md),
      field(
        'Collection',
        DropdownButtonFormField<String>(
          key: ValueKey(_collectionId),
          initialValue: _collectionId,
          items: [
            for (final c in widget.collections)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: widget.collectionId != null
              ? null
              : (id) {
                  setState(() {
                    _collectionId = id;
                    _cardId = null;
                    _cards = const [];
                  });
                  _load();
                },
        ),
      ),
      if (_onCard)
        field(
          action.scope == ActionScope.card ? 'Card' : 'Card (optional)',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                hintText: 'Search cards',
                dense: true,
                onChanged: (q) => setState(() => _query = q),
                onCleared: () => setState(() => _query = ''),
              ),
              if (_loadFailed)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(
                    "Couldn't load cards",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              RadioGroup<String>(
                groupValue: _cardId,
                onChanged: (id) => setState(() => _cardId = id),
                child: Column(
                  children: [
                    for (final c in matches)
                      RadioListTile<String>(
                        value: c.id,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.label),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      for (final MapEntry(key: name, value: prop)
          in (action.input?.properties ?? const <String, InputProperty>{})
              .entries)
        field(
          prop.title ?? name,
          _ParamInput(
            property: prop,
            value: _params[name],
            collection: _collection,
            collections: widget.collections,
            onChanged: (v) => setState(() => _params[name] = v),
          ),
        ),
      if (test?.result case final result?) ...[
        const Divider(height: Spacing.xl),
        TestRunResultView(result: result),
      ],
    ];

    return AutomationSheetFrame(
      header: SheetHeader(
        icon: Icons.play_arrow_outlined,
        title: 'Test "${action.label}"',
      ),
      body: body,
      footer: SheetFooter(
        hint: state.canTestRun ? null : 'Allow the module to test it',
        buttons: [
          TextActionButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Semantics(
            hint: state.canTestRun ? null : 'Allow the module to test it',
            child: PrimaryButton(
              label: 'Run test',
              icon: Icons.play_arrow,
              loading: test?.running ?? false,
              onPressed: state.canTestRun && _ready && !(test?.running ?? false)
                  ? () => cubit.testRun(
                      TestRunRequest(
                        moduleId: moduleId,
                        actionId: action.id,
                        cardId: _cardId,
                        collectionId: _collectionId,
                        params: Map.of(_params)
                          ..removeWhere((_, v) => v == null || v == ''),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// One action input: a field or collection picker, an enum dropdown, a
/// switch, or a text / number field.
class _ParamInput extends StatefulWidget {
  const _ParamInput({
    required this.property,
    required this.value,
    required this.collection,
    required this.collections,
    required this.onChanged,
  });

  final InputProperty property;
  final Object? value;
  final Collection? collection;
  final List<Collection> collections;
  final ValueChanged<Object?> onChanged;

  @override
  State<_ParamInput> createState() => _ParamInputState();
}

class _ParamInputState extends State<_ParamInput> {
  late final _text = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final value = widget.value;
    final collection = widget.collection;
    final onChanged = widget.onChanged;
    final options = switch (property) {
      InputProperty(format: InputFormat.field) => [
        for (final f in collection?.fields ?? const <FieldDefinition>[])
          (f.id, f.name),
      ],
      InputProperty(format: InputFormat.collection) => [
        for (final c in widget.collections) (c.id, c.name),
      ],
      InputProperty(:final enumValues?) => [for (final v in enumValues) (v, v)],
      _ => null,
    };
    if (options != null) {
      return DropdownButtonFormField<String>(
        key: ValueKey((collection?.id, value)),
        initialValue: options.any((o) => o.$1 == value)
            ? value as String
            : null,
        items: [
          for (final (id, name) in options)
            DropdownMenuItem(value: id, child: Text(name)),
        ],
        onChanged: onChanged,
      );
    }
    if (property.type == InputType.boolean) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(value: value == true, onChanged: (v) => onChanged(v)),
      );
    }
    final numeric =
        property.type == InputType.number || property.type == InputType.integer;
    return MorkvaTextField(
      controller: _text,
      hint: property.description,
      keyboardType: numeric ? TextInputType.number : null,
      onChanged: (t) => onChanged(
        !numeric
            ? t
            : property.type == InputType.integer
            ? int.tryParse(t)
            : num.tryParse(t),
      ),
    );
  }
}

/// A test run's result block (the sheet, the chat's test-run card): status
/// line, read-only plan rows, then collapsible Calls and Console.
class TestRunResultView extends StatelessWidget {
  const TestRunResultView({super.key, required this.result});

  final TestRunResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = result.plan.length;
    final ms = result.log.calls.isEmpty
        ? null
        : result.log.calls.last.t + result.log.calls.last.ms;
    final (text, color) = switch (result.status) {
      RunStatus.succeeded when n == 0 => ('No changes', scheme.onSurface),
      RunStatus.succeeded => (
        'Would change $n ${n == 1 ? 'card' : 'cards'}'
            '${ms == null ? '' : ' · $ms ms'}',
        scheme.onSurface,
      ),
      RunStatus.skipped => (
        runCopy(result.status, result.reason).row,
        scheme.onSurfaceVariant,
      ),
      _ => (
        'Failed: ${result.error?.message ?? runCopy(result.status, result.reason).row}',
        scheme.error,
      ),
    };
    final mono = MorkvaTypography.mono(theme.textTheme.bodySmall!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        ),
        if (result.plan.isNotEmpty) ...[
          const SizedBox(height: Spacing.xs),
          for (final p in result.plan) PlanLineRow(line: p),
        ],
        if (result.log.calls.isNotEmpty)
          ExpansionTile(
            title: Text('Calls (${result.log.calls.length})'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in result.log.calls)
                Text(
                  '${c.op} · ${c.args} · ${c.ms} ms ${c.ok ? '✓' : '✗ ${c.result}'}',
                  style: mono.copyWith(color: c.ok ? null : scheme.error),
                ),
            ],
          ),
        if (result.log.console.isNotEmpty)
          ExpansionTile(
            title: Text('Console (${result.log.console.length})'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in result.log.console)
                ConsoleLineText(line: c, style: mono),
            ],
          ),
      ],
    );
  }
}

/// One planned change, read-only (the PlanCard row style without a
/// checkbox): "#1042 · Shipped on: — → 12 Nov".
class PlanLineRow extends StatelessWidget {
  const PlanLineRow({super.key, required this.line});

  final PlanLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "#1042 · Iryna Melnyk": the card chip, then the rest in bold.
    final cut = line.label.indexOf(' · ');
    final head = cut < 0 ? line.label : line.label.substring(0, cut);
    final rest = cut < 0 ? null : line.label.substring(cut + 3);
    final icon = Icon(
      switch (line.kind) {
        'createCard' => Icons.add_circle_outline,
        'deleteCard' => Icons.remove_circle_outline,
        _ => Icons.edit_outlined,
      },
      size: 16,
      color: theme.colorScheme.onSurfaceVariant,
    );
    // A log written before the pills were stored: the line in words.
    if (line.changes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: Spacing.xs),
            Text(line.label, style: theme.textTheme.titleSmall),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(line.change, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: Spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // An edit is the plain case; a create or delete says so.
        if (line.kind == 'createCard' || line.kind == 'deleteCard') icon,
        // Not a link here: the chip names the card, nothing opens.
        ObjectChip(label: head, semanticLabel: head),
        if (rest != null) Text(rest, style: theme.textTheme.titleSmall),
        for (final c in line.changes)
          DiffLine(
            // A create's fields have no before: no dashes there.
            markEmpty: line.kind != 'createCard',
            change: PlanChange(
              field: c.field,
              beforeText: c.before,
              afterText: c.after,
            ),
          ),
      ],
    );
  }
}

/// A console line in mono, coloured by level (warn amber, error red).
class ConsoleLineText extends StatelessWidget {
  const ConsoleLineText({super.key, required this.line, required this.style});

  final ConsoleLine line;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (line.level) {
      'warn' => theme.extension<MorkvaSemanticColors>()!.onWarningContainer,
      'error' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${line.level.padRight(5)}  ',
            style: TextStyle(color: color),
          ),
          TextSpan(text: line.text),
        ],
      ),
      style: style,
    );
  }
}
