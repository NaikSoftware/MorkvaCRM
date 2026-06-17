import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/auth/conflict_warning_banner.dart';

class _MockSyncCubit extends MockCubit<SyncStatus> implements SyncStatusCubit {}

void main() {
  late _MockSyncCubit cubit;

  setUp(() => cubit = _MockSyncCubit());

  Widget host() => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: BlocProvider<SyncStatusCubit>.value(
        value: cubit,
        child: const ConflictWarningBanner(),
      ),
    ),
  );

  testWidgets('renders nothing when there is no conflict', (tester) async {
    when(() => cubit.state).thenReturn(const SyncSynced());

    await tester.pumpWidget(host());

    expect(find.text('Got it'), findsNothing);
  });

  testWidgets('explains the overwrite in plain language on conflict', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SyncConflict(affectedObjectIds: {'a'}));

    await tester.pumpWidget(host());

    expect(
      find.textContaining('A newer version of an item was saved elsewhere'),
      findsOneWidget,
    );
    expect(find.textContaining('We kept your latest changes'), findsOneWidget);
  });

  testWidgets('pluralizes the message for multiple affected items', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SyncConflict(affectedObjectIds: {'a', 'b', 'c'}));

    await tester.pumpWidget(host());

    expect(
      find.textContaining('A newer version of 3 items was saved elsewhere'),
      findsOneWidget,
    );
  });

  testWidgets('dismiss action calls dismissConflict', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const SyncConflict(affectedObjectIds: {'a'}));
    when(() => cubit.dismissConflict()).thenReturn(null);

    await tester.pumpWidget(host());
    await tester.tap(find.text('Got it'));
    await tester.pump();

    verify(() => cubit.dismissConflict()).called(1);
  });
}
