import '../field_definition.dart';
import '../field_value.dart';
import '../types/auto_number_field.dart';
import '../types/boolean_field.dart';
import '../types/calculated_field.dart';
import '../types/date_field.dart';
import '../types/file_field.dart';
import '../types/multi_select_field.dart';
import '../types/number_field.dart';
import '../types/reference_field.dart';
import '../types/single_select_field.dart';
import '../types/text_field.dart';

/// The calendar day [value] falls on, as a local-midnight [DateTime].
///
/// A field with time stores an instant, so its day is the viewer's local day.
/// A date-only field stores the calendar date as UTC midnight, so its day is
/// read from the UTC components (converting would shift it a day back in
/// zones west of UTC).
DateTime calendarDayOf(DateFieldDefinition field, DateTime value) {
  final d = field.includeTime ? value.toLocal() : value.toUtc();
  return DateTime(d.year, d.month, d.day);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// [n] without float noise: integers as is, other doubles rounded to 12
/// significant digits (0.1 + 0.2 shows as 0.3).
String _plainNumber(num n) {
  if (n is int) return '$n';
  if (n == n.truncateToDouble()) return n.toStringAsFixed(0);
  return '${double.parse(n.toStringAsPrecision(12))}';
}

/// [text] with ',' between thousands of its integer part ("48250.5" →
/// "48,250.5"). Exponent forms are left as they are.
// shortcut: en-style separators only; switch to locale-aware formatting when
// the app gets a locale setting.
String _grouped(String text) {
  if (text.contains('e')) return text;
  final negative = text.startsWith('-');
  final body = negative ? text.substring(1) : text;
  final dot = body.indexOf('.');
  final whole = dot < 0 ? body : body.substring(0, dot);
  final fraction = dot < 0 ? '' : body.substring(dot);
  final out = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '${negative ? '-' : ''}$out$fraction';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// The one display formatter for a field value (cards, rows, detail sheet).
/// Empty values format as `''`.
///
/// [referenceLabels] maps referenced object ids to their labels; when some id
/// has no label the value formats as a count ("2 linked").
String formatFieldValue(
  FieldDefinition field,
  FieldValue value, {
  Map<String, String> referenceLabels = const {},
}) {
  if (value.isEmpty) return '';
  switch ((field, value)) {
    case (TextFieldDefinition(), TextFieldValue(:final text)):
      return text ?? '';
    case (
      NumberFieldDefinition(:final decimalPlaces, :final unitLabel),
      NumberFieldValue(value: final number?),
    ):
      if (number.isNaN) return '';
      if (number.isInfinite) return number > 0 ? '∞' : '-∞';
      final digits = _grouped(
        decimalPlaces != null
            ? number.toStringAsFixed(decimalPlaces)
            : _plainNumber(number),
      );
      return unitLabel == null || unitLabel.isEmpty
          ? digits
          : '$digits $unitLabel';
    case (
      AutoNumberFieldDefinition(:final prefix, :final padding),
      AutoNumberFieldValue(sequence: final seq?),
    ):
      return '${prefix ?? ''}${seq.toString().padLeft(padding ?? 0, '0')}';
    case (DateFieldDefinition(), DateFieldValue(value: final dt?)):
      final f = field as DateFieldDefinition;
      final day = calendarDayOf(f, dt);
      final date = '${_months[day.month - 1]} ${day.day}, ${day.year}';
      if (!f.includeTime) return date;
      final local = dt.toLocal();
      return '$date ${_two(local.hour)}:${_two(local.minute)}';
    case (BooleanFieldDefinition(), BooleanFieldValue(value: final b?)):
      return b ? 'Yes' : 'No';
    case (
      SingleSelectFieldDefinition(:final options),
      SingleSelectFieldValue(:final optionId),
    ):
      return options.where((o) => o.id == optionId).firstOrNull?.label ?? '';
    case (
      MultiSelectFieldDefinition(:final options),
      MultiSelectFieldValue(:final optionIds),
    ):
      return [
        for (final o in options)
          if (optionIds.contains(o.id)) o.label,
      ].join(', ');
    case (ReferenceFieldDefinition(), ReferenceFieldValue(:final objectIds)):
      final labels = objectIds.map((id) => referenceLabels[id]).toList();
      if (labels.contains(null)) return '${objectIds.length} linked';
      return labels.join(', ');
    case (FileFieldDefinition(), FileFieldValue(:final attachments)):
      return attachments.map((a) => a.name).join(', ');
    case (CalculatedFieldDefinition(), CalculatedFieldValue(:final cached)):
      return '$cached';
  }
  return value.toJson()?.toString() ?? '';
}
