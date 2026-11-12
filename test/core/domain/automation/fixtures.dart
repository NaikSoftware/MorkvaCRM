/// Shared automation fixtures.
library;

import 'package:morkva_crm/core/domain/automation/automation.dart';

/// The SDK's stamp-shipped-date example manifest.
Map<String, Object?> stampManifest() => {
  'id': 'stamp-shipped-date',
  'name': 'Stamp shipped date',
  'version': '1.0.0',
  'description': 'Sets a date field to today.',
  'author': 'Jane Doe',
  'apiVersion': 2,
  'permissions': {
    'capabilities': ['schema:read', 'data:read', 'data:write'],
  },
  'actions': [
    {
      'id': 'stamp',
      'label': 'Stamp shipped date',
      'scope': 'card',
      'icon': 'truck',
      'input': {
        'type': 'object',
        'required': ['dateField'],
        'properties': {
          'dateField': {
            'type': 'string',
            'title': 'Date field',
            'format': 'field',
          },
          'overwrite': {'type': 'boolean', 'default': false},
          'days': {
            'type': 'integer',
            'minimum': 0,
            'maximum': 30,
            'default': 1,
          },
          'mode': {
            'type': 'string',
            'enum': ['today', 'tomorrow'],
            'default': 'today',
          },
        },
      },
    },
  ],
};

final fixtureNow = DateTime.utc(2026, 11, 12, 10);

AutomationRecord automation({
  TriggerSpec trigger = const EventTrigger(
    kind: TriggerKind.cardUpdated,
    collectionId: 'c_orders',
    where: [
      {
        'field': 'f_status',
        'op': 'anyOf',
        'value': ['o_shipped'],
      },
      {'field': 'f_due', 'op': 'onDay', 'relative': 'today'},
    ],
    fields: ['f_status'],
  ),
  ApplyMode apply = ApplyMode.ask,
  String? autoBy,
  bool enabled = true,
  PausedReason? paused,
}) => AutomationRecord(
  id: 'a_1',
  name: 'Stamp date when shipped',
  enabled: enabled,
  moduleId: 'stamp-shipped-date',
  actionId: 'stamp',
  params: const {'dateField': 'f_shipped'},
  trigger: trigger,
  apply: apply,
  autoBy: autoBy,
  pausedReason: paused,
  createdBy: 'user:u1',
  createdAt: fixtureNow,
  updatedAt: fixtureNow,
);

GrantRecord consent({
  bool autoApply = false,
  GrantVia via = GrantVia.consentSheet,
}) => GrantRecord(
  moduleId: 'stamp-shipped-date',
  codeHash: 'sha256:abc',
  version: '1.0.0',
  codeBytes: 2100,
  caps: const ['schema:read', 'data:read', 'data:write'],
  collections: const ['c_orders'],
  autoApply: autoApply,
  grantedAt: fixtureNow,
  via: via,
);
