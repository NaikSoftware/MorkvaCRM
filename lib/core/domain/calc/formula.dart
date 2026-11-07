import 'dart:math' as math;

import '../field_definition.dart';
import '../types/auto_number_field.dart';
import '../types/boolean_field.dart';
import '../types/calculated_field.dart';
import '../types/date_field.dart';
import '../types/multi_select_field.dart';
import '../types/number_field.dart';
import '../types/single_select_field.dart';
import '../types/text_field.dart';

/// The static type of a formula (sub)expression.
enum FormulaType {
  number,
  text,
  boolean,
  date;

  /// The field type discriminator a result of this type is shown as.
  String get fieldType => switch (this) {
    number => kNumberFieldType,
    text => kTextFieldType,
    boolean => kBooleanFieldType,
    date => kDateFieldType,
  };

  /// Human name for messages ("Number", "Yes / No").
  String get label => switch (this) {
    number => 'Number',
    text => 'Text',
    boolean => 'Yes / No',
    date => 'Date',
  };

  static FormulaType? ofFieldType(String type) => switch (type) {
    kNumberFieldType => number,
    kTextFieldType => text,
    kBooleanFieldType => boolean,
    kDateFieldType => date,
    _ => null,
  };
}

/// What a field reads as inside a formula, or null when it can't be used.
FormulaType? formulaTypeOfField(FieldDefinition field) => switch (field) {
  NumberFieldDefinition() || AutoNumberFieldDefinition() => FormulaType.number,
  TextFieldDefinition() ||
  SingleSelectFieldDefinition() ||
  MultiSelectFieldDefinition() => FormulaType.text,
  BooleanFieldDefinition() => FormulaType.boolean,
  DateFieldDefinition() => FormulaType.date,
  CalculatedFieldDefinition(:final declaredOutputType) =>
    FormulaType.ofFieldType(declaredOutputType),
  _ => null,
};

/// A parse or type error at [offset] (a character index of the source).
class FormulaError {
  const FormulaError(this.message, this.offset);

  final String message;
  final int offset;

  @override
  String toString() => 'FormulaError($message @ $offset)';
}

/// Reads a field's current value for evaluation: a [num], [String], [bool],
/// a UTC-midnight [DateTime] (a calendar day), or null when blank.
typedef FormulaReader = Object? Function(String fieldId);

/// A parsed, type-checked formula.
class CompiledFormula {
  CompiledFormula._(this._root, this.type, this.fieldIds, this._readsBlanks);

  final _Expr _root;

  /// The result type.
  final FormulaType type;

  /// The ids of the fields the formula reads.
  final Set<String> fieldIds;

  /// The formula asks about blanks itself (ISBLANK), so all-blank inputs
  /// still evaluate.
  final bool _readsBlanks;

  /// Evaluates against [read]. Blank (null) when every field it reads is
  /// blank, on division by zero, and on values of an unexpected type.
  /// [today] is TODAY()'s calendar day.
  Object? evaluate(FormulaReader read, {DateTime? today}) {
    final values = {for (final id in fieldIds) id: read(id)};
    if (!_readsBlanks &&
        fieldIds.isNotEmpty &&
        values.values.every((v) => v == null)) {
      return null;
    }
    final now = today ?? DateTime.now();
    try {
      final result = _root.eval(
        _Env((id) => values[id], DateTime.utc(now.year, now.month, now.day)),
      );
      if (result is double && (result.isNaN || result.isInfinite)) return null;
      return result;
    } on _EvalFailure {
      return null;
    }
  }
}

/// The result of [compileFormula]: a formula, or the first error.
typedef FormulaCompileResult = ({
  CompiledFormula? formula,
  FormulaError? error,
});

/// Parses and type-checks [source] against [fields]. A `{token}` refers to a
/// field by id, else by name (case-insensitive). [selfId] is the field being
/// defined (it can't read itself).
FormulaCompileResult compileFormula(
  String source,
  List<FieldDefinition> fields, {
  String? selfId,
}) {
  if (source.trim().isEmpty) {
    return (formula: null, error: const FormulaError('Enter a formula', 0));
  }
  try {
    final parser = _Parser(source, fields, selfId);
    final root = parser.parse();
    final type = root.check();
    return (
      formula: CompiledFormula._(
        root,
        type,
        parser.fieldIds,
        parser.readsBlanks,
      ),
      error: null,
    );
  } on FormulaError catch (e) {
    return (formula: null, error: e);
  }
}

