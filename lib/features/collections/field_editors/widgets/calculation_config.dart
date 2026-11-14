import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import '../../../views/widgets/filter_builder.dart';
import '../../../views/widgets/view_labels.dart';
import '../../../views/widgets/view_popover.dart';
import 'config_controls.dart';
import 'formula_highlighter.dart';

/// The functions offered as one-tap chips; the rest sit in "More".
const _quickFunctions = ['IF', 'ROUND', 'MIN', 'MAX', 'AND', 'OR', 'TODAY'];

/// How a calculated field computes.
enum _Mode { formula, aggregate, lookup }

/// Configures a calculated field: a formula over the item's own fields, an
/// aggregate over other items, or a lookup of a linked item's field. Emits a
/// new definition on every edit.
class CalculationConfig extends StatefulWidget {
  const CalculationConfig({
    super.key,
    required this.field,
    required this.collections,
    required this.editingCollectionId,
    required this.onChanged,
  });

  final CalculatedFieldDefinition field;

  /// The workspace, with the collection being edited as its draft.
  final List<Collection> collections;
  final String editingCollectionId;
  final ValueChanged<FieldDefinition> onChanged;

  @override
  State<CalculationConfig> createState() => _CalculationConfigState();
}

class _CalculationConfigState extends State<CalculationConfig> {
  late final FormulaEditingController _formula = FormulaEditingController(
    text: _displayFormula,
    fields: _owner.fields,
  );
  final FocusNode _formulaFocus = FocusNode();

  /// What the other mode held, restored when switching back.
  String? _stashedExpression;
  Aggregation? _stashedAggregate;
  Lookup? _stashedLookup;

  _Mode get _mode => _field.isLookup
      ? _Mode.lookup
      : _field.isAggregate
      ? _Mode.aggregate
      : _Mode.formula;

  CalculatedFieldDefinition get _field => widget.field;

  Collection get _owner =>
      widget.collections
          .where((c) => c.id == widget.editingCollectionId)
          .firstOrNull ??
      Collection(id: widget.editingCollectionId, name: '');

  String get _displayFormula =>
      formulaToDisplay(widget.field.expression ?? '', _owner.fields);

  @override
  void didUpdateWidget(CalculationConfig old) {
    super.didUpdateWidget(old);
    _formula.fields = _owner.fields;
    // Follow outside changes (another field renamed) while not typing.
    final shown = _displayFormula;
    if (!_formulaFocus.hasFocus && _formula.text != shown) {
      _formula.text = shown;
    }
  }

  @override
  void dispose() {
    _formula.dispose();
    _formulaFocus.dispose();
    super.dispose();
  }

  void _emit(CalculatedFieldDefinition next) => widget.onChanged(next);

