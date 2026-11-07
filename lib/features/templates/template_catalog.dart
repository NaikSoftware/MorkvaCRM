import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/domain/domain.dart';

/// The example templates bundled with the app (`assets/templates/`).
const kBundledTemplates = [
  'assets/templates/orders_pipeline.json',
  'assets/templates/production_materials.json',
];

/// Loads the bundled templates, in [kBundledTemplates] order.
Future<List<WorkspaceTemplate>> loadBundledTemplates([AssetBundle? bundle]) =>
    Future.wait([
      for (final path in kBundledTemplates)
        (bundle ?? rootBundle)
            .loadString(path)
            .then(
              (text) => WorkspaceTemplate.fromJson(
                jsonDecode(text) as Map<String, dynamic>,
              ),
            ),
    ]);
