import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../views/widgets/board/board_card_draggable.dart';
import 'field_value_editor.dart';

/// file: one tile per attachment (type badge, name opening the file, size,
/// remove), a progress tile per upload in flight, and a dashed
/// "Upload file" (or "Replace" on a single-file field that has a file).
/// Without [ValueEditorContext.attachments] the files can only be removed.
class FileValueEditor extends FieldValueEditor {
  const FileValueEditor();

  @override
  String get typeId => kFileFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) {
    final field = ctx.field as FileFieldDefinition;
    final files = (ctx.value as FileFieldValue).attachments;
    final actions = ctx.attachments;
    final uploads = actions?.uploads ?? const <PendingUpload>[];

    Future<void> pick() async {
      final allowed = field.allowedExtensions;
      final type = allowed == null || allowed.isEmpty
          ? FileType.any
          : FileType.custom;
      final ext = type == FileType.custom ? allowed : null;
      final picked = field.multiple
          ? await FilePicker.pickFiles(type: type, allowedExtensions: ext)
          : [?await FilePicker.pickFile(type: type, allowedExtensions: ext)];
      if (picked.isEmpty) return;
      final read = [
        for (final f in picked) (name: f.name, bytes: await f.readAsBytes()),
      ];
      actions?.upload(read);
    }

    final canUpload = actions != null && ctx.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final file in files) ...[
          _AttachmentTile(
            attachment: file,
            hasError: ctx.error != null,
            onOpen: actions == null ? null : () => actions.open(file),
            // shortcut: removed/discarded attachments stay in Storage; add
            // cleanup in the Storage epic.
            onRemove: ctx.enabled
                ? () => ctx.onChanged(
                    FileFieldValue([
                      for (final f in files)
                        if (f != file) f,
                    ]),
                  )
                : null,
          ),
          const SizedBox(height: Spacing.xs),
        ],
        for (final upload in uploads) ...[
          _UploadingTile(upload: upload),
          const SizedBox(height: Spacing.xs),
        ],
        if (actions != null)
          _UploadButton(
            label: !field.multiple && files.isNotEmpty
                ? 'Replace'
                : 'Upload file',
            // A single-file field uploads one file at a time.
            onPressed: canUpload && (field.multiple || uploads.isEmpty)
                ? pick
                : null,
          ),
      ],
    );
  }
}

/// "412 KB", "1.4 MB", "980 B".
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// "PDF", "PNG"; "FILE" without an extension.
String _badgeOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'FILE';
  final ext = name.substring(dot + 1).toUpperCase();
  return ext.length > 4 ? ext.substring(0, 4) : ext;
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.child, this.hasError = false});

  final Widget child;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.xxs,
        Spacing.xxs,
        Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: hasError ? scheme.error : scheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: Radii.smAll,
        ),
        child: Text(
          _badgeOf(name),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color:
                theme.extension<MorkvaSemanticColors>()?.primaryText ??
                scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.hasError,
    required this.onOpen,
    required this.onRemove,
  });

  final FileAttachment attachment;
  final bool hasError;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = attachment.sizeBytes;
    return _TileFrame(
      hasError: hasError,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              link: onOpen != null,
              child: InkWell(
                onTap: onOpen,
                borderRadius: Radii.smAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      _TypeBadge(attachment.name),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              attachment.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            if (size != null)
                              Text(
                                formatFileSize(size),
                                style: MorkvaTypography.tabular(
                                  theme.textTheme.bodySmall ??
                                      const TextStyle(),
                                ).copyWith(color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove ${attachment.name}',
            onPressed: onRemove,
            iconSize: 18,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.upload});

  final PendingUpload upload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (upload.progress * 100).round();
    return _TileFrame(
      child: Padding(
        padding: const EdgeInsets.only(right: Spacing.xs),
        child: Row(
          children: [
            _TypeBadge(upload.name),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    upload.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs - Spacing.xxs / 2),
                  LinearProgressIndicator(
                    value: upload.progress,
                    minHeight: 4,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                    backgroundColor: scheme.surfaceContainerHigh,
                    semanticsLabel: 'Uploading ${upload.name}',
                    semanticsValue: '$percent%',
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            ExcludeSemantics(
              child: Text(
                '$percent%',
                style: MorkvaTypography.tabular(
                  theme.textTheme.bodySmall ?? const TextStyle(),
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashed "+ Upload file": 32 px tall with a padded 48 px hit area.
class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: theme.textTheme.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        backgroundBuilder: (context, states, child) => DashedRRect(
          color: scheme.outline,
          radius: Radii.sm,
          width: null,
          child: child,
        ),
      ),
    );
  }
}
