import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'option_pill.dart';
import 'view_labels.dart';

/// Builds one filter in three steps: field (searchable) → operator (by the
/// field's type) → value. Operators without a value (is empty, is checked…)
/// apply straight from the operator step.
///
/// Editing an existing [initial] filter opens at its value step. The result
/// is reported through [onApply]; nothing with a blank value is reported.
class FilterBuilder extends StatefulWidget {
  const FilterBuilder({
    super.key,
    required this.collection,
    required this.onApply,
    this.initial,
    this.referenceChoices = _noChoices,
  });

  final Collection collection;
  final ViewFilter? initial;
  final ValueChanged<ViewFilter> onApply;

  /// Object id → label of what a reference field can point at; empty while
  /// loading.
  final Map<String, String> Function(String fieldId) referenceChoices;

  static Map<String, String> _noChoices(String _) => const {};

  @override
  State<FilterBuilder> createState() => _FilterBuilderState();
}

/// Whether [op] takes no operand.
bool _valueless(FilterOp op) => const {
  FilterOp.isEmpty,
  FilterOp.isNotEmpty,
  FilterOp.isTrue,
  FilterOp.isFalse,
}.contains(op);

/// Builder-facing operator names ("is any of" rather than the chip's "is").
String operatorLabel(FilterOp op, FieldDefinition field) => switch (op) {
  FilterOp.isEmpty => 'is empty',
  FilterOp.isNotEmpty => 'is not empty',
  FilterOp.equals => field is TextFieldDefinition ? 'is' : '=',
  FilterOp.notEquals => '≠',
  FilterOp.contains => 'contains',
  FilterOp.notContains => 'does not contain',
  FilterOp.greaterThan => '>',
  FilterOp.lessThan => '<',
  FilterOp.before => 'is before',
  FilterOp.after => 'is after',
  FilterOp.onDay => 'is on',
  FilterOp.anyOf =>
    field is MultiSelectFieldDefinition ||
            (field is ReferenceFieldDefinition && field.multiple)
        ? 'has any of'
        : 'is any of',
  FilterOp.noneOf =>
    field is MultiSelectFieldDefinition ? 'has none of' : 'is none of',
  FilterOp.isTrue => 'is checked',
  FilterOp.isFalse => 'is not checked',
};