final _braced = RegExp(r'\{([^{}]*)\}');

FieldDefinition? _resolve(String token, List<FieldDefinition> fields) {
  final t = token.trim();
  for (final f in fields) {
    if (f.id == t) return f;
  }
  final lower = t.toLowerCase();
  for (final f in fields) {
    if (f.name.trim().toLowerCase() == lower) return f;
  }
  return null;
}

/// [stored] with `{fieldId}` tokens shown as `{Field name}`.
String formulaToDisplay(String stored, List<FieldDefinition> fields) =>
    stored.replaceAllMapped(_braced, (m) {
      final f = _resolve(m[1]!, fields);
      return f == null ? m[0]! : '{${f.name}}';
    });

/// [display] with `{Field name}` tokens stored as `{fieldId}`.
String formulaToStorage(String display, List<FieldDefinition> fields) =>
    display.replaceAllMapped(_braced, (m) {
      final f = _resolve(m[1]!, fields);
      return f == null ? m[0]! : '{${f.id}}';
    });

/// The ids of the fields [stored] refers to (resolvable tokens only).
Set<String> formulaFieldIds(String stored, List<FieldDefinition> fields) => {
  for (final m in _braced.allMatches(stored)) ?_resolve(m[1]!, fields)?.id,
};

// ---------------------------------------------------------------------------
// Functions
// ---------------------------------------------------------------------------

/// A built-in function: its signature check and its implementation.
class FormulaFunction {
  const FormulaFunction({
    required this.name,
    required this.usage,
    required this.summary,
    required this.minArgs,
    this.maxArgs,
    required this.check,
    required this.apply,
  });

  final String name;

  /// e.g. `ROUND(number, digits)`.
  final String usage;
  final String summary;
  final int minArgs;

  /// null = any number.
  final int? maxArgs;

  /// Returns the result type for the argument types, or throws a message.
  final FormulaType Function(List<FormulaType> args) check;
  final Object? Function(List<Object?> args, DateTime today) apply;
}

FormulaType _numbers(List<FormulaType> args) {
  if (args.any((t) => t != FormulaType.number)) throw 'expects numbers';
  return FormulaType.number;
}

FormulaType _booleans(List<FormulaType> args) {
  if (args.any((t) => t != FormulaType.boolean)) {
    throw 'expects Yes / No values';
  }
  return FormulaType.boolean;
}

FormulaType _oneText(List<FormulaType> args) {
  if (args.first != FormulaType.text) throw 'expects text';
  return FormulaType.text;
}

FormulaType _oneDate(List<FormulaType> args) {
  if (args.first != FormulaType.date) throw 'expects a date';
  return FormulaType.number;
}

num _n(Object? v) => v is num ? v : throw const _EvalFailure();
String _s(Object? v) => v is String ? v : throw const _EvalFailure();
DateTime? _d(Object? v) => v is DateTime ? v : null;

num _round(num value, num digits, num Function(num) mode) {
  final f = math.pow(10, digits.toInt());
  final r = mode(value * f) / f;
  return r == r.truncateToDouble() && digits <= 0 ? r.toInt() : r;
}

