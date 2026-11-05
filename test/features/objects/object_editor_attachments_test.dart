import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';
import 'package:morkva_crm/features/objects/object_editor_cubit.dart';

import '../collections/fake_data_repository.dart';
import '../views/views_fixtures.dart';
import 'fake_attachment_store.dart';

class _Ids extends IdGenerator {
  var _n = 0;

  @override
  String attachmentId() => 'a${++_n}';
}

/// Deals plus a multi-file "Files" and a single PDF "Contract".
final withFiles = deals.copyWith(
  fields: [
    ...deals.fields,
    const FileFieldDefinition(id: 'files', name: 'Files', multiple: true),
    const FileFieldDefinition(
      id: 'contract',
      name: 'Contract',
      allowedExtensions: ['pdf'],
    ),
  ],
);

FileFieldValue valueOf(ObjectEditorCubit c, String id) =>
    c.state.valueOf(withFiles.fieldById(id)!) as FileFieldValue;

void main() {
  late FakeDataRepository repo;
  late FakeAttachmentStore store;

  setUp(() {
    repo = FakeDataRepository([withFiles, companies]);
    repo.seedObjects('deals', sampleDeals());
    store = FakeAttachmentStore();
  });

  Future<ObjectEditorCubit> edit() async {
    final c = ObjectEditorCubit(
      repo,
      withFiles,
      object: repo.objectsOf('deals').first,
      attachments: store,
      idGenerator: _Ids(),
    );
    addTearDown(c.close);
    await c.initialize();
    await pumpEventQueue();
    return c;
  }

  test('an upload shows progress, then joins the draft', () async {
    final c = await edit();
    final done = c.upload('files', [picked('a.png'), picked('b.pdf', 20)]);
    await pumpEventQueue();
    expect(c.state.uploads.map((u) => u.name), ['a.png', 'b.pdf']);
    expect(c.state.isUploading, isTrue);
    store.progress['a.png']!(0.64);
    expect(c.state.uploads.first.progress, 0.64);

    store.finish('a.png');
    await pumpEventQueue();
    expect(c.state.uploads.map((u) => u.name), ['b.pdf']);
    store.finish('b.pdf');
    await done;
    expect(c.state.isUploading, isFalse);
    expect(valueOf(c, 'files').attachments, [
      const FileAttachment(
        id: 'a1',
        name: 'a.png',
        mimeType: 'image/png',
        sizeBytes: 10,
      ),
      const FileAttachment(
        id: 'a2',
        name: 'b.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 20,
      ),
    ]);
    expect(c.state.changedFieldIds, {'files'});
  });

  test('a failed upload sets the error and leaves the value', () async {
    final c = await edit();
    final done = c.upload('files', [picked('a.png')]);
    await pumpEventQueue();
    store.fail('a.png');
    await done;
    expect(c.state.uploads, isEmpty);
    expect(c.state.uploadErrors, {'files': "Couldn't upload a.png"});
    expect(valueOf(c, 'files').attachments, isEmpty);
    expect(c.state.draft, isEmpty);

    // The next upload clears it.
    final retry = c.upload('files', [picked('a.png')]);
    await pumpEventQueue();
    expect(c.state.uploadErrors, isEmpty);
    store.finish('a.png');
    await retry;
  });

  test('a file of 25 MB or more is refused without uploading', () async {
    final c = await edit();
    await c.upload('files', [picked('huge.mov', 25 * 1024 * 1024)]);
    expect(store.pending, isEmpty);
    expect(c.state.uploadErrors['files'], contains('under 25 MB'));
  });

  test('a single-file field replaces its file and takes one pick', () async {
    final c = await edit();
    final first = c.upload('contract', [picked('v1.pdf'), picked('x.pdf')]);
    await pumpEventQueue();
    expect(c.state.uploads, hasLength(1));
    store.finish('v1.pdf');
    await first;
    final second = c.upload('contract', [picked('v2.pdf')]);
    await pumpEventQueue();
    store.finish('v2.pdf');
    await second;
    expect(valueOf(c, 'contract').attachments.map((a) => a.name), ['v2.pdf']);
  });

  test('a disallowed extension shows the domain error', () async {
    final c = await edit();
    final done = c.upload('contract', [picked('setup.exe')]);
    await pumpEventQueue();
    store.finish('setup.exe');
    await done;
    expect(
      c.state.visibleErrors['contract'],
      'setup.exe has an unsupported type for Contract',
    );
  });

  test('Save waits for uploads', () async {
    final c = await edit();
    final done = c.upload('files', [picked('a.png')]);
    await pumpEventQueue();
    expect(c.state.hasUnsavedChanges, isTrue);
    expect(await c.save(), isFalse);
    expect(c.state.status, ObjectEditorStatus.editing);
    store.finish('a.png');
    await done;
    expect(await c.save(), isTrue);
    final saved = repo.objectsOf('deals').first.values['files'];
    expect((saved as FileFieldValue).attachments.single.name, 'a.png');
  });

  test('removing is a change without the attachment', () async {
    final c = await edit();
    final done = c.upload('files', [picked('a.png'), picked('b.png')]);
    await pumpEventQueue();
    store
      ..finish('a.png')
      ..finish('b.png');
    await done;
    final [a, _] = valueOf(c, 'files').attachments;
    c.change('files', FileFieldValue([a]));
    expect(valueOf(c, 'files').attachments, [a]);
  });

  test('a canceled upload ends without an error or a file', () async {
    final c = await edit();
    final done = c.upload('files', [picked('a.png')]);
    await pumpEventQueue();
    final id = c.state.uploads.single.id;
    c.cancelUpload(id);
    await done;
    expect(store.canceled, [id]);
    expect(c.state.uploads, isEmpty);
    expect(c.state.uploadErrors, isEmpty);
    expect(valueOf(c, 'files').attachments, isEmpty);
  });

  test('without a store nothing uploads', () async {
    final c = ObjectEditorCubit(repo, withFiles);
    addTearDown(c.close);
    expect(c.canUpload, isFalse);
    await c.upload('files', [picked('a.png')]);
    expect(c.state.uploads, isEmpty);
  });

  group('form', () {
    Future<ObjectEditorCubit> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ObjectEditorCubit(
        repo,
        withFiles,
        object: repo.objectsOf('deals').first,
        attachments: store,
      );
      addTearDown(c.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider.value(
              value: c,
              child: const ObjectEditor(compact: false),
            ),
          ),
        ),
      );
      return c;
    }

    testWidgets('Save reads "Uploading…" and is disabled while uploading', (
      tester,
    ) async {
      final c = await pumpForm(tester);
      expect(find.text('Upload file'), findsNWidgets(2));
      final done = c.upload('files', [picked('a.png')]);
      await tester.pump();
      expect(find.text('Uploading…'), findsOneWidget);
      final save = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Uploading…'),
      );
      expect(save.onPressed, isNull);
      store.finish('a.png');
      await tester.runAsync(() => done);
      await tester.pump();
      expect(find.text('Uploading…'), findsNothing);
      expect(find.text('a.png'), findsOneWidget);
    });

    testWidgets('an upload tile cancels from its ✕', (tester) async {
      final c = await pumpForm(tester);
      final done = c.upload('contract', [picked('msa.pdf')]);
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel upload'));
      await tester.runAsync(() => done);
      await tester.pump();
      expect(find.byTooltip('Cancel upload'), findsNothing);
      expect(find.text("Couldn't upload msa.pdf"), findsNothing);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('a failed upload shows under the field', (tester) async {
      final c = await pumpForm(tester);
      final done = c.upload('contract', [picked('msa.pdf')]);
      await tester.pump();
      store.fail('msa.pdf');
      await tester.runAsync(() => done);
      await tester.pump();
      expect(find.text("Couldn't upload msa.pdf"), findsOneWidget);
      expect(find.text('msa.pdf'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
