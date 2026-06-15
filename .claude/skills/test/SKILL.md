---
name: test
description: Generate high-quality Dart tests for the Flutter app with focus on real-world scenarios and project conventions. Use when the user asks to write tests, generate tests, or create test files for Flutter/Dart code.
---

# Test

Generate high-quality Dart tests for the Flutter app with focus on real-world scenarios and project conventions.

## Description

This skill helps generate focused and well-structured tests that follow the project's established patterns and testing conventions. It prioritizes quality over quantity, focusing on meaningful test scenarios that validate real business logic and user interactions.

## Before Writing Tests

Always ask the user to specify **what component, class, or functionality** should be tested or **specific test scenarios** they want to cover.

## Running Tests

- Run the full suite: `flutter test`
- Run a single file: `flutter test test/path/to/file_test.dart`
- Run a single test by name: `flutter test --plain-name "renders text field"`
- Mirror the source layout under `test/` (e.g. `lib/src/foo.dart` → `test/src/foo_test.dart`) and name files `*_test.dart`.

## Testing Philosophy: Less is More (CRITICAL)

### The Problem with Excessive Tests

Many developers fall into the trap of writing too many tests. This leads to:
- **Maintenance burden** - more tests = more code to maintain when refactoring
- **False confidence** - 50 similar tests don't provide more coverage than 5 well-designed ones
- **Slower CI/CD** - excessive tests slow down development feedback loop
- **Test fatigue** - developers stop reading/maintaining bloated test suites

### Right-Size Your Tests

The number of tests should be **proportional to code complexity**, not arbitrary targets:

| Code Complexity | Test Count | Examples |
|-----------------|------------|----------|
| **Simple** (single method, trivial logic) | 1-3 tests | Simple getter with condition, basic formatter, simple validator |
| **Moderate** (class with few methods, clear logic) | 3-6 tests | Service with CRUD operations, widget with few states |
| **Complex** (multiple methods, business rules) | 5-10 tests | Complex validator, state machine, multi-step workflow |

**Key principle**: One well-designed test that covers multiple cases is better than many similar tests.

### Examples of Proportional Testing

**Simple code - 2 tests are enough:**
```dart
// Testing a simple null-or-empty check method
class StringUtils {
  static bool isNullOrEmpty(String? value) => value == null || value.trim().isEmpty;
}

// ✅ GOOD - 2 tests cover everything
test('returns true for null, empty, and whitespace values', () {
  expect(StringUtils.isNullOrEmpty(null), isTrue);
  expect(StringUtils.isNullOrEmpty(''), isTrue);
  expect(StringUtils.isNullOrEmpty('   '), isTrue);
});

test('returns false for non-empty strings', () {
  expect(StringUtils.isNullOrEmpty('hello'), isFalse);
  expect(StringUtils.isNullOrEmpty(' a '), isFalse);
});

// ❌ BAD - 7 separate tests for same logic
test('returns true for null');
test('returns true for empty string');
test('returns true for single space');
test('returns true for multiple spaces');
test('returns true for tab');
test('returns false for single char');
test('returns false for word');
```

**Moderate code - consolidate similar scenarios:**
```dart
// ✅ GOOD - One test covers multiple valid inputs
test('validates various valid integer formats within range', () {
  final validator = IntegerRangeValidator(min: 0, max: 100);
  expect(validator.validate('50'), isNull);      // middle value
  expect(validator.validate('0'), isNull);       // min boundary
  expect(validator.validate('100'), isNull);     // max boundary
  expect(validator.validate('50,5'), isNull);    // comma decimal
  expect(validator.validate('50.5'), isNull);    // dot decimal
});

// ❌ BAD - Separate tests for each input
test('validates 50');
test('validates 0');
test('validates 100');
test('validates with comma');
test('validates with dot');
```

### When NOT to Consolidate

Keep tests separate when:
- Different **error messages** need verification
- Different **behavior paths** are exercised (not just different inputs)
- Tests have **different setup requirements**
- Failure in one scenario shouldn't mask others (critical paths)