/// The built-in functions, by upper-case name. Add one here to extend
/// formulas; storage and the field system don't change.
final Map<String, FormulaFunction> formulaFunctions = {
  for (final f in <FormulaFunction>[
    FormulaFunction(
      name: 'IF',
      usage: 'IF(condition, then, else)',
      summary: 'Picks a value by a Yes / No condition.',
      minArgs: 3,
      maxArgs: 3,
      check: (a) {
        if (a[0] != FormulaType.boolean) throw 'needs a Yes / No condition';
        if (a[1] != a[2]) {
          throw 'needs "then" and "else" of the same type (${a[1].label} vs ${a[2].label})';
        }
        return a[1];
      },
      apply: (a, _) => throw StateError('IF is lazy'),
    ),
    FormulaFunction(
      name: 'AND',
      usage: 'AND(a, b, …)',
      summary: 'Yes when every condition is Yes.',
      minArgs: 1,
      check: _booleans,
      apply: (a, _) => a.every((v) => v == true),
    ),
    FormulaFunction(
      name: 'OR',
      usage: 'OR(a, b, …)',
      summary: 'Yes when any condition is Yes.',
      minArgs: 1,
      check: _booleans,
      apply: (a, _) => a.any((v) => v == true),
    ),
    FormulaFunction(
      name: 'NOT',
      usage: 'NOT(condition)',
      summary: 'Flips Yes and No.',
      minArgs: 1,
      maxArgs: 1,
      check: _booleans,
      apply: (a, _) => a.first != true,
    ),
    FormulaFunction(
      name: 'ROUND',
      usage: 'ROUND(number, digits)',
      summary: 'Rounds to the given decimal digits (0 by default).',
      minArgs: 1,
      maxArgs: 2,
      check: _numbers,
      apply: (a, _) =>
          _round(_n(a[0]), a.length > 1 ? _n(a[1]) : 0, (x) => x.round()),
    ),
    FormulaFunction(
      name: 'FLOOR',
      usage: 'FLOOR(number)',
      summary: 'Rounds down to a whole number.',
      minArgs: 1,
      maxArgs: 1,
      check: _numbers,
      apply: (a, _) => _n(a[0]).floor(),
    ),
    FormulaFunction(
      name: 'CEIL',
      usage: 'CEIL(number)',
      summary: 'Rounds up to a whole number.',
      minArgs: 1,
      maxArgs: 1,
      check: _numbers,
      apply: (a, _) => _n(a[0]).ceil(),
    ),
    FormulaFunction(
      name: 'ABS',
      usage: 'ABS(number)',
      summary: 'The number without its sign.',
      minArgs: 1,
      maxArgs: 1,
      check: _numbers,
      apply: (a, _) => _n(a[0]).abs(),
    ),
    FormulaFunction(
      name: 'MIN',
      usage: 'MIN(a, b, …)',
      summary: 'The smallest number.',
      minArgs: 1,
      check: _numbers,
      apply: (a, _) => a.map(_n).reduce(math.min),
    ),
    FormulaFunction(
      name: 'MAX',
      usage: 'MAX(a, b, …)',
      summary: 'The largest number.',
      minArgs: 1,
      check: _numbers,
      apply: (a, _) => a.map(_n).reduce(math.max),
    ),
    FormulaFunction(
      name: 'CONCAT',
      usage: 'CONCAT(a, b, …)',
      summary: 'Joins values into one text.',
      minArgs: 1,
      check: (_) => FormulaType.text,
      apply: (a, _) => a.map(_text).join(),
    ),
    FormulaFunction(
      name: 'LEN',
      usage: 'LEN(text)',
      summary: 'How many characters the text has.',
      minArgs: 1,
      maxArgs: 1,
      check: (a) {
        _oneText(a);
        return FormulaType.number;
      },
      apply: (a, _) => _s(a[0]).length,
    ),
    FormulaFunction(
      name: 'UPPER',
      usage: 'UPPER(text)',
      summary: 'The text in capitals.',
      minArgs: 1,
      maxArgs: 1,
      check: _oneText,
      apply: (a, _) => _s(a[0]).toUpperCase(),
    ),
    FormulaFunction(
      name: 'LOWER',
      usage: 'LOWER(text)',
      summary: 'The text in lower case.',
      minArgs: 1,
      maxArgs: 1,
      check: _oneText,
      apply: (a, _) => _s(a[0]).toLowerCase(),
    ),
    FormulaFunction(
      name: 'TODAY',
      usage: 'TODAY()',
      summary: "Today's date.",
      minArgs: 0,
      maxArgs: 0,
      check: (_) => FormulaType.date,
      apply: (_, today) => today,
    ),
    FormulaFunction(
      name: 'YEAR',
      usage: 'YEAR(date)',
      summary: 'The year of a date.',
      minArgs: 1,
      maxArgs: 1,
      check: _oneDate,
      apply: (a, _) => _d(a[0])?.year,
    ),
    FormulaFunction(
      name: 'MONTH',
      usage: 'MONTH(date)',
      summary: 'The month of a date (1–12).',
      minArgs: 1,
      maxArgs: 1,
      check: _oneDate,
      apply: (a, _) => _d(a[0])?.month,
    ),
    FormulaFunction(
      name: 'DAY',
      usage: 'DAY(date)',
      summary: 'The day of the month of a date.',
      minArgs: 1,
      maxArgs: 1,
      check: _oneDate,
      apply: (a, _) => _d(a[0])?.day,
    ),
    FormulaFunction(
      name: 'ISBLANK',
      usage: 'ISBLANK(value)',
      summary: 'Yes when the value is empty.',
      minArgs: 1,
      maxArgs: 1,
      check: (_) => FormulaType.boolean,
      apply: (a, _) => throw StateError('ISBLANK reads raw values'),
    ),
  ])
    f.name: f,
};

