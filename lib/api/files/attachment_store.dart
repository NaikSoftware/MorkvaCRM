import 'dart:typed_data';

import '../../core/domain/domain.dart';

/// Stores file-field blobs; the object keeps only their [FileAttachment]
/// metadata.
abstract interface class AttachmentStore {
  /// Binds the store to [workspaceId]; uploads and downloads go under it.
  void initialize(String workspaceId);

  /// Uploads [bytes] as [fileName] under the new attachment [id], reporting
  /// progress (0…1) through [onProgress]. Completes with the stored
  /// attachment; throws when the upload fails.
  Future<FileAttachment> upload({
    required String id,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  });

  /// A URL the user can open [attachment] at.
  Future<Uri> downloadUrl(FileAttachment attachment);
}

/// Largest file the Storage rules accept.
const int kMaxAttachmentBytes = 25 * 1024 * 1024;