## Testing Rules and Best Practices

### 1. Focus on Essential Business Logic Only

- Write tests ONLY for critical business logic that could break or cause user issues
- Avoid trivial tests: constants, getters/setters, props, hashCode, toString
- Avoid excessive edge case testing - test only realistic failure scenarios
- Ask: "If this breaks, would users notice?" If no, don't test it

**ESSENTIAL (Always Test):**
- Core business rules and validation logic
- Input/output transformations that affect user experience
- Error handling that prevents crashes
- Integration with external dependencies (APIs, databases)
- User interaction flows that could break

**NON-ESSENTIAL (Skip These):**
- Testing framework functionality
- Trivial getters/setters without logic
- Constants and static values
- Multiple variations of the same logic path
- Props, equality, hashCode unless custom logic

### 2. Follow Project Style

- Check existing tests in the same module/directory for style consistency
- Use the same naming conventions, setup patterns, and test structure
- Follow the established `group()` and `testWidgets()` organization
- Maintain consistent test descriptions using present tense (e.g., "renders text field", "calls handler on tap")

### 3. Use Project Test Utilities

- Before writing new helpers, check `test/` (and any shared `test/helpers/` or `test_utils/` directory) for existing utilities and reuse them.
- Common Flutter testing tools: `flutter_test` (`testWidgets`, `WidgetTester`, `pumpWidget`, `pump`, `pumpAndSettle`), `mocktail` or `mockito` for mocking.
- Wrap widgets under test with the same scaffolding the rest of the suite uses (e.g. a shared `pumpApp`/`wrapWidget` helper). If the project has no such helper yet, wrap with `MaterialApp(home: ...)` and the localization/theme delegates the app requires.
- <!-- TODO: document the project's actual shared test helpers and localization-mocking pattern once they exist. --> If the app uses localized strings, prefer the project's localization test helper over hand-rolled `AppLocalizations` mocks.

### 4. Extract Repetitive Code

- Create reusable helper functions for common test setups
- Use `setUp()` and `setUpAll()` for shared initialization
- Extract widget preparation into helper methods

### 5. No Unnecessary Comments

- Avoid "Act", "Arrange", "Assert" comments
- Let the test structure and naming speak for itself

### 6. Proper Mock Setup and Verification

- Register fallback values with `registerFallbackValue()` when stubbing methods that take custom types (mocktail)
- Use `when()` for mock setup and `verify()` for verification
- Reset or recreate mocks in `setUp()` so tests stay isolated

### 7. Widget Testing Patterns

- Use the project's shared widget-wrapping helper (or `MaterialApp`) so theming, routing, and localization resolve correctly
- Always `await tester.pumpAndSettle()` (or targeted `pump()` calls) after triggering async UI changes

**Widget Finder Specificity (CRITICAL):**
- **NEVER use generic widget type checks** like `expect(find.byType(InkWell), findsOneWidget)`
- **ALWAYS use specific checks** with custom widget types or keys
- Generic types (InkWell, Container, Text) may appear multiple times

```dart
// BAD - Generic type check
expect(find.byType(InkWell), findsOneWidget);

// GOOD - Specific widget type or key
expect(find.byType(CustomButton), findsOneWidget);
expect(find.byKey(const Key('submit_button')), findsOneWidget);
```

### 8. Test Organization

- Group related tests using `group()` with descriptive names
- Order tests logically (basic functionality first, then edge cases)
- Keep tests focused on single responsibility

## After Writing Tests

- Run the relevant test file(s) and confirm they pass.
- Check all setup and mocks — some may be redundant and can be removed.

## Key Success Metrics

- **Test count matches code complexity** (1-3 for simple, 5-10 max for complex)
- **Each test validates unique business logic or behavior path**
- **Similar inputs consolidated into single tests**
- **Focuses on preventing real user issues**
- **Follows existing project patterns**