String _text(Object? v) => switch (v) {
  null => '',
  final num n when n == n.truncateToDouble() && n.abs() < 1e15 =>
    '${n.toInt()}',
  final num n => '${double.parse(n.toStringAsPrecision(12))}',
  final bool b => b ? 'Yes' : 'No',
  final DateTime d =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
  _ => '$v',
};

// ---------------------------------------------------------------------------
// AST
// ---------------------------------------------------------------------------

class _EvalFailure implements Exception {
  const _EvalFailure();
}

class _Env {
  _Env(this.read, this.today);

  final Object? Function(String id) read;
  final DateTime today;
}

sealed class _Expr {
  _Expr(this.offset);

  final int offset;
  late FormulaType type;

  /// Type-checks this node (and its children); returns and remembers its type.
  FormulaType check() => type = _check();

  FormulaType _check();

  Object? eval(_Env env);
}

class _Literal extends _Expr {
  _Literal(super.offset, this.value, this.literalType);

  final Object value;
  final FormulaType literalType;

  @override
  FormulaType _check() => literalType;

  @override
  Object? eval(_Env env) => value;
}

class _FieldRef extends _Expr {
  _FieldRef(super.offset, this.field, this.fieldType);

  final FieldDefinition field;
  final FormulaType fieldType;

  @override
  FormulaType _check() => fieldType;

  /// Blank reads as 0 / "" / No; a blank date stays blank.
  @override
  Object? eval(_Env env) => evalRaw(env) ?? _blankOf(fieldType);

  Object? evalRaw(_Env env) => env.read(field.id);
}

Object? _blankOf(FormulaType type) => switch (type) {
  FormulaType.number => 0,
  FormulaType.text => '',
  FormulaType.boolean => false,
  FormulaType.date => null,
};

class _Unary extends _Expr {
  _Unary(super.offset, this.operand);

  final _Expr operand;

  @override
  FormulaType _check() {
    if (operand.check() != FormulaType.number) {
      throw FormulaError('"-" needs a number', offset);
    }
    return FormulaType.number;
  }

  @override
  Object? eval(_Env env) => -_n(operand.eval(env));
}

class _Binary extends _Expr {
  _Binary(super.offset, this.op, this.left, this.right);

  final String op;
  final _Expr left;
  final _Expr right;

  @override
  FormulaType _check() {
    final l = left.check();
    final r = right.check();
    const n = FormulaType.number;
    const d = FormulaType.date;
    switch (op) {
      case '&':
        return FormulaType.text;
      case '+':
        if (l == n && r == n) return n;
        if ((l == d && r == n) || (l == n && r == d)) return d;
        if (l == FormulaType.text || r == FormulaType.text) {
          throw FormulaError('Use & to join text', offset);
        }
      case '-':
        if (l == n && r == n) return n;
        if (l == d && r == n) return d;
        if (l == d && r == d) return n;
      case '*' || '/':
        if (l == n && r == n) return n;
      case '=' || '!=':
        if (l == r) return FormulaType.boolean;
      default: // < <= > >=
        if (l == r && l != FormulaType.boolean) return FormulaType.boolean;
    }
    throw FormulaError(
      '"$op" can\'t combine ${l.label} and ${r.label}',
      offset,
    );
  }

  @override
  Object? eval(_Env env) {
    final a = left.eval(env);
    final b = right.eval(env);
    if (op == '&') return _text(a) + _text(b);
    if (left.type == FormulaType.date || right.type == FormulaType.date) {
      return _dateOp(a, b);
    }
    switch (op) {
      case '+':
        return _n(a) + _n(b);
      case '-':
        return _n(a) - _n(b);
      case '*':
        return _n(a) * _n(b);
      case '/':
        final divisor = _n(b);
        if (divisor == 0) throw const _EvalFailure();
        final q = _n(a) / divisor;
        return q == q.truncateToDouble() && q.abs() < 1e15 ? q.toInt() : q;
      case '=':
        return a == b;
      case '!=':
        return a != b;
    }
    final c = switch ((a, b)) {
      (final num x, final num y) => x.compareTo(y),
      (final String x, final String y) => x.toLowerCase().compareTo(
        y.toLowerCase(),
      ),
      _ => throw const _EvalFailure(),
    };
    return switch (op) {
      '<' => c < 0,
      '<=' => c <= 0,
      '>' => c > 0,
      _ => c >= 0,
    };
  }

