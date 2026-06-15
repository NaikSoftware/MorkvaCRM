import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the text field.
const String kTextFieldType = 'text';

/// A free-text field, single- or multi-line.
///
/// This type is the reference implementation for the field-type system: every
/// other field type follows the same shape — a [FieldDefinition] subclass that
/// serializes its own config, parses/produces a matching [FieldValue], and
/// validates its own rules; plus a [FieldValue] subclass that reports emptiness
/// and serializes itself.
class TextFieldDefinition extends FieldDefinition {
  const TextFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.multiline = false,
    this.maxLength,
  });

  /// Whether the editor should allow line breaks. Pure UI hint; not validated.
  final bool multiline;

  /// Optional maximum character length.
  final int? maxLength;

  @override
  String get type => kTextFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory TextFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return TextFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      multiline: (json['multiline'] as bool?) ?? false,
      maxLength: json['maxLength'] as int?,
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
        'multiline': multiline,
        if (maxLength != null) 'maxLength': maxLength,
      };

  @override
  List<Object?> get configProps => [multiline, maxLength];

  @override
  FieldValue emptyValue() => const TextFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) => TextFieldValue(json as String?);

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as TextFieldValue;
    final text = v.text;
    final errors = <ValidationError>[];
    if (text != null && maxLength != null && text.length > maxLength!) {
      errors.add(ValidationError(
        fieldId: id,
        code: ValidationError.tooLong,
        message: '$name must be at most $maxLength characters',
      ));
    }
    return errors;
  }
}

/// The value of a [TextFieldDefinition]: an optional string.
class TextFieldValue extends FieldValue {
  const TextFieldValue(this.text);

  final String? text;

  @override
  bool get isEmpty => text == null || text!.isEmpty;

  @override
  Object? toJson() => text;

  @override
  List<Object?> get props => [text];
}
