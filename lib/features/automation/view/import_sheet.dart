import 'package:flutter/material.dart';

import '../../../core/domain/automation/automation.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../assistant/view/widgets/dashed_border.dart';
import '../bloc/modules_cubit.dart';
import '../widgets/reason_copy.dart';
import 'automations_page.dart';
import 'consent_sheet.dart';

/// The import sheet (UX §2): a `.morkva.json` from a file or pasted. Returns
/// the preview to consent to (never one with problems), or null.
Future<ImportPreview?> showImportSheet(
  BuildContext context, {
  required ImportPreview Function(String text) preview,
  required Future<({String name, String text})?> Function() pickFile,
}) => showAutomationSheet<ImportPreview>(
  context,
  builder: (_) => ImportSheet(preview: preview, pickFile: pickFile),
);

enum _Source { file, paste }

class ImportSheet extends StatefulWidget {
  const ImportSheet({super.key, required this.preview, required this.pickFile});

  final ImportPreview Function(String text) preview;
  final Future<({String name, String text})?> Function() pickFile;

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  _Source _source = _Source.file;
  final _paste = TextEditingController();
  String? _fileName;
  String _fileText = '';
  ImportPreview? _result;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  String get _text => _source == _Source.file ? _fileText : _paste.text;

  void _check() => setState(
    () => _result = _text.trim().isEmpty ? null : widget.preview(_text),
  );

  Future<void> _choose() async {
    final ({String name, String text})? file;
    try {
      file = await widget.pickFile();
    } on Object {
      // The browser refused to read the picked file (moved, or no access).
      if (mounted) {
        setState(
          () => _result = ImportPreview.problems([
            AutomationProblem(
              '',
              'unreadable',
              context.l10n.automationImportUnreadable,
            ),
          ]),
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    _fileName = file.name;
    _fileText = file.text;
    _check();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _result;
    final replacing = result?.replacing;
    final bundle = result?.bundle;
    final errorStyle = theme.textTheme.bodySmall?.copyWith(color: scheme.error);
    final l10n = context.l10n;

    final input = switch (_source) {
      _Source.file => DashedBorder(
        color: scheme.outline,
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            children: [
              if (automationsExpanded(context)) ...[
                Icon(
                  Icons.upload_file_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  // No drop target yet: dropping a file on Flutter web opens it in the tab.
                  _fileName ?? l10n.automationImportChooseFileHint,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.sm),
              ] else if (_fileName != null) ...[
                Text(_fileName!, style: theme.textTheme.bodyMedium),
                const SizedBox(height: Spacing.sm),
              ],
              SecondaryButton(
                label: l10n.automationImportChooseFile,
                icon: Icons.folder_open_outlined,
                onPressed: _choose,
              ),
            ],
          ),
        ),
      ),
      _Source.paste => MorkvaTextField(
        controller: _paste,
        hint: l10n.automationImportPasteHint,
        minLines: 8,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        onChanged: (_) => _check(),
      ),
    };

    return AutomationSheetFrame(
      header: SheetHeader(
        icon: Icons.upload_outlined,
        title: l10n.automationImportModule,
      ),
      body: [
        SegmentedButton<_Source>(
          segments: [
            ButtonSegment(
              value: _Source.file,
              label: Text(l10n.automationImportSourceFile),
            ),
            ButtonSegment(
              value: _Source.paste,
              label: Text(l10n.automationImportSourcePaste),
            ),
          ],
          selected: {_source},
          showSelectedIcon: false,
          style: sheetSegmentedStyle,
          onSelectionChanged: (s) {
            _source = s.single;
            _check();
          },
        ),
        const SizedBox(height: Spacing.md),
        // MorkvaTextField types in bodyLarge: make that mono for the paste.
        Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.copyWith(
              bodyLarge: MorkvaTypography.mono(theme.textTheme.bodyMedium!),
            ),
          ),
          child: input,
        ),
        if (result != null && result.problems.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in result.problems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xxs),
                    child: Text(
                      p.path.isEmpty ? p.message : '${p.path} — ${p.message}',
                      style: errorStyle,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (replacing != null &&
            bundle != null &&
            replacing.module.codeHash ==
                bundleHashOf(bundle.manifestJson, bundle.code)) ...[
          const SizedBox(height: Spacing.sm),
          AutomationBanner(
            tone: CopyTone.neutral,
            icon: Icons.check_circle_outline,
            title: l10n.automationImportSameVersion(bundle.manifest.version),
          ),
        ] else if (replacing != null && bundle != null) ...[
          const SizedBox(height: Spacing.sm),
          AutomationBanner(
            tone: CopyTone.warning,
            icon: Icons.swap_horiz,
            title: l10n.automationImportReplacingTitle(
              replacing.module.version,
            ),
            body: l10n.automationImportReplacingBody(
              replacing.automations,
              bundle.manifest.version,
            ),
          ),
        ],
        if (bundle != null && replacing == null) ...[
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Flexible(
                child: Text(
                  bundle.manifest.name,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: Spacing.xs),
              HugChip(
                label: 'v${bundle.manifest.version}',
                tone: CopyTone.neutral,
              ),
            ],
          ),
        ],
      ],
      footer: SheetFooter(
        buttons: [
          TextActionButton(
            label: l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
          PrimaryButton(
            label: l10n.commonContinue,
            onPressed: bundle == null
                ? null
                : () => Navigator.of(context).pop(result),
          ),
        ],
      ),
    );
  }
}
