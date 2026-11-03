import 'dart:async';
import 'dart:typed_data';

import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/value_editors/field_value_editor.dart';

/// An [AttachmentStore] whose uploads finish when the test says so.
class FakeAttachmentStore implements AttachmentStore {
  final pending = <String, Completer<void>>{};
  final progress = <String, void Function(double)?>{};
  final uploaded = <String>[];

  @override
  void initialize(String workspaceId) {}

  @override
  Future<FileAttachment> upload({
    required String id,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final done = pending[fileName] = Completer<void>();
    progress[fileName] = onProgress;
    await done.future;
    uploaded.add(fileName);
    return FileAttachment(
      id: id,
      name: fileName,
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }

  void finish(String name) => pending[name]!.complete();

  void fail(String name) => pending[name]!.completeError(Exception('404'));

  @override
  Future<Uri> downloadUrl(FileAttachment attachment) async =>
      Uri.parse('https://files.test/${attachment.id}');
}

PickedFile picked(String name, [int size = 10]) =>
    (name: name, bytes: Uint8List(size));