  Object? _dateOp(Object? a, Object? b) {
    switch (op) {
      case '+':
        final (date, days) = a is DateTime ? (a, b) : (_d(b), a);
        if (date == null) return null;
        return date.add(Duration(days: _n(days).round()));
      case '-':
        final date = _d(a);
        if (date == null) return null;
        if (right.type == FormulaType.date) {
          final other = _d(b);
          return other == null ? null : date.difference(other).inDays;
        }
        return date.subtract(Duration(days: _n(b).round()));
      case '=':
        return a == b;
      case '!=':
        return a != b;
    }
    final x = _d(a);
    final y = _d(b);
    if (x == null || y == null) return false;
    final c = x.compareTo(y);
    return switch (op) {
      '<' => c < 0,
      '<=' => c <= 0,
      '>' => c > 0,
      _ => c >= 0,
    };
  }
}

class _Call extends _Expr {
  _Call(super.offset, this.function, this.args);

  final FormulaFunction function;
  final List<_Expr> args;

  @override
  FormulaType _check() {
    final types = [for (final a in args) a.check()];
    final f = function;
    final max = f.maxArgs;
    if (types.length < f.minArgs || (max != null && types.length > max)) {
      throw FormulaError('Use ${f.usage}', offset);
    }
    try {
      return f.check(types);
    } on String catch (message) {
      throw FormulaError('${f.name} $message', offset);
    }
  }

  @override
  Object? eval(_Env env) {
    switch (function.name) {
      case 'IF':
        return args[0].eval(env) == true
            ? args[1].eval(env)
            : args[2].eval(env);
      case 'ISBLANK':
        final arg = args.first;
        final raw = arg is _FieldRef ? arg.evalRaw(env) : arg.eval(env);
        return raw == null || raw == '';
    }
    return function.apply([for (final a in args) a.eval(env)], env.today);
  }
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

enum _T { number, string, field, name, op, lparen, rparen, comma, end }

class _Token {
  const _Token(this.kind, this.text, this.offset);

