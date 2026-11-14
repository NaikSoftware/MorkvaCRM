import '../core/domain/domain.dart';
import '../core/import/trello/trello_mapper.dart';
import 'app_localizations.dart';

/// Words for what `lib/core` returns as structured values (enums, codes,
/// names), so every screen words them the same way.
extension CoreLabels on AppLocalizations {
  /// The words core writes into display text itself; the app sets
  /// [CoreWords.current] to these when the locale resolves.
  CoreWords get coreWords => CoreWords(
    untitled: commonUntitled,
    yes: coreYes,
    no: coreNo,
    linkedCount: coreLinkedCount,
    noValueGroup: coreNoValueGroup,
    weekOf: coreWeekOf,
    defaultViewName: coreDefaultViewName,
  );

  /// "Number", "Yes / No"….
  String formulaTypeLabel(FormulaType type) => switch (type) {
    FormulaType.number => coreFormulaTypeNumber,
    FormulaType.text => coreFormulaTypeText,
    FormulaType.boolean => coreFormulaTypeBoolean,
    FormulaType.date => coreFormulaTypeDate,
  };

  /// "Count", "Sum"….
  String aggregateOpLabel(AggregateOp op) => switch (op) {
    AggregateOp.count => coreAggregateOpCount,
    AggregateOp.sum => coreAggregateOpSum,
    AggregateOp.average => coreAggregateOpAverage,
    AggregateOp.min => coreAggregateOpMin,
    AggregateOp.max => coreAggregateOpMax,
  };

  /// `IF(condition, then, else)`, with the argument names translated.
  String formulaUsage(FormulaFunction f) => formulaFunctionUsage(f.name);

  /// What [f] does, in a sentence.
  String formulaSummary(FormulaFunction f) => formulaFunctionSummary(f.name);

  /// [error] in a sentence.
  String formulaErrorMessage(FormulaError error) {
    final text = error.text;
    String type(FormulaType? t) => t == null ? '' : formulaTypeLabel(t);
    return switch (error.code) {
      FormulaErrorCode.empty => formulaErrorEmpty,
      FormulaErrorCode.notANumber => formulaErrorNotANumber(text),
      FormulaErrorCode.unclosedText => formulaErrorUnclosedText,
      FormulaErrorCode.unclosedField => formulaErrorUnclosedField('}'),
      FormulaErrorCode.unexpected => formulaErrorUnexpected(text),
      FormulaErrorCode.noSuchField => formulaErrorNoSuchField(text),
      FormulaErrorCode.ownField => formulaErrorOwnField,
      FormulaErrorCode.fieldNotUsable => formulaErrorFieldNotUsable(text),
      FormulaErrorCode.fieldWithoutBraces => formulaErrorFieldWithoutBraces(
        '{$text}',
      ),
      FormulaErrorCode.unknownFunction => formulaErrorUnknownFunction(text),
      FormulaErrorCode.wrongArguments => formulaErrorWrongArguments(
        formulaFunctionUsage(text),
      ),
      FormulaErrorCode.unclosedCall => formulaErrorUnclosedCall(text),
      FormulaErrorCode.expectsNumbers => formulaErrorExpectsNumbers(text),
      FormulaErrorCode.expectsBooleans => formulaErrorExpectsBooleans(text),
      FormulaErrorCode.expectsText => formulaErrorExpectsText(text),
      FormulaErrorCode.expectsDate => formulaErrorExpectsDate(text),
      FormulaErrorCode.needsCondition => formulaErrorNeedsCondition(text),
      FormulaErrorCode.branchTypesDiffer => formulaErrorBranchTypesDiffer(
        text,
        type(error.left),
        type(error.right),
      ),
      FormulaErrorCode.unclosedBracket => formulaErrorUnclosedBracket,
      FormulaErrorCode.endsEarly => formulaErrorEndsEarly,
      FormulaErrorCode.negateNeedsNumber => formulaErrorNegateNeedsNumber,
      FormulaErrorCode.joinWithAmpersand => formulaErrorJoinWithAmpersand,
      FormulaErrorCode.cannotCombine => formulaErrorCannotCombine(
        text,
        type(error.left),
        type(error.right),
      ),
    };
  }

  /// The permission a module asks for with [cap] (a `kCapabilityCopy` key),
  /// or [cap] itself when unknown.
  String capabilityTitle(String cap) => switch (cap) {
    'schema:read' => capabilitySchemaReadTitle,
    'data:read' => capabilityDataReadTitle,
    'data:write' => capabilityDataWriteTitle,
    'data:delete' => capabilityDataDeleteTitle,
    'schema:write' => capabilitySchemaWriteTitle,
    'schema:delete' => capabilitySchemaDeleteTitle,
    'views:write' => capabilityViewsWriteTitle,
    'ui:navigate' => capabilityUiNavigateTitle,
    _ => cap,
  };

