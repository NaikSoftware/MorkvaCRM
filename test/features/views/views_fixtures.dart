import 'package:morkva_crm/core/domain/domain.dart';

/// Shared fixtures for the views feature tests: a "Deals" collection with
/// every groupable kind of layout field and a "Companies" reference target.

const stageField = SingleSelectFieldDefinition(
  id: 'stage',
  name: 'Stage',
  options: [
    SelectOption(id: 'lead', label: 'Lead', color: '#3A7CA5'),
    SelectOption(id: 'won', label: 'Won', color: '#2E8B57'),
    SelectOption(id: 'lost', label: 'Lost', color: '#C0392B'),
  ],
);

const companyField = ReferenceFieldDefinition(
  id: 'company',
  name: 'Company',
  targetCollectionId: 'companies',
);

const dueField = DateFieldDefinition(id: 'due', name: 'Due');
const meetingField = DateFieldDefinition(
  id: 'meeting',
  name: 'Meeting',
  includeTime: true,
);

const tableView = ViewDefinition(
  id: 'all',
  name: 'All deals',
  fieldIds: ['name', 'amount', 'stage', 'company'],
);
const boardView = ViewDefinition(
  id: 'board',
  name: 'Pipeline',
  mode: ViewModeIds.board,
  layoutFieldId: 'stage',
  fieldIds: ['name', 'amount'],
);

const deals = Collection(
  id: 'deals',
  name: 'Deals',
  icon: 'handshake',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    NumberFieldDefinition(id: 'amount', name: 'Amount', unitLabel: 'USD'),
    stageField,
    companyField,
    dueField,
    meetingField,
  ],
  views: [tableView, boardView],
);

const companies = Collection(
  id: 'companies',
  name: 'Companies',
  fields: [TextFieldDefinition(id: 'cname', name: 'Name')],
  views: [
    ViewDefinition(
      id: 'all',
      name: 'All',
      fieldIds: ['cname'],
      sort: ViewSort(fieldId: 'cname'),
    ),
  ],
);

final t0 = DateTime.utc(2026, 3, 1, 9);

MorkvaObject deal(
  String id,
  int minute, {
  String? name,
  num? amount,
  String? stage,
  String? company,
  DateTime? due,
  DateTime? meeting,
}) => MorkvaObject.create(
  id: id,
  collection: deals,
  values: {
    if (name != null) 'name': TextFieldValue(name),
    if (amount != null) 'amount': NumberFieldValue(amount),
    if (stage != null) 'stage': SingleSelectFieldValue(stage),
    if (company != null) 'company': ReferenceFieldValue([company]),
    if (due != null) 'due': DateFieldValue(due),
    if (meeting != null) 'meeting': DateFieldValue(meeting),
  },
  createdAt: t0.add(Duration(minutes: minute)),
  updatedAt: t0.add(Duration(minutes: minute)),
);

MorkvaObject company(String id, String name, int minute) => MorkvaObject.create(
  id: id,
  collection: companies,
  values: {'cname': TextFieldValue(name)},
  createdAt: t0.add(Duration(minutes: minute)),
  updatedAt: t0.add(Duration(minutes: minute)),
);

/// Five deals: two leads, one won, one lost, one without a stage.
List<MorkvaObject> sampleDeals() => [
  deal(
    'd1',
    0,
    name: 'Acme renewal',
    amount: 1200,
    stage: 'lead',
    company: 'k2',
  ),
  deal('d2', 1, name: 'Globex pilot', amount: 300, stage: 'won', company: 'k1'),
  deal('d3', 2, name: 'Initech', amount: 50, stage: 'lead'),
  deal('d4', 3, name: 'Umbrella', stage: 'lost'),
  deal('d5', 4, name: 'Hooli'),
];
