import 'collection.dart';
import 'field_definition.dart';
import 'types/date_field.dart';
import 'types/file_field.dart';
import 'types/multi_select_field.dart';
import 'types/reference_field.dart';
import 'types/single_select_field.dart';

/// What a [SchemaIssue] is about; harness error codes key on it.
enum SchemaIssueCode {
  /// The collection name is blank.
  emptyCollectionName,

  /// A field name is blank.
  emptyFieldName,

  /// Two fields share a name (trimmed, case-insensitive).
  duplicateFieldName,

  /// A saved field changed its type (or, in strict mode, its shape).
  typeLocked,

  /// A select field has no options.
  noOptions,

  /// A reference field has no target, or (with known collection ids) a
  /// target that does not exist.
  noTarget,
}

/// A schema problem. [blocking] problems must be fixed before the schema is
/// saved; the others are warnings about a valid but unfinished schema.
class SchemaIssue {
  const SchemaIssue({
    required this.code,
    required this.message,
    required this.blocking,
    this.fieldId,
    this.fieldName,
  });

  final SchemaIssueCode code;

  /// The problem in English (the harness reads it; the UI words [code] with
  /// [fieldName]).
  final String message;

  /// Whether this problem blocks save.
  final bool blocking;

  /// The field the problem belongs to, or null for collection-level problems.
  final String? fieldId;

  /// That field's name as [message] quotes it (the saved name for
  /// [SchemaIssueCode.typeLocked]).
  final String? fieldName;
}

/// The result of [validateCollectionSchema]: the blocking and non-blocking
/// issues.
class SchemaValidation {
  const SchemaValidation(this.issues);

  /// All issues, blocking and non-blocking.
  final List<SchemaIssue> issues;

  /// The blocking issues only.
  List<SchemaIssue> get blocking =>
      issues.where((i) => i.blocking).toList(growable: false);

  /// The non-blocking warnings only.
  List<SchemaIssue> get warnings =>
      issues.where((i) => !i.blocking).toList(growable: false);

  /// Whether any blocking issue exists (i.e. save is disallowed).
  bool get hasBlocking => issues.any((i) => i.blocking);
}

/// Checks [draft] before it is saved; the schema editor and the assistant
/// harness share these rules.
///
/// Always blocking: a blank collection name, blank or duplicate
/// (case-insensitive) field names, and a field of [saved] whose type changed
/// (its type is locked once saved).
///
/// [strict] is for writers that cannot ask the user to finish later (the
/// harness): a select field without options and a reference field without an
/// existing target block instead of warn, and flipping `multiple` on a
/// reference or file field or `includeTime` on a date field counts as a type
/// change. A reference target exists when it is [draft] itself or one of
/// [collectionIds]; without [collectionIds] only an empty target is flagged.
// shortcut: a changed option id is not detected here (it reads the same as
// removing one option and adding another); the harness planner mints option
// ids itself and rejects it there.
SchemaValidation validateCollectionSchema(
  Collection draft, {
  Collection? saved,
  Set<String>? collectionIds,
  bool strict = false,
}) {
  final issues = <SchemaIssue>[];

  if (draft.name.trim().isEmpty) {
    issues.add(
      const SchemaIssue(
        code: SchemaIssueCode.emptyCollectionName,
        message: 'Collection name is required',
        blocking: true,
      ),
    );
  }

  final seen = <String>{};
  for (final field in draft.fields) {
    final key = field.name.trim().toLowerCase();
    if (key.isEmpty) {
      issues.add(
        SchemaIssue(
          code: SchemaIssueCode.emptyFieldName,
          message: 'Field name is required',
          blocking: true,
          fieldId: field.id,
        ),
      );
    } else if (!seen.add(key)) {
      issues.add(
        SchemaIssue(
          code: SchemaIssueCode.duplicateFieldName,
          message: 'Duplicate field name "${field.name.trim()}"',
          blocking: true,
          fieldId: field.id,
          fieldName: field.name.trim(),
        ),
      );
    }
  }

  if (saved != null) {
    for (final field in draft.fields) {
      final before = saved.fieldById(field.id);
      if (before == null) continue;
      final change = _lockedChange(before, field, strict: strict);
      if (change == null) continue;
      issues.add(
        SchemaIssue(
          code: SchemaIssueCode.typeLocked,
          message:
              'The $change of "${before.name}" is locked after save; '
              'add a new field instead',
          blocking: true,
          fieldId: field.id,
          fieldName: before.name,
        ),
      );
    }
  }

  for (final field in draft.fields) {
    final noOptions = switch (field) {
      SingleSelectFieldDefinition(:final options) ||
      MultiSelectFieldDefinition(:final options) => options.isEmpty,
      _ => false,
    };
    if (noOptions) {
      issues.add(
        SchemaIssue(
          code: SchemaIssueCode.noOptions,
          message: '"${field.name}" has no options yet',
          blocking: strict,
          fieldId: field.id,
          fieldName: field.name,
        ),
      );
    } else if (field is ReferenceFieldDefinition) {
      final target = field.targetCollectionId;
      final message = target.isEmpty
          ? '"${field.name}" has no target collection yet'
          : collectionIds != null &&
                target != draft.id &&
                !collectionIds.contains(target)
          ? '"${field.name}" links to a collection that does not exist'
          : null;
      if (message != null) {
        issues.add(
          SchemaIssue(
            code: SchemaIssueCode.noTarget,
            message: message,
            blocking: strict,
            fieldId: field.id,
            fieldName: field.name,
          ),
        );
      }
    }
  }

  return SchemaValidation(issues);
}

/// What locked part of [before] [after] changes ("type", "multiple" …), or
/// null when nothing locked changed.
String? _lockedChange(
  FieldDefinition before,
  FieldDefinition after, {
  required bool strict,
}) {
  if (before.type != after.type) return 'type';
  if (!strict) return null;
  return switch ((before, after)) {
    (
      ReferenceFieldDefinition(multiple: final a),
      ReferenceFieldDefinition(multiple: final b),
    ) ||
    (
      FileFieldDefinition(multiple: final a),
      FileFieldDefinition(multiple: final b),
    ) when a != b => '"multiple" setting',
    (
      DateFieldDefinition(includeTime: final a),
      DateFieldDefinition(includeTime: final b),
    )
        when a != b =>
      '"include time" setting',
    _ => null,
  };
}
