import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/domain/domain.dart';
import 'attachment_store.dart';

/// [AttachmentStore] on Firebase Storage, at
/// `workspaces/{workspaceId}/files/{attachmentId}/{fileName}`.
class FirebaseAttachmentStore implements AttachmentStore {
  /// [storage] defaults to `FirebaseStorage.instance`, resolved on first use
  /// so building the store never needs Firebase.
  FirebaseAttachmentStore({FirebaseStorage? storage}) : _storage = storage;

  FirebaseStorage? _storage;
  String? _workspaceId;

  @override
  void initialize(String workspaceId) => _workspaceId = workspaceId;

  Reference _ref(String id, String fileName) {
    final workspaceId = _workspaceId;
    if (workspaceId == null) {
      throw StateError('AttachmentStore used before initialize()');
    }
    final storage = _storage ??= FirebaseStorage.instance;
    return storage.ref('workspaces/$workspaceId/files/$id/$fileName');
  }

  @override
  Future<FileAttachment> upload({
    required String id,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final task = _ref(
      id,
      fileName,
    ).putData(bytes, SettableMetadata(contentType: mimeType));
    final progress = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    }, onError: (Object _) {});
    try {
      await task;
    } finally {
      await progress.cancel();
    }
    return FileAttachment(
      id: id,
      name: fileName,
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<Uri> downloadUrl(FileAttachment attachment) async =>
      Uri.parse(await _ref(attachment.id, attachment.name).getDownloadURL());
}
