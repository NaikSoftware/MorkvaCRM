import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/domain/domain.dart';

/// The example templates bundled with the app (`assets/templates/`).
const kBundledTemplates = [
  'assets/templates/orders_pipeline.json',
  'assets/templates/production_materials.json',
];

/// The languages the bundled templates are translated to, besides English:
/// `orders_pipeline.uk.json` next to `orders_pipeline.json`.
const _translated = {'uk'};

/// Loads the bundled templates, in [kBundledTemplates] order, in
/// [languageCode] when they are translated to it (else English). Their names
/// become the user's data when added, so they are added in that language.
Future<List<WorkspaceTemplate>> loadBundledTemplates([
  AssetBundle? bundle,
  String? languageCode,
]) => Future.wait([
  for (final path in kBundledTemplates)
    (bundle ?? rootBundle)
        .loadString(
          _translated.contains(languageCode)
              ? path.replaceFirst('.json', '.$languageCode.json')
              : path,
        )
        .then(
          (text) => WorkspaceTemplate.fromJson(
            jsonDecode(text) as Map<String, dynamic>,
          ),
        ),
]);
