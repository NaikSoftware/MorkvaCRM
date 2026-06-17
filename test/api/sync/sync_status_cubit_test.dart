import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';

void main() {
  group('SyncStatusCubit', () {
    test('starts in SyncUnknown (no signal yet — not a misleading Offline)', () {
      final cubit = SyncStatusCubit();
      expect(cubit.state, const SyncUnknown());
      cubit.close();
    });

    group('reportPendingWrite', () {
      blocTest<SyncStatusCubit, SyncStatus>(
        'emits SyncPending',
        build: SyncStatusCubit.new,
        act: (cubit) => cubit.reportPendingWrite(),
        expect: () => const [SyncPending()],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'is a no-op while in SyncConflict (conflict stays sticky)',
        build: SyncStatusCubit.new,
        seed: () => const SyncConflict(affectedObjectIds: {'a'}),
        act: (cubit) => cubit.reportPendingWrite(),
        expect: () => const <SyncStatus>[],
      );
    });

    group('reportSnapshotMeta', () {
      blocTest<SyncStatusCubit, SyncStatus>(
        'acknowledged (not cache, no pending) → SyncSynced',
        build: SyncStatusCubit.new,
        act: (cubit) => cubit.reportSnapshotMeta(
          isFromCache: false,
          hasPendingWrites: false,
        ),
        expect: () => const [SyncSynced()],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'from cache, no pending → SyncOffline',
        build: SyncStatusCubit.new,
        // Seed a non-offline state so the SyncOffline emission is observable.
        seed: () => const SyncSynced(),
        act: (cubit) => cubit.reportSnapshotMeta(
          isFromCache: true,
          hasPendingWrites: false,
        ),
        expect: () => const [SyncOffline()],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'pending writes (server) → SyncPending',
        build: SyncStatusCubit.new,
        act: (cubit) => cubit.reportSnapshotMeta(
          isFromCache: false,
          hasPendingWrites: true,
        ),
        expect: () => const [SyncPending()],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'pending writes take precedence over cache flag → SyncPending',
        build: SyncStatusCubit.new,
        act: (cubit) =>
            cubit.reportSnapshotMeta(isFromCache: true, hasPendingWrites: true),
        expect: () => const [SyncPending()],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'is ignored while in SyncConflict',
        build: SyncStatusCubit.new,
        seed: () => const SyncConflict(affectedObjectIds: {'a'}),
        act: (cubit) => cubit
          ..reportSnapshotMeta(isFromCache: false, hasPendingWrites: false)
          ..reportSnapshotMeta(isFromCache: true, hasPendingWrites: false)
          ..reportSnapshotMeta(isFromCache: false, hasPendingWrites: true),
        expect: () => const <SyncStatus>[],
      );
    });

    group('reportConflict', () {
      blocTest<SyncStatusCubit, SyncStatus>(
        'emits SyncConflict with the affected ids',
        build: SyncStatusCubit.new,
        act: (cubit) => cubit.reportConflict({'a'}),
        expect: () => const [
          SyncConflict(affectedObjectIds: {'a'}),
        ],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'unions new ids with the existing conflict set',
        build: SyncStatusCubit.new,
        act: (cubit) => cubit
          ..reportConflict({'a'})
          ..reportConflict({'b'}),
        expect: () => const [
          SyncConflict(affectedObjectIds: {'a'}),
          SyncConflict(affectedObjectIds: {'a', 'b'}),
        ],
      );
    });

    group('dismissConflict', () {
      blocTest<SyncStatusCubit, SyncStatus>(
        'in SyncConflict → SyncPending so metadata can settle next',
        build: SyncStatusCubit.new,
        seed: () => const SyncConflict(affectedObjectIds: {'a'}),
        act: (cubit) => cubit.dismissConflict(),
        expect: () => const [SyncPending()],
      );

      blocTest<SyncStatusCubit, SyncStatus>(
        'is a no-op when not in conflict',
        build: SyncStatusCubit.new,
        seed: () => const SyncSynced(),
        act: (cubit) => cubit.dismissConflict(),
        expect: () => const <SyncStatus>[],
      );
    });

    blocTest<SyncStatusCubit, SyncStatus>(
      'reportError emits SyncError carrying the message',
      build: SyncStatusCubit.new,
      act: (cubit) => cubit.reportError('boom'),
      expect: () => const [SyncError(message: 'boom')],
    );

    test('SyncError equality is by message, ignoring the cause', () {
      // props is [message]; cause is intentionally excluded from equality.
      expect(
        const SyncError(message: 'x', cause: 'one'),
        const SyncError(message: 'x', cause: 'two'),
      );
      expect(
        const SyncError(message: 'x'),
        isNot(const SyncError(message: 'y')),
      );
    });

    group('SyncConflict equality', () {
      test('equal when affected-id sets are equal (order-independent)', () {
        expect(
          const SyncConflict(affectedObjectIds: {'a', 'b'}),
          const SyncConflict(affectedObjectIds: {'b', 'a'}),
        );
      });

      test('not equal when affected-id sets differ', () {
        expect(
          const SyncConflict(affectedObjectIds: {'a'}),
          isNot(const SyncConflict(affectedObjectIds: {'a', 'b'})),
        );
      });
    });
  });
}
