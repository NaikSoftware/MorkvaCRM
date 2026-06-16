import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/app/shell/sync_status_indicator.dart';
import 'package:morkva_crm/design/design.dart';

class _MockSyncCubit extends MockCubit<SyncStatus> implements SyncStatusCubit {}

void main() {
  late _MockSyncCubit cubit;

  setUp(() => cubit = _MockSyncCubit());

  Widget host() => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: BlocProvider<SyncStatusCubit>.value(
        value: cubit,
        child: const SyncStatusIndicator(),
      ),
    ),
  );

  testWidgets('renders "Synced" with a glyph (no spinner) when synced', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(const SyncSynced());

    await tester.pumpWidget(host());

    expect(find.text('Synced'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders a spinner and "Syncing…" when pending', (tester) async {
    when(() => cubit.state).thenReturn(const SyncPending());

    await tester.pumpWidget(host());

    expect(find.text('Syncing…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders "Offline" when offline', (tester) async {
    when(() => cubit.state).thenReturn(const SyncOffline());

    await tester.pumpWidget(host());

    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('renders "Sync error" on error', (tester) async {
    when(() => cubit.state).thenReturn(const SyncError(message: 'boom'));

    await tester.pumpWidget(host());

    expect(find.text('Sync error'), findsOneWidget);
  });

  testWidgets('conflict state is tappable and dismisses the conflict', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SyncConflict(affectedObjectIds: {'a'}));
    when(() => cubit.dismissConflict()).thenReturn(null);

    await tester.pumpWidget(host());
    expect(find.text('Conflict'), findsOneWidget);

    await tester.tap(find.text('Conflict'));
    await tester.pump();

    verify(() => cubit.dismissConflict()).called(1);
  });
}
