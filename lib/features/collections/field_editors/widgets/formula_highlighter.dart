import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';

/// What a stretch of formula text is, for coloring.
enum FormulaTokenKind {
  field,
  unknownField,
  function,
  unknownName,
  keyword,
  string,
  number,
  operator,
  plain,
}

/// A colored stretch of formula source: [start] inclusive, [end] exclusive.
typedef FormulaToken = ({int start, int end, FormulaTokenKind kind});

final _name = RegExp(r'[A-Za-z0-9_]');
final _digit = RegExp(r'[0-9.]');
final _ws = RegExp(r'\s');

/// Splits [source] into colorable tokens without ever failing: half-typed
/// input (an open brace or quote) runs to the end of the text.
List<FormulaToken> formulaTokens(String source, List<FieldDefinition> fields) {
  final names = {
    for (final f in fields) ...[f.id, f.name.trim().toLowerCase()],
  };
  final tokens = <FormulaToken>[];
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final start = i;
    if (_ws.hasMatch(c)) {
      i++;
      continue;
    }
    FormulaTokenKind kind;
    if (c == '{') {
      final close = source.indexOf('}', i);
      i = close < 0 ? source.length : close + 1;
      final inner = source.substring(start + 1, close < 0 ? i : i - 1).trim();
      kind =
          close >= 0 &&
              (names.contains(inner) || names.contains(inner.toLowerCase()))
          ? FormulaTokenKind.field
          : FormulaTokenKind.unknownField;
    } else if ('"“”'.contains(c)) {
      i++;
      while (i < source.length && !'"“”'.contains(source[i])) {
        i++;
      }
      if (i < source.length) i++;
      kind = FormulaTokenKind.string;
    } else if (_digit.hasMatch(c) &&
        (c != '.' ||
            i + 1 < source.length && RegExp('[0-9]').hasMatch(source[i + 1]))) {
      while (i < source.length && _digit.hasMatch(source[i])) {
        i++;
      }
      kind = FormulaTokenKind.number;
    } else if (_name.hasMatch(c)) {
      while (i < source.length && _name.hasMatch(source[i])) {
        i++;
      }
      final word = source.substring(start, i).toUpperCase();
      kind = formulaFunctions.containsKey(word)
          ? FormulaTokenKind.function
          : const {'TRUE', 'FALSE', 'YES', 'NO'}.contains(word)
          ? FormulaTokenKind.keyword
          : FormulaTokenKind.unknownName;
    } else if ('+-*/&=<>!×÷'.contains(c)) {
      i++;
      kind = FormulaTokenKind.operator;
    } else {
      i++;
      kind = FormulaTokenKind.plain;
    }
    tokens.add((start: start, end: i, kind: kind));
  }
  return tokens;
}

/// A text controller that colors formula syntax: field references as
/// tinted chips, functions, text, numbers and operators — and unknown names
/// with a wavy error underline.
class FormulaEditingController extends TextEditingController {
  FormulaEditingController({super.text, required this.fields});

  /// The fields `{…}` may refer to.
  List<FieldDefinition> fields;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Mid-IME composition: keep the platform's underline.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final base = style ?? const TextStyle();
    TextStyle styleOf(FormulaTokenKind kind) => switch (kind) {
      FormulaTokenKind.field => base.copyWith(
        color: scheme.onPrimaryContainer,
        backgroundColor: scheme.primaryContainer,
        fontWeight: FontWeight.w600,
      ),
      FormulaTokenKind.unknownField ||
      FormulaTokenKind.unknownName => base.copyWith(
        color: scheme.error,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.wavy,
        decorationColor: scheme.error,
      ),
      FormulaTokenKind.function => base.copyWith(
        color: semantic.primaryText,
        fontWeight: FontWeight.w700,
      ),
      FormulaTokenKind.keyword => base.copyWith(
        color: semantic.info,
        fontWeight: FontWeight.w600,
      ),
      FormulaTokenKind.string => base.copyWith(color: semantic.success),
      FormulaTokenKind.number => base.copyWith(color: semantic.info),
      FormulaTokenKind.operator => base.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      FormulaTokenKind.plain => base,
    };
    final source = text;
    final spans = <TextSpan>[];
    var at = 0;
    for (final t in formulaTokens(source, fields)) {
      if (t.start > at) {
        spans.add(TextSpan(text: source.substring(at, t.start)));
      }
      spans.add(
        TextSpan(
          text: source.substring(t.start, t.end),
          style: styleOf(t.kind),
        ),
      );
      at = t.end;
    }
    if (at < source.length) spans.add(TextSpan(text: source.substring(at)));
    return TextSpan(style: base, children: spans);
  }
}
