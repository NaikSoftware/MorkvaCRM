import 'package:equatable/equatable.dart';

import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the file/attachment field.
const String kFileFieldType = 'file';

/// A single stored attachment.
///
/// Holds only the metadata the domain needs to identify and validate a file;
/// the actual bytes live elsewhere (e.g. Google Drive), keyed by [id]. [name]
/// is the original filename (used for extension validation); [mimeType] and
/// [sizeBytes] are optional hints that may be unknown at attach time.
class FileAttachment extends Equatable {
  const FileAttachment({
    required this.id,
    required this.name,
    this.mimeType,
    this.sizeBytes,
  });

  /// Stable identifier of the stored file (e.g. the Drive file id).
  final String id;

  /// Original filename, including its extension.
  final String name;

  /// Optional MIME type (e.g. `image/png`).
  final String? mimeType;

  /// Optional size in bytes.
  final int? sizeBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (mimeType != null) 'mimeType': mimeType,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };

  factory FileAttachment.fromJson(Map<String, dynamic> json) => FileAttachment(
    id: json['id'] as String,
    name: json['name'] as String,
    mimeType: json['mimeType'] as String?,
    sizeBytes: json['sizeBytes'] as int?,
  );

  @override
  List<Object?> get props => [id, name, mimeType, sizeBytes];
}

/// A field holding one or more file attachments.
///
/// Follows the reference shape established by `TextFieldDefinition`: the
/// definition serializes its own config ([multiple], [allowedExtensions]),
/// parses/produces a matching [FileFieldValue], and validates its own rules.
class FileFieldDefinition extends FieldDefinition {
  const FileFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.multiple = false,
    this.allowedExtensions,
  });

  /// Whether more than one attachment may be stored.
  final bool multiple;

  /// Optional whitelist of allowed file extensions, lowercase and without the
  /// leading dot (e.g. `['png', 'jpg']`). When null, any extension is allowed.
  final List<String>? allowedExtensions;

  @override
  String get type => kFileFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory FileFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    final rawExtensions = json['allowedExtensions'] as List<dynamic>?;
    return FileFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      multiple: (json['multiple'] as bool?) ?? false,
      allowedExtensions: rawExtensions
          ?.map((e) => (e as String).toLowerCase())
          .toList(),
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    'multiple': multiple,
    if (allowedExtensions != null) 'allowedExtensions': allowedExtensions,
  };

  @override
  List<Object?> get configProps => [multiple, allowedExtensions];

  @override
  FieldValue emptyValue() => const FileFieldValue();

  @override
  FieldValue valueFromJson(Object? json) {
    if (json is! List) return const FileFieldValue();
    return FileFieldValue(
      json
          .map((e) => FileAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as FileFieldValue;
    final attachments = v.attachments;
    final errors = <ValidationError>[];
    if (!multiple && attachments.length > 1) {
      errors.add(
        ValidationError(
          fieldId: id,
          code: tooManyFiles,
          message: '$name allows only one file',
        ),
      );
    }
    final allowed = allowedExtensions;
    if (allowed != null) {
      for (final attachment in attachments) {
        final extension = _extensionOf(attachment.name);
        if (extension == null || !allowed.contains(extension)) {
          errors.add(
            ValidationError(
              fieldId: id,
              code: invalidExtension,
              message: '${attachment.name} has an unsupported type for $name',
            ),
          );
        }
      }
    }
    return errors;
  }

  /// Lowercase extension (without the dot) of [filename], or null when the
  /// name has no extension.
  static String? _extensionOf(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return null;
    return filename.substring(dot + 1).toLowerCase();
  }

  /// Validation code: more than one file on a single-file field.
  static const String tooManyFiles = 'too_many_files';

  /// Validation code: a file's extension is not in [allowedExtensions].
  static const String invalidExtension = 'invalid_extension';
}

/// The value of a [FileFieldDefinition]: an ordered list of attachments.
class FileFieldValue extends FieldValue {
  const FileFieldValue([this.attachments = const []]);

  final List<FileAttachment> attachments;

  @override
  bool get isEmpty => attachments.isEmpty;

  @override
  Object? toJson() => attachments.map((a) => a.toJson()).toList();

  @override
  List<Object?> get props => [attachments];
}