  /// What [cap] lets a module do, or '' when unknown.
  String capabilityExplanation(String cap) => switch (cap) {
    'schema:read' => capabilitySchemaReadExplanation,
    'data:read' => capabilityDataReadExplanation,
    'data:write' => capabilityDataWriteExplanation,
    'data:delete' => capabilityDataDeleteExplanation,
    'schema:write' => capabilitySchemaWriteExplanation,
    'schema:delete' => capabilitySchemaDeleteExplanation,
    'views:write' => capabilityViewsWriteExplanation,
    'ui:navigate' => capabilityUiNavigateExplanation,
    _ => '',
  };

  /// [issue] in a sentence. The editor validates non-strictly, where only
  /// these codes block and only a type change locks; the rest (strict, for
  /// the harness) keep their English message.
  String schemaIssueMessage(SchemaIssue issue) {
    final name = issue.fieldName ?? '';
    return switch (issue.code) {
      SchemaIssueCode.emptyCollectionName => coreSchemaCollectionNameRequired,
      SchemaIssueCode.emptyFieldName => coreSchemaFieldNameRequired,
      SchemaIssueCode.duplicateFieldName => coreSchemaDuplicateFieldName(name),
      SchemaIssueCode.typeLocked => coreSchemaTypeLocked(name),
      SchemaIssueCode.noOptions || SchemaIssueCode.noTarget => issue.message,
    };
  }

  /// [error] (from [field]'s rules) in a sentence; an unknown code keeps its
  /// English message.
  String validationMessage(FieldDefinition field, ValidationError error) {
    final name = field.name;
    final subject = error.subject ?? '';
    final date = field is DateFieldDefinition;
    // As core words them: an ISO instant, a plain number.
    String bound(Object? b) => b is DateTime ? b.toIso8601String() : '$b';
    return switch ((error.code, error.minimum, error.maximum)) {
      (ValidationError.requiredCode, _, _) => validationRequired(name),
      (ValidationError.outOfRange, final min?, _) =>
        date
            ? validationDateMin(name, bound(min))
            : validationNumberMin(name, bound(min)),
      (ValidationError.outOfRange, _, final max?) =>
        date
            ? validationDateMax(name, bound(max))
            : validationNumberMax(name, bound(max)),
      (ValidationError.tooLong, _, final int max) => validationTooLong(
        name,
        max,
      ),
      (FileFieldDefinition.tooManyFiles, _, _) => validationOneFile(name),
      (FileFieldDefinition.invalidExtension, _, _) => validationFileType(
        subject,
        name,
      ),
      (ValidationError.invalidOption, _, _) =>
        field is MultiSelectFieldDefinition
            ? validationInvalidOption(subject, name)
            : validationNoOption(name, subject),
      (ValidationError.invalidReference, _, _) => validationBlankReference(
        name,
      ),
      (kTooManyReferencesCode, _, _) => validationOneReference(name),
      _ => error.message,
    };
  }

  /// The names a Trello import gives what it creates.
  TrelloNames get trelloNames => TrelloNames(
    board: coreTrelloBoard,
    untitledCard: coreTrelloUntitledCard,
    untitledList: coreTrelloUntitledList,
    untitledField: coreTrelloUntitledField,
    untitledOption: coreTrelloUntitledOption,
    untitledItem: coreTrelloUntitledItem,
    noList: coreTrelloNoList,
    label: coreTrelloLabel,
    member: coreTrelloMember,
    name: coreTrelloName,
    description: coreTrelloDescription,
    list: coreTrelloList,
    labels: coreTrelloLabels,
    members: coreTrelloMembers,
    start: coreTrelloStart,
    due: coreTrelloDue,
    dueDone: coreTrelloDueDone,
    attachments: coreTrelloAttachments,
    trelloLink: coreTrelloLink,
    archived: coreTrelloArchived,
    boardView: coreTrelloBoardView,
    allView: coreDefaultViewName,
    item: coreTrelloItem,
    done: coreTrelloDone,
    checklist: coreTrelloChecklist,
    card: coreTrelloCard,
    comment: coreTrelloComment,
    author: coreTrelloAuthor,
    date: coreTrelloDate,
    checklistItems: coreTrelloChecklistItems,
    comments: coreTrelloComments,
    trelloField: (field, n) => n == 2
        ? coreTrelloFieldRenamed(field)
        : coreTrelloFieldRenamedNumbered(field, n - 1),
    color: (base, shade) {
      final color =
          _trelloColor(base) ??
          // Not a Trello colour: shown as is, capitalized.
          '${base[0].toUpperCase()}${base.substring(1)}';
      return shade == null ? color : coreTrelloColorShade(color, shade);
    },
  );

  String? _trelloColor(String base) => switch (base) {
    'green' => coreTrelloColorGreen,
    'yellow' => coreTrelloColorYellow,
    'orange' => coreTrelloColorOrange,
    'red' => coreTrelloColorRed,
    'purple' => coreTrelloColorPurple,
    'blue' => coreTrelloColorBlue,
    'sky' => coreTrelloColorSky,
    'lime' => coreTrelloColorLime,
    'pink' => coreTrelloColorPink,
    'black' => coreTrelloColorBlack,
    _ => null,
  };
}
