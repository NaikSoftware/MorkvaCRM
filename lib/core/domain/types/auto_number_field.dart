import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the auto-number field.
const String kAutoNumberFieldType = 'auto_number';

/// A field whose value is an automatically assigned sequence number.
///
/// Numbers are assigned when an object is first saved (see
/// `allocateSequences`), starting at [start]; a per-field counter keeps them
/// unique and never reuses one.
class AutoNumberFieldDefinition extends FieldDefinition {
  const AutoNumberFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.prefix,
    this.padding,
    this.start = 1,
  });

  /// The first number handed out.
  final int start;

  /// Optional string prepended when the number is rendered (e.g. `INV-`).
  /// Display/formatting hint only; not stored in the numeric value.
  final String? prefix;

  /// Optional zero-pad width for the rendered number (e.g. `5` → `00042`).
  /// Display/formatting hint only.
  final int? padding;

  @override
  String get type => kAutoNumberFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory AutoNumberFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return AutoNumberFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      prefix: json['prefix'] as String?,
      padding: (json['padding'] as num?)?.toInt(),
      start: (json['start'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    if (prefix != null) 'prefix': prefix,
    if (padding != null) 'padding': padding,
    if (start != 1) 'start': start,
  };

  @override
  List<Object?> get configProps => [prefix, padding, start];

  @override
  FieldValue emptyValue() => const AutoNumberFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) =>
      // Tolerate a JSON double (e.g. 42.0) from non-Dart writers; never throw.
      AutoNumberFieldValue(json is num ? json.toInt() : null);

  /// No user-facing validation: the value is assigned by the engine (Epic 6),
  /// never entered or edited by a user.
  @override
  List<ValidationError> validateValue(FieldValue value) =>
      const <ValidationError>[];
}

/// The value of an [AutoNumberFieldDefinition]: an optional sequence number.
class AutoNumberFieldValue extends FieldValue {
  const AutoNumberFieldValue(this.sequence);

  /// The assigned sequence number, or null until the engine assigns one.
  final int? sequence;

  @override
  bool get isEmpty => sequence == null;

  @override
  Object? toJson() => sequence;

  @override
  List<Object?> get props => [sequence];
}