  final _T kind;
  final String text;
  final int offset;
}

List<_Token> _tokenize(String s) {
  final tokens = <_Token>[];
  var i = 0;
  bool isDigit(int c) => c >= 48 && c <= 57;
  bool isNameChar(String c) => RegExp(r'[A-Za-z0-9_]').hasMatch(c);
  while (i < s.length) {
    final c = s[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    final start = i;
    if (isDigit(c.codeUnitAt(0)) ||
        (c == '.' && i + 1 < s.length && isDigit(s.codeUnitAt(i + 1)))) {
      while (i < s.length && (isDigit(s.codeUnitAt(i)) || s[i] == '.')) {
        i++;
      }
      final text = s.substring(start, i);
      if (num.tryParse(text) == null) {
        throw FormulaError('"$text" is not a number', start);
      }
      tokens.add(_Token(_T.number, text, start));
    } else if (c == '"' || c == '“' || c == '”') {
      i++;
      final buffer = StringBuffer();
      while (i < s.length && !'"“”'.contains(s[i])) {
        buffer.write(s[i]);
        i++;
      }
      if (i >= s.length) throw FormulaError('Close the text with "', start);
      i++;
      tokens.add(_Token(_T.string, buffer.toString(), start));
    } else if (c == '{') {
      final close = s.indexOf('}', i);
      if (close < 0) throw FormulaError('Close the field with }', start);
      tokens.add(_Token(_T.field, s.substring(i + 1, close), start));
      i = close + 1;
    } else if (isNameChar(c)) {
      while (i < s.length && isNameChar(s[i])) {
        i++;
      }
      tokens.add(_Token(_T.name, s.substring(start, i), start));
    } else if (c == '(') {
      tokens.add(_Token(_T.lparen, c, i++));
    } else if (c == ')') {
      tokens.add(_Token(_T.rparen, c, i++));
    } else if (c == ',' || c == ';') {
      tokens.add(_Token(_T.comma, c, i++));
    } else {
      final two = i + 1 < s.length ? s.substring(i, i + 2) : '';
      if (const {'<=', '>=', '!=', '<>', '=='}.contains(two)) {
        tokens.add(
          _Token(_T.op, two == '<>' ? '!=' : (two == '==' ? '=' : two), i),
        );
        i += 2;
      } else if ('+-*/&=<>×÷'.contains(c)) {
        tokens.add(_Token(_T.op, c == '×' ? '*' : (c == '÷' ? '/' : c), i++));
      } else {
        throw FormulaError('Unexpected "$c"', i);
      }
    }
  }
  tokens.add(_Token(_T.end, '', s.length));
  return tokens;
}

class _Parser {
  _Parser(String source, this.fields, this.selfId)
    : _tokens = _tokenize(source);

  final List<FieldDefinition> fields;
  final String? selfId;
  final List<_Token> _tokens;
  final Set<String> fieldIds = {};
  var readsBlanks = false;
  var _pos = 0;

  _Token get _peek => _tokens[_pos];

  _Token _next() => _tokens[_pos++];

  _Expr parse() {
    final e = _comparison();
    if (_peek.kind != _T.end) {
      throw FormulaError('Unexpected "${_peek.text}"', _peek.offset);
    }
    return e;
  }

  bool _isOp(Set<String> ops) =>
      _peek.kind == _T.op && ops.contains(_peek.text);

  _Expr _comparison() {
    var left = _concat();
    while (_isOp(const {'=', '!=', '<', '<=', '>', '>='})) {
      final op = _next();
      left = _Binary(op.offset, op.text, left, _concat());
    }
    return left;
  }

  _Expr _concat() {
    var left = _additive();
    while (_isOp(const {'&'})) {
      final op = _next();
      left = _Binary(op.offset, '&', left, _additive());
    }
    return left;
  }

  _Expr _additive() {
    var left = _multiplicative();
    while (_isOp(const {'+', '-'})) {
      final op = _next();
      left = _Binary(op.offset, op.text, left, _multiplicative());
    }
    return left;
  }

  _Expr _multiplicative() {
    var left = _unary();
    while (_isOp(const {'*', '/'})) {
      final op = _next();
      left = _Binary(op.offset, op.text, left, _unary());
    }
    return left;
  }

  _Expr _unary() {
    if (_isOp(const {'-'})) {
      final op = _next();
      return _Unary(op.offset, _unary());
    }
    if (_isOp(const {'+'})) _next();
    return _primary();
  }

  _Expr _primary() {
    final t = _next();
    switch (t.kind) {
      case _T.number:
        return _Literal(t.offset, num.parse(t.text), FormulaType.number);
      case _T.string:
        return _Literal(t.offset, t.text, FormulaType.text);
      case _T.field:
        final field = _resolve(t.text, fields);
        if (field == null) {
          throw FormulaError('No field named "${t.text.trim()}"', t.offset);
        }
        if (field.id == selfId) {
          throw FormulaError("A formula can't use its own field", t.offset);
        }
        final type = formulaTypeOfField(field);
        if (type == null) {
          throw FormulaError(
            '"${field.name}" can\'t be used in a formula — '
            'use an Aggregate field to summarize linked items',
            t.offset,
          );
        }
        fieldIds.add(field.id);
        return _FieldRef(t.offset, field, type);
      case _T.name:
        final upper = t.text.toUpperCase();
        if (upper == 'TRUE' || upper == 'YES') {
          return _Literal(t.offset, true, FormulaType.boolean);
        }
        if (upper == 'FALSE' || upper == 'NO') {
          return _Literal(t.offset, false, FormulaType.boolean);
        }
        final function = formulaFunctions[upper];
        if (function == null) {
          final asField = _resolve(t.text, fields);
          throw FormulaError(
            asField != null
                ? 'Put field names in braces: {${asField.name}}'
                : 'Unknown function "${t.text}"',
            t.offset,
          );
        }
        if (_peek.kind != _T.lparen) {
          throw FormulaError('Use ${function.usage}', t.offset);
        }
        if (function.name == 'ISBLANK') readsBlanks = true;
        _next();
        final args = <_Expr>[];
        if (_peek.kind != _T.rparen) {
          args.add(_comparison());
          while (_peek.kind == _T.comma) {
            _next();
            args.add(_comparison());
          }
        }
        if (_next().kind != _T.rparen) {
          throw FormulaError('Close ${function.name}( with )', t.offset);
        }
        return _Call(t.offset, function, args);
      case _T.lparen:
        final e = _comparison();
        if (_next().kind != _T.rparen) {
          throw FormulaError('Close the bracket with )', t.offset);
        }
        return e;
      case _T.end:
        throw FormulaError('The formula ends too early', t.offset);
      default:
        throw FormulaError('Unexpected "${t.text}"', t.offset);
    }
  }
}