  // ---------------------------------------------------------------------------
  // Mode
  // ---------------------------------------------------------------------------

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    switch (_mode) {
      case _Mode.formula:
        _stashedExpression = _field.expression;
      case _Mode.aggregate:
        _stashedAggregate = _field.aggregate;
      case _Mode.lookup:
        _stashedLookup = _field.lookup;
    }
    switch (mode) {
      case _Mode.aggregate:
        final a =
            _stashedAggregate ??
            _sourceOptions(context.l10n).firstOrNull?.aggregation ??
            Aggregation(
              source: AggregateSource.all,
              collectionId: widget.editingCollectionId,
            );
        _emit(
          _field.copyWith(
            aggregate: a,
            lookup: null,
            lookupTarget: null,
            expression: null,
            declaredOutputType: aggregateOutputType(
              a,
              _owner,
              widget.collections,
            ),
          ),
        );
      case _Mode.formula:
        final expression = _stashedExpression;
        _formula.text = formulaToDisplay(expression ?? '', _owner.fields);
        _emit(
          _field.copyWith(
            aggregate: null,
            lookup: null,
            lookupTarget: null,
            expression: expression,
            declaredOutputType: _formulaType(expression)?.fieldType,
          ),
        );
      case _Mode.lookup:
        final ref = _lookupReferences().firstOrNull;
        final lookup =
            _stashedLookup ??
            (ref == null ? null : _defaultLookup(ref)) ??
            const Lookup(referenceFieldId: '');
        _setLookup(
          lookup,
          base: _field.copyWith(aggregate: null, expression: null),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// The single-link reference fields of this collection a lookup can follow.
  List<ReferenceFieldDefinition> _lookupReferences() => [
    for (final r in _owner.fields.whereType<ReferenceFieldDefinition>())
      if (!r.multiple && _collection(r.targetCollectionId) != null) r,
  ];

  /// The fields of [ref]'s target a lookup can show.
  List<FieldDefinition> _shownFields(ReferenceFieldDefinition? ref) {
    final target = _collection(ref?.targetCollectionId);
    if (target == null) return const [];
    return [
      for (final f in target.fields)
        if (isLookupable(f) && !(target.id == _owner.id && f.id == _field.id))
          f,
    ];
  }

  Lookup? _defaultLookup(ReferenceFieldDefinition ref) => Lookup(
    referenceFieldId: ref.id,
    fieldId: _shownFields(ref).firstOrNull?.id,
  );

  void _setLookup(Lookup lookup, {CalculatedFieldDefinition? base}) {
    final field = (base ?? _field).copyWith(lookup: lookup);
    final target = lookupTargetOf(_owner, field, widget.collections);
    // The shown field is resolved on load, not stored: keeping it off the
    // draft keeps the draft equal to what the store echoes back.
    _emit(
      field.copyWith(
        lookupTarget: null,
        declaredOutputType: target?.type ?? kTextFieldType,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formula
  // ---------------------------------------------------------------------------

  FormulaCompileResult _compile(String? stored) =>
      compileFormula(stored ?? '', _owner.fields, selfId: _field.id);

  FormulaType? _formulaType(String? stored) => _compile(stored).formula?.type;

  void _onFormulaChanged(String text) {
    final stored = formulaToStorage(text, _owner.fields);
    _emit(
      _field.copyWith(
        expression: text.trim().isEmpty ? null : stored,
        declaredOutputType: _formulaType(stored)?.fieldType,
      ),
    );
  }

  /// Puts [snippet] at the cursor (replacing a selection); the cursor lands
  /// [back] characters before its end.
  void _insert(String snippet, {int back = 0}) {
    final value = _formula.value;
    final sel = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(sel.start, sel.end, snippet);
    _formula.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: sel.start + snippet.length - back,
      ),
    );
    _formulaFocus.requestFocus();
    _onFormulaChanged(text);
  }

  // ---------------------------------------------------------------------------
  // Aggregate
  // ---------------------------------------------------------------------------

  Collection? _collection(String? id) => id == _owner.id
      ? _owner
      : widget.collections.where((c) => c.id == id).firstOrNull;

  List<_SourceOption> _sourceOptions(AppLocalizations l10n) {
    final owner = _owner;
    final options = <_SourceOption>[];
    for (final c in widget.collections) {
      for (final r in c.fields.whereType<ReferenceFieldDefinition>()) {
        if (r.targetCollectionId != owner.id) continue;
        options.add(
          _SourceOption(
            Aggregation(
              source: AggregateSource.linkedFrom,
              collectionId: c.id,
              referenceFieldId: r.id,
            ),
            c.id == owner.id
                ? l10n.collectionsSourceLinkingToThis(c.name)
                : l10n.collectionsSourceLinkingHere(c.name),
            l10n.collectionsSourceVia(r.name),
            Icons.call_received,
          ),
        );
      }
    }
    for (final r in owner.fields.whereType<ReferenceFieldDefinition>()) {
      final target = _collection(r.targetCollectionId);
      if (target == null) continue;
      options.add(
        _SourceOption(
          Aggregation(
            source: AggregateSource.linked,
            collectionId: target.id,
            referenceFieldId: r.id,
          ),
          l10n.collectionsSourceLinked(target.name),
          l10n.collectionsSourceIn(r.name),
          Icons.call_made,
        ),
      );
    }
    for (final c in widget.collections) {
      options.add(
        _SourceOption(
          Aggregation(source: AggregateSource.all, collectionId: c.id),
          l10n.collectionsSourceAll(c.name),
          l10n.collectionsSourceEveryItem,
          Icons.select_all,
        ),
      );
    }
    return options;
  }

  static bool _sameSource(Aggregation a, Aggregation b) =>
      a.source == b.source &&
      a.collectionId == b.collectionId &&
      a.referenceFieldId == b.referenceFieldId;

  /// Fields of [source] that [op] can fold.
  static List<FieldDefinition> _foldable(Collection? source, AggregateOp op) {
    if (source == null || !op.needsField) return const [];
    return [
      for (final f in source.fields)
        if (_isNumber(f) || (op.index >= AggregateOp.min.index && _isDate(f)))
          f,
    ];
  }

  static bool _isNumber(FieldDefinition f) =>
      f is NumberFieldDefinition ||
      f is AutoNumberFieldDefinition ||
      (f is CalculatedFieldDefinition &&
          f.declaredOutputType == kNumberFieldType);

  static bool _isDate(FieldDefinition f) =>
      f is DateFieldDefinition ||
      (f is CalculatedFieldDefinition &&
          f.declaredOutputType == kDateFieldType);

  void _setAggregation(Aggregation a) {
    final source = _collection(_sourceIdOf(a));
    final fields = _foldable(source, a.op);
    final keep = fields.any((f) => f.id == a.fieldId);
    final fixed = a.op.needsField
        ? a.copyWith(fieldId: keep ? a.fieldId : fields.firstOrNull?.id)
        : a.copyWith(fieldId: null);
    _emit(
      _field.copyWith(
        aggregate: fixed,
        declaredOutputType: aggregateOutputType(
          fixed,
          _owner,
          widget.collections,
        ),
      ),
    );
  }

  String? _sourceIdOf(Aggregation a) => a.source == AggregateSource.linked
      ? switch (_owner.fieldById(a.referenceFieldId ?? '')) {
          ReferenceFieldDefinition(:final targetCollectionId) =>
            targetCollectionId,
          _ => null,
        }
      : a.collectionId;

  Future<void> _editCondition(
    BuildContext anchorContext,
    Collection source, [
    int? index,
  ]) async {
    final a = _field.aggregate!;
    final box = anchorContext.findRenderObject() as RenderBox?;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final anchor = box == null
        ? Rect.zero
        : box.localToGlobal(Offset.zero) & box.size;
    final result = await showViewPopover<ViewFilter>(
      context,
      compact: compact || box == null,
      anchor: anchor,
      label: index == null
          ? context.l10n.collectionsAddCondition
          : context.l10n.collectionsEditCondition,
      builder: (popover) => FilterBuilder(
        collection: source,
        initial: index == null ? null : a.filters.elementAtOrNull(index),
        onApply: (f) => Navigator.of(popover).pop(f),
      ),
    );
    if (result == null || !mounted) return;
    final current = _field.aggregate;
    if (current == null) return;
    final filters = [...current.filters];
    if (index != null && index < filters.length) {
      filters[index] = result;
    } else {
      filters.add(result);
    }
    _setAggregation(current.copyWith(filters: filters));
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = _mode;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_Mode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _Mode.formula,
              icon: const Icon(Icons.functions),
              label: Text(l10n.collectionsModeFormula),
            ),
            ButtonSegment(
              value: _Mode.aggregate,
              icon: const Icon(Icons.bar_chart),
              label: Text(l10n.collectionsModeAggregate),
            ),
            ButtonSegment(
              value: _Mode.lookup,
              icon: const Icon(Icons.manage_search),
              label: Text(l10n.collectionsModeLookup),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => _setMode(s.first),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          switch (mode) {
            _Mode.aggregate => l10n.collectionsModeAggregateHint,
            _Mode.lookup => l10n.collectionsModeLookupHint,
            _Mode.formula => l10n.collectionsModeFormulaHint,
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.md),
        ...switch (mode) {
          _Mode.aggregate => _aggregateControls(context),
          _Mode.lookup => _lookupControls(context),
          _Mode.formula => _formulaControls(context),
        },
        // A lookup shows the number as its source field formats it.
        if (mode != _Mode.lookup &&
            _field.declaredOutputType == kNumberFieldType) ...[
          const SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConfigTextField(
                  key: ValueKey('decimals_${_field.id}'),
                  label: l10n.collectionsDecimals,
                  hint: l10n.collectionsDecimalsAuto,
                  value: _field.decimalPlaces?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  onChanged: (t) {
                    final n = parseOptionalInt(t);
                    _emit(_field.copyWith(decimalPlaces: n?.clamp(0, 10)));
                  },
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: ConfigTextField(
                  key: ValueKey('unit_${_field.id}'),
                  label: l10n.collectionsUnit,
                  hint: l10n.collectionsUnitHint,
                  value: _field.unitLabel ?? '',
                  onChanged: (t) => _emit(
                    _field.copyWith(unitLabel: t.trim().isEmpty ? null : t),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _formulaControls(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final l10n = context.l10n;
    final compiled = _compile(_field.expression);
    final cycle = compiled.formula == null
        ? null
        : formulaCycle(_owner, _field.id);
    final error = cycle != null
        ? l10n.collectionsFormulaCircular(cycle.join(' → '))
        : switch (compiled.error) {
            final e? when _field.expression != null =>
              l10n.formulaErrorMessage(e),
            _ => null,
          };
    final insertable = [
      for (final f in _owner.fields)
        if (f.id != _field.id && formulaTypeOfField(f) != null) f,
    ];
    final mono = MorkvaTypography.tabular(
      (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Roboto Mono', 'Courier New'],
        height: 1.5,
      ),
    );
    return [
      Text(l10n.collectionsModeFormula, style: _labelStyle(theme)),
      const SizedBox(height: Spacing.xxs),
      TextField(
        key: ValueKey('formula_${_field.id}'),
        controller: _formula,
        focusNode: _formulaFocus,
        minLines: 3,
        maxLines: 6,
        style: mono,
        keyboardType: TextInputType.multiline,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp('\t'))],
        decoration: InputDecoration(
          hintText: l10n.collectionsFormulaExample('{', '}'),
          errorText: error,
          errorMaxLines: 3,
        ),
        onChanged: _onFormulaChanged,
      ),
      if (error == null && compiled.formula != null) ...[
        const SizedBox(height: Spacing.xxs),
        Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: semantic.success),
            const SizedBox(width: Spacing.xxs),
            Text(
              l10n.collectionsFormulaResult(
                l10n.formulaTypeLabel(compiled.formula!.type),
              ),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: Spacing.md),
      if (insertable.isNotEmpty) ...[
        Text(l10n.collectionsInsertField, style: _labelStyle(theme)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: [
            for (final f in insertable)
              ActionChip(
                avatar: Icon(fieldTypeIcon(f), size: 16),
                label: Text(f.name),
                onPressed: () => _insert('{${f.name}}'),
              ),
          ],
        ),
        const SizedBox(height: Spacing.md),
      ],
      Text(l10n.collectionsFunctions, style: _labelStyle(theme)),
      const SizedBox(height: Spacing.xs),
      Wrap(
        spacing: Spacing.xs,
        runSpacing: Spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final name in _quickFunctions)
            _FunctionChip(
              function: formulaFunctions[name]!,
              l10n: l10n,
              onPressed: () => _insertFunction(formulaFunctions[name]!),
            ),
          _FunctionChip.text(
            label: l10n.collectionsJoinChip,
            tooltip: l10n.collectionsJoinTooltip('{', '}'),
            onPressed: () => _insert(' & '),
          ),
          MenuAnchor(
            menuChildren: [
              for (final f in formulaFunctions.values)
                MenuItemButton(
                  onPressed: () => _insertFunction(f),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.formulaUsage(f),
                          style: mono.copyWith(fontSize: 13),
                        ),
                        Text(
                          l10n.formulaSummary(f),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            builder: (context, controller, _) => _FunctionChip.text(
              label: l10n.collectionsAllFunctions,
              tooltip: l10n.collectionsAllFunctionsTooltip,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
    ];
  }

  void _insertFunction(FormulaFunction f) =>
      f.maxArgs == 0 ? _insert('${f.name}()') : _insert('${f.name}()', back: 1);

  List<Widget> _aggregateControls(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final a = _field.aggregate!;
    final options = _sourceOptions(l10n);
    final selected = options.indexWhere((o) => _sameSource(o.aggregation, a));
    final source = _collection(_sourceIdOf(a));
    final foldable = _foldable(source, a.op);
    return [
      Text(l10n.collectionsSummarize, style: _labelStyle(theme)),
      const SizedBox(height: Spacing.xxs),
      DropdownButtonFormField<int>(
        key: ValueKey('source_${_field.id}'),
        initialValue: selected < 0 ? null : selected,
        isExpanded: true,
        hint: Text(l10n.collectionsPickSource),
        items: [
          for (final (i, o) in options.indexed)
            DropdownMenuItem(
              value: i,
              child: Row(
                children: [
                  Icon(o.icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: Spacing.xs),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: o.title,
                        children: [
                          TextSpan(
                            text: '  ${o.detail}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (i) {
          if (i == null) return;
          final o = options[i].aggregation;
          _setAggregation(
            a.copyWith(
              source: o.source,
              collectionId: o.collectionId,
              referenceFieldId: o.referenceFieldId,
              // Conditions belong to the old source's fields.
              filters: _sourceIdOf(o) == _sourceIdOf(a) ? a.filters : const [],
            ),
          );
        },
      ),
      if (options.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Spacing.xxs),
          child: Text(
            l10n.collectionsNoSources,
            style: theme.textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: Spacing.md),
      Text(l10n.collectionsCalculate, style: _labelStyle(theme)),
      const SizedBox(height: Spacing.xs),
      Wrap(
        spacing: Spacing.xs,
        runSpacing: Spacing.xs,
        children: [
          for (final op in AggregateOp.values)
            ChoiceChip(
              label: Text(l10n.aggregateOpLabel(op)),
              selected: a.op == op,
              onSelected: (_) => _setAggregation(a.copyWith(op: op)),
            ),
        ],
      ),
      if (a.op.needsField) ...[
        const SizedBox(height: Spacing.md),
        Text(l10n.collectionsAggregateOf, style: _labelStyle(theme)),
        const SizedBox(height: Spacing.xxs),
        if (foldable.isEmpty)
          Text(
            source == null
                ? l10n.collectionsPickSourceFirst
                : a.op.index >= AggregateOp.min.index
                ? l10n.collectionsNoNumberOrDateFields(source.name)
                : l10n.collectionsNoNumberFields(source.name),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey('of_${_field.id}_${source?.id}_${a.op}'),
            initialValue: foldable.any((f) => f.id == a.fieldId)
                ? a.fieldId
                : null,
            isExpanded: true,
            items: [
              for (final f in foldable)
                DropdownMenuItem(
                  value: f.id,
                  child: Row(
                    children: [
                      Icon(fieldTypeIcon(f), size: 18),
                      const SizedBox(width: Spacing.xs),
                      Flexible(
                        child: Text(f.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (id) => _setAggregation(a.copyWith(fieldId: id)),
          ),
      ],
      if (source != null) ...[
        const SizedBox(height: Spacing.md),
        Text(l10n.collectionsOnlyWhere, style: _labelStyle(theme)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: [
            for (final (i, f) in a.filters.indexed)
              Builder(
                builder: (chipContext) => InputChip(
                  label: Text(
                    filterLabel(f, source, l10n: chipContext.l10n),
                  ),
                  onPressed: () => _editCondition(chipContext, source, i),
                  onDeleted: () => _setAggregation(
                    a.copyWith(filters: [...a.filters]..removeAt(i)),
                  ),
                  deleteButtonTooltipMessage: l10n.collectionsRemoveCondition,
                ),
              ),
            Builder(
              builder: (buttonContext) => ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(
                  a.filters.isEmpty
                      ? l10n.collectionsAddCondition
                      : l10n.collectionsAndCondition,
                ),
                onPressed: () => _editCondition(buttonContext, source),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: Spacing.md),
      _InWords(
        text: calculationSummary(
          _field,
          _owner,
          widget.collections,
          l10n: context.l10n,
        ),
      ),
    ];
  }

  List<Widget> _lookupControls(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lookup = _field.lookup!;
    final refs = _lookupReferences();
    final ref = refs.where((r) => r.id == lookup.referenceFieldId).firstOrNull;
    final shown = _shownFields(ref);
    final target = _collection(ref?.targetCollectionId);
    final l10n = context.l10n;
    return [
      Text(l10n.collectionsThrough, style: _labelStyle(theme)),
      const SizedBox(height: Spacing.xxs),
      if (refs.isEmpty)
        Text(
          l10n.collectionsNoLookupReferences,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
        )
      else
        DropdownButtonFormField<String>(
          key: ValueKey('through_${_field.id}'),
          initialValue: ref?.id,
          isExpanded: true,
          hint: Text(l10n.collectionsPickReference),
          items: [
            for (final r in refs)
              DropdownMenuItem(
                value: r.id,
                child: Row(
                  children: [
                    Icon(
                      Icons.call_made,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: r.name,
                          children: [
                            TextSpan(
                              text:
                                  '  ${l10n.collectionsLinksTo(_collection(r.targetCollectionId)?.name ?? '…')}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (id) {
            final next = refs.where((r) => r.id == id).firstOrNull;
            if (next != null) _setLookup(_defaultLookup(next)!);
          },
        ),
      if (ref != null) ...[
        const SizedBox(height: Spacing.md),
        Text(l10n.collectionsShow, style: _labelStyle(theme)),
        const SizedBox(height: Spacing.xxs),
        if (shown.isEmpty)
          Text(
            target == null
                ? l10n.collectionsThatCollectionNoFields
                : l10n.collectionsNoFieldsToShow(target.name),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey('show_${_field.id}_${ref.id}'),
            initialValue: shown.any((f) => f.id == lookup.fieldId)
                ? lookup.fieldId
                : null,
            isExpanded: true,
            hint: Text(l10n.collectionsPickField),
            items: [
              for (final f in shown)
                DropdownMenuItem(
                  value: f.id,
                  child: Row(
                    children: [
                      Icon(fieldTypeIcon(f), size: 18),
                      const SizedBox(width: Spacing.xs),
                      Flexible(
                        child: Text(f.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (id) =>
                _setLookup(Lookup(referenceFieldId: ref.id, fieldId: id)),
          ),
        const SizedBox(height: Spacing.xxs),
        Text(
          l10n.collectionsLookupKeepsType,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: Spacing.md),
      _InWords(
        text: calculationSummary(
          _field,
          _owner,
          widget.collections,
          l10n: context.l10n,
        ),
      ),
    ];
  }

  static TextStyle? _labelStyle(ThemeData theme) => theme.textTheme.labelLarge
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
}

/// The plain-language sentence of what the field computes.
class _InWords extends StatelessWidget {
  const _InWords({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.collectionsInWords,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: Spacing.xxs),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SourceOption {
  const _SourceOption(this.aggregation, this.title, this.detail, this.icon);

  final Aggregation aggregation;
  final String title;
  final String detail;
  final IconData icon;
}

/// A compact monospace chip that inserts a function.
class _FunctionChip extends StatelessWidget {
  _FunctionChip({
    required FormulaFunction function,
    required AppLocalizations l10n,
    required this.onPressed,
  }) : label = function.name,
       tooltip =
           '${l10n.formulaUsage(function)} — ${l10n.formulaSummary(function)}';

  const _FunctionChip.text({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        label: Text(label),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Roboto Mono', 'Courier New'],
        ),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }
}
