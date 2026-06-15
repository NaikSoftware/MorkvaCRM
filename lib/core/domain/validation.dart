import 'package:equatable/equatable.dart';

/// A single validation failure for a field value.
///
/// [code] is a stable, machine-readable identifier (e.g. `required`,
/// `out_of_range`) the UI can branch on or localize; [message] is a
/// human-readable default. [fieldId] identifies the offending field.
class ValidationError extends Equatable {
  const ValidationError({
    required this.fieldId,
    required this.code,
    required this.message,
  });

  final String fieldId;
  final String code;
  final String message;

  /// Common, type-agnostic codes. Field types may define additional codes.
  static const String requiredCode = 'required';
  static const String wrongType = 'wrong_type';
  static const String outOfRange = 'out_of_range';
  static const String tooLong = 'too_long';
  static const String invalidOption = 'invalid_option';
  static const String invalidReference = 'invalid_reference';

  @override
  List<Object?> get props => [fieldId, code, message];

  @override
  String toString() => 'ValidationError($fieldId, $code: $message)';
}

/// The structured outcome of validating one or more field values.
class ValidationResult extends Equatable {
  const ValidationResult(this.errors);

  const ValidationResult.valid() : errors = const [];

  final List<ValidationError> errors;

  bool get isValid => errors.isEmpty;

  /// Errors for a specific field id.
  List<ValidationError> forField(String fieldId) =>
      errors.where((e) => e.fieldId == fieldId).toList();

  ValidationResult merge(ValidationResult other) =>
      ValidationResult([...errors, ...other.errors]);

  @override
  List<Object?> get props => [errors];

  @override
  String toString() =>
      isValid ? 'ValidationResult.valid' : 'ValidationResult($errors)';
}
