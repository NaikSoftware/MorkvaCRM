/// Records for the automation cubit tests.
library;

import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';

import '../../../core/domain/automation/fixtures.dart';

export '../../../automation/fakes/fake_runner.dart';
export '../../../automation/fakes/fake_stores.dart';
export '../../../core/domain/automation/fixtures.dart';

const uid = 'u1';
const stampId = 'stamp-shipped-date';

ModuleBundle stampBundle({
  String code = 'morkva.action("stamp", () => {});',
  String version = '1.0.0',
  List<String>? caps,
}) => ModuleBundle.of({
  ...stampManifest(),
  'version': version,
  if (caps != null) 'permissions': {'capabilities': caps},
}, code);

ModuleRecord stampModule({ModuleBundle? bundle}) => ModuleRecord.fromBundle(
  bundle ?? stampBundle(),
  source: ModuleSource.import,
  createdBy: 'user:$uid',
  now: fixtureNow,
);

/// A consent to exactly [module].
GrantRecord consentTo(
  ModuleRecord module, {
  bool autoApply = false,
  List<String>? collections = const ['c_orders'],
}) => GrantRecord(
  moduleId: module.id,
  codeHash: module.bundleHash,
  version: module.version,
  codeBytes: module.codeBytes,
  caps: module.manifest!.capabilities,
  collections: collections,
  autoApply: autoApply,
  grantedAt: fixtureNow,
  via: GrantVia.consentSheet,
);

final orders = Collection(
  id: 'c_orders',
  name: 'Orders',
  fields: [
    TextFieldDefinition(id: 'f_title', name: 'Title'),
    DateFieldDefinition(id: 'f_shipped', name: 'Shipped on'),
  ],
);

final clients = Collection(
  id: 'c_clients',
  name: 'Clients',
  fields: [TextFieldDefinition(id: 'f_name', name: 'Name')],
);

RunRecord runRecord(
  String id, {
  RunStatus status = RunStatus.succeeded,
  RunReason? reason,
  String sessionId = 't_test',
  String? automationId = 'a_1',
  DateTime? startedAt,
  DateTime? endedAt,
  DateTime? applyStartedAt,
  String? journalId,
  DateTime? undoneAt,
  RunReceipt? receipt,
  TriggerKind kind = TriggerKind.button,
  String cardId = 'b_1042',
  List<String> touched = const [],
  String moduleId = stampId,
  RunError? error,
  DateTime? changedAt,
  Map<String, Object?>? params,
}) => RunRecord(
  id: id,
  params: params,
  status: status,
  reason: reason,
  moduleId: moduleId,
  moduleName: 'Stamp shipped date',
  moduleVersion: '1.0.0',
  codeHash: 'sha256:x',
  actionId: 'stamp',
  actionLabel: 'Stamp shipped date',
  automationId: automationId,
  automationName: 'Stamp when shipped',
  trigger: RunTrigger(
    kind: kind,
    collectionId: 'c_orders',
    cardId: cardId,
    cardLabel: '#1042',
    changedAt: changedAt,
  ),
  apply: ApplyMode.ask,
  by: 'user:$uid',
  device: 'web',
  sessionId: sessionId,
  startedAt: startedAt ?? fixtureNow,
  endedAt: endedAt,
  applyStartedAt: applyStartedAt,
  journalId: journalId,
  undoneAt: undoneAt,
  receipt: receipt,
  touchedCardIds: touched,
  error: error,
);

RunView runView(
  String runId, {
  RunStatus status = RunStatus.running,
  TriggerKind kind = TriggerKind.button,
  DateTime? startedAt,
  String automationId = 'a_1',
}) => RunView(
  runId: runId,
  automationId: automationId,
  moduleId: stampId,
  actionId: 'stamp',
  label: 'Mark shipped',
  status: status,
  trigger: RunTrigger(kind: kind, collectionId: 'c_orders', cardId: 'b_1042'),
  startedAt: startedAt ?? fixtureNow,
);

/// Lets the stores' and the runner's stream events land.
Future<void> settle() => Future<void>.delayed(Duration.zero);
