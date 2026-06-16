import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/auth/auth_cubit.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/auth/sign_in_page.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockAuthCubit cubit;

  setUp(() => cubit = _MockAuthCubit());

  Widget host() => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<AuthCubit>.value(
      value: cubit,
      child: const SignInPage(),
    ),
  );

  testWidgets('renders brand, value line and the Google CTA when '
      'unauthenticated', (tester) async {
    when(() => cubit.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(host());

    expect(find.text('Morkva CRM'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('tapping the CTA calls signInWithGoogle', (tester) async {
    when(() => cubit.state).thenReturn(const AuthUnauthenticated());
    when(() => cubit.signInWithGoogle()).thenAnswer((_) async {});

    await tester.pumpWidget(host());
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    verify(() => cubit.signInWithGoogle()).called(1);
  });

  testWidgets('shows a spinner and hides the label while loading', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(const AuthLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('shows the error message inline on AuthError (no dialog)', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const AuthError(message: 'Sign-in was cancelled.'));

    await tester.pumpWidget(host());

    expect(find.text('Sign-in was cancelled.'), findsOneWidget);
    // Inline, not a dialog.
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
