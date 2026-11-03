import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/value_editors/field_value_editor.dart';
import 'package:morkva_crm/features/objects/value_editors/file_value_editor.dart';

import 'editor_harness.dart';

const _pdf = FileAttachment(
  id: 'a1',
  name: 'stark-msa-2026.pdf',
  mimeType: 'application/pdf',
  sizeBytes: 412 * 1024,
);
const _png = FileAttachment(id: 'a2', name: 'logo.png', sizeBytes: 900);

AttachmentActions _actions({
  List<PendingUpload> uploads = const [],
  List<FileAttachment>? opened,
}) => AttachmentActions(
  upload: (_) {},
  open: (a) => opened?.add(a),
  uploads: uploads,
);

void main() {
  test('sizes read as B / KB / MB', () {
    expect(formatFileSize(980), '980 B');
    expect(formatFileSize(412 * 1024), '412 KB');
    expect(formatFileSize(1468006), '1.4 MB');
  });

  testWidgets('tiles show badge, name and size; the name opens the file', (
    tester,
  ) async {
    final opened = <FileAttachment>[];
    final h = EditorHarness(
      const FileFieldDefinition(id: 'f', name: 'Files', multiple: true),
      const FileFieldValue([_pdf, _png]),
    );
    await h.pump(tester, attachments: _actions(opened: opened));
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('412 KB'), findsOneWidget);
    expect(find.text('900 B'), findsOneWidget);
    expect(find.text('Upload file'), findsOneWidget);
    await tester.tap(find.text('stark-msa-2026.pdf'));
    expect(opened, [_pdf]);
  });

  testWidgets('remove drops the attachment', (tester) async {
    final h = EditorHarness(
      const FileFieldDefinition(id: 'f', name: 'Files', multiple: true),
      const FileFieldValue([_pdf, _png]),
    );
    await h.pump(tester, attachments: _actions());
    await tester.tap(find.byTooltip('Remove logo.png'));
    await tester.pump();
    expect(h.value, const FileFieldValue([_pdf]));
    expect(find.text('logo.png'), findsNothing);
  });

  testWidgets('a single-file field with a file offers Replace', (tester) async {
    final h = EditorHarness(
      const FileFieldDefinition(id: 'f', name: 'Contract'),
      const FileFieldValue([_pdf]),
    );
    await h.pump(tester, attachments: _actions());
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Upload file'), findsNothing);
  });

  testWidgets('an upload in flight shows its progress', (tester) async {
    final h = EditorHarness(
      const FileFieldDefinition(id: 'f', name: 'Contract'),
      null,
    );
    await h.pump(
      tester,
      attachments: _actions(
        uploads: const [
          PendingUpload(
            id: 'u',
            fieldId: 'f',
            name: 'signature-page.png',
            progress: 0.64,
          ),
        ],
      ),
    );
    expect(find.text('signature-page.png'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.64);
    // One file at a time on a single-file field.
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Upload file'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('without attachment actions there is no upload', (tester) async {
    final h = EditorHarness(
      const FileFieldDefinition(id: 'f', name: 'Files', multiple: true),
      const FileFieldValue([_pdf]),
    );
    await h.pump(tester);
    expect(find.text('stark-msa-2026.pdf'), findsOneWidget);
    expect(find.text('Upload file'), findsNothing);
  });
}