/// [day] as the bare `YYYY-MM-DD` a date filter stores.
String dateOperand(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

class _FilterBuilderState extends State<FilterBuilder> {
  FieldDefinition? _field;
  FilterOp? _op;
  Object? _operand;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final field = initial == null
        ? null
        : widget.collection.fieldById(initial.fieldId);
    if (initial == null || field == null) return;
    _field = field;
    if (operatorsFor(field).contains(initial.op)) {
      _op = _valueless(initial.op) ? null : initial.op;
      _operand = initial.operand;
    }
  }

  /// The operand to save, or null while it is blank or malformed.
  Object? get _valid => switch (_operand) {
    final String s when s.trim().isNotEmpty => s.trim(),
    final num n when n.isFinite => n,
    final List<Object?> l when l.isNotEmpty => [...l.whereType<String>()],
    _ => null,
  };

  void _pickField(FieldDefinition field) => setState(() {
    if (field.id != _field?.id) {
      _op = null;
      _operand = null;
    }
    _field = field;
  });

  void _pickOp(FilterOp op) {
    final field = _field!;
    if (_valueless(op)) {
      widget.onApply(ViewFilter(fieldId: field.id, op: op));
      return;
    }
    // A field type's operators share one operand kind, so it carries over.
    setState(() => _op = op);
  }

  void _apply() {
    final operand = _valid;
    final field = _field;
    final op = _op;
    if (operand == null || field == null || op == null) return;
    widget.onApply(ViewFilter(fieldId: field.id, op: op, operand: operand));
  }

  void _back() => setState(() {
    if (_op != null) {
      _op = null;
    } else {
      _field = null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final field = _field;
    final op = _op;
    final (title, body) = switch ((field, op)) {
      (null, _) => (
        'Filter by',
        _FieldStep(fields: widget.collection.fields, onPick: _pickField),
      ),
      (final f?, null) => (
        f.name,
        _OperatorStep(
          field: f,
          selected: widget.initial?.fieldId == f.id ? widget.initial?.op : null,
          onPick: _pickOp,
        ),
      ),
      (final f?, final o?) => (
        '${f.name} ${operatorLabel(o, f)}',
        _ValueStep(
          field: f,
          op: o,
          operand: _operand,
          referenceChoices: f is ReferenceFieldDefinition
              ? widget.referenceChoices(f.id)
              : const {},
          onChanged: (v) => setState(() => _operand = v),
          onSubmit: _apply,
        ),
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: title, onBack: field == null ? null : _back),
        Flexible(child: body),
        if (field != null && op != null)
          _ApplyBar(
            editing: widget.initial != null,
            onApply: _valid == null ? null : _apply,
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        onBack == null ? Spacing.md : Spacing.xxs,
        Spacing.xs,
        Spacing.md,
        Spacing.xxs,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: onBack,
              ),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.editing, required this.onApply});

  final bool editing;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Align(
          alignment: Alignment.centerRight,
          child: PrimaryButton(
            label: editing ? 'Update filter' : 'Add filter',
            icon: Icons.check,
            onPressed: onApply,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Step 1 — field
// -----------------------------------------------------------------------------

class _FieldStep extends StatefulWidget {
  const _FieldStep({required this.fields, required this.onPick});

  final List<FieldDefinition> fields;
  final ValueChanged<FieldDefinition> onPick;

  @override
  State<_FieldStep> createState() => _FieldStepState();
}

class _FieldStepState extends State<_FieldStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final fields = [
      for (final f in widget.fields)
        if (q.isEmpty || f.name.toLowerCase().contains(q)) f,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.fields.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              0,
              Spacing.sm,
              Spacing.xs,
            ),
            child: SearchField(
              hintText: 'Search fields',
              onChanged: (v) => setState(() => _query = v),
              onCleared: () => setState(() => _query = ''),
            ),
          ),
        Flexible(
          child: fields.isEmpty
              ? const _Hint('No fields match')
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  children: [
                    for (final f in fields)
                      _Row(
                        leading: Icon(fieldTypeIcon(f), size: 20),
                        label: f.name,
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => widget.onPick(f),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Step 2 — operator
// -----------------------------------------------------------------------------

class _OperatorStep extends StatelessWidget {
  const _OperatorStep({
    required this.field,
    required this.onPick,
    this.selected,
  });

  final FieldDefinition field;
  final FilterOp? selected;
  final ValueChanged<FilterOp> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      children: [
        for (final op in operatorsFor(field))
          _Row(
            label: operatorLabel(op, field),
            selected: op == selected,
            trailing: _valueless(op)
                ? (op == selected
                      ? Icon(Icons.check, size: 20, color: scheme.primary)
                      : null)
                : const Icon(Icons.chevron_right, size: 20),
            onTap: () => onPick(op),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Step 3 — value
// -----------------------------------------------------------------------------

class _ValueStep extends StatelessWidget {
  const _ValueStep({
    required this.field,
    required this.op,
    required this.operand,
    required this.referenceChoices,
    required this.onChanged,
    required this.onSubmit,
  });

  final FieldDefinition field;
  final FilterOp op;
  final Object? operand;
  final Map<String, String> referenceChoices;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ids = switch (operand) {
      final List<Object?> l => l.whereType<String>().toList(),
      _ => const <String>[],
    };
    return switch (field) {
      SingleSelectFieldDefinition(:final options) ||
      MultiSelectFieldDefinition(:final options) => _CheckList(
        entries: [
          for (final o in options)
            (
              id: o.id,
              label: o.label,
              color: o.color == null ? null : colorFromHex(o.color!),
            ),
        ],
        selected: ids,
        onChanged: onChanged,
        empty: 'This field has no options yet',
        pills: true,
      ),
      ReferenceFieldDefinition() => _CheckList(
        entries: [
          for (final MapEntry(:key, :value) in referenceChoices.entries)
            (id: key, label: value, color: null),
          // Picked earlier but gone from the target: still uncheckable.
          for (final id in ids)
            if (!referenceChoices.containsKey(id))
              (id: id, label: 'Missing item', color: null),
        ],
        selected: ids,
        onChanged: onChanged,
        empty: 'Nothing to link to yet',
        searchable: true,
      ),
      DateFieldDefinition() => _DateValue(
        day: switch (operand) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
        onChanged: (d) => onChanged(dateOperand(d)),
      ),
      NumberFieldDefinition() || AutoNumberFieldDefinition() => _TextValue(
        initial: switch (operand) {
          final num n => _plain(n),
          _ => '',
        },
        number: true,
        onChanged: (t) => onChanged(num.tryParse(t.trim())),
        onSubmit: onSubmit,
      ),
      _ => _TextValue(
        initial: operand is String ? operand as String : '',
        onChanged: onChanged,
        onSubmit: onSubmit,
      ),
    };
  }

  static String _plain(num n) =>
      n is double && n == n.truncateToDouble() && n.isFinite
      ? n.toInt().toString()
      : '$n';
}

class _TextValue extends StatefulWidget {
  const _TextValue({
    required this.initial,
    required this.onChanged,
    required this.onSubmit,
    this.number = false,
  });

  final String initial;
  final bool number;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  State<_TextValue> createState() => _TextValueState();
}

class _TextValueState extends State<_TextValue> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final invalid =
        widget.number &&
        text.isNotEmpty &&
        num.tryParse(text)?.isFinite != true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.xxs,
        Spacing.md,
        Spacing.md,
      ),
      child: MorkvaTextField(
        controller: _controller,
        autofocus: true,
        hint: widget.number ? 'Number' : 'Text',
        errorText: invalid ? 'Enter a number' : null,
        keyboardType: widget.number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        textInputAction: TextInputAction.done,
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
        onSubmitted: (_) => widget.onSubmit(),
      ),
    );
  }
}

class _DateValue extends StatelessWidget {
  const _DateValue({required this.day, required this.onChanged});

  final DateTime? day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = day;
    return SingleChildScrollView(
      child: CalendarDatePicker(
        initialDate: d == null ? null : DateTime(d.year, d.month, d.day),
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
        onDateChanged: onChanged,
      ),
    );
  }
}

typedef _Entry = ({String id, String label, Color? color});

/// A multi-check list; [selected] keeps the order things were checked in.
class _CheckList extends StatefulWidget {
  const _CheckList({
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.empty,
    this.pills = false,
    this.searchable = false,
  });

  final List<_Entry> entries;
  final List<String> selected;
  final ValueChanged<Object?> onChanged;
  final String empty;
  final bool pills;
  final bool searchable;

  @override
  State<_CheckList> createState() => _CheckListState();
}

class _CheckListState extends State<_CheckList> {
  String _query = '';

  void _toggle(String id) {
    final next = [...widget.selected];
    if (!next.remove(id)) next.add(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return _Hint(widget.empty);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final e in widget.entries)
        if (q.isEmpty || e.label.toLowerCase().contains(q)) e,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.searchable && widget.entries.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              0,
              Spacing.sm,
              Spacing.xs,
            ),
            child: SearchField(
              onChanged: (v) => setState(() => _query = v),
              onCleared: () => setState(() => _query = ''),
            ),
          ),
        Flexible(
          child: shown.isEmpty
              ? const _Hint('No matches')
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  children: [
                    for (final e in shown)
                      _Row(
                        leading: ExcludeSemantics(
                          child: Checkbox(
                            value: widget.selected.contains(e.id),
                            onChanged: (_) => _toggle(e.id),
                          ),
                        ),
                        label: e.label,
                        labelWidget: widget.pills
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: OptionPill(
                                  label: e.label,
                                  color: e.color,
                                ),
                              )
                            : null,
                        checked: widget.selected.contains(e.id),
                        onTap: () => _toggle(e.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Shared
// -----------------------------------------------------------------------------

/// A 44 px menu row with a hover/focus ink.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.labelWidget,
    this.leading,
    this.trailing,
    this.selected = false,
    this.checked,
  });

  final String label;
  final Widget? labelWidget;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool? checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: checked == null,
      checked: checked,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.smAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      IconTheme.merge(
                        data: IconThemeData(color: scheme.onSurfaceVariant),
                        child: leading!,
                      ),
                      const SizedBox(width: Spacing.sm),
                    ],
                    Expanded(
                      child:
                          labelWidget ??
                          Text(
                            label,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                    if (trailing != null)
                      IconTheme.merge(
                        data: IconThemeData(color: scheme.onSurfaceVariant),
                        child: trailing!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.xs,
        Spacing.md,
        Spacing.lg,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
