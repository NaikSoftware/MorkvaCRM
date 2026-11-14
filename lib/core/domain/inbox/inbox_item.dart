import 'package:equatable/equatable.dart';

/// What an Inbox item is: a [task] (checkbox, can be done and overdue) or a
/// [note] (the owner's "notification": no checkbox, never overdue).
enum InboxKind {
  task,
  note;

  static InboxKind? fromWire(Object? wire) =>
      values.asNameMap()[wire is String ? wire : null];
}

/// The card an item points at. Card ids are unique only within their
/// collection, so both ids are kept; [label] is a display snapshot.
final class InboxLink extends Equatable {
  const InboxLink({
    required this.collectionId,
    required this.cardId,
    required this.label,
  });

  /// A link to a card titled [label], cut to [labelMax] (spec §5).
  InboxLink.toCard({
    required String collectionId,
    required String cardId,
    required String label,
  }) : this(
         collectionId: collectionId,
         cardId: cardId,
         label: label.length > labelMax ? label.substring(0, labelMax) : label,
       );

  static const labelMax = 200;

  final String collectionId;
  final String cardId;
  final String label;

  Map<String, Object?> toJson() => {
    'collectionId': collectionId,
    'cardId': cardId,
    'label': label,
  };

  static InboxLink fromJson(Map<String, Object?> json) => InboxLink(
    collectionId: _string(json['collectionId']),
    cardId: _string(json['cardId']),
    label: json['label'] is String ? json['label']! as String : '',
  );

  @override
  List<Object?> get props => [collectionId, cardId, label];
}

/// Reminder offsets, in wall-clock minutes before the due moment (an
/// all-day item's is its local midnight); negative = after it (spec §3, §5).
/// Any other offset is a custom date/time the user picked.
abstract final class InboxReminders {
  static const atStart = 0;
  static const min15 = 15;
  static const min30 = 30;

  static const timed = [atStart, min15, min30];

  /// An all-day item "starts" at 09:00: its presets are [timed] counted
  /// from then (-540 = 09:00, -525 = 08:45, -510 = 08:30).
  static const dayStart = 9 * 60;
  static const allDay = [
    atStart - dayStart,
    min15 - dayStart,
    min30 - dayStart,
  ];
  static const max = 3;

  /// The [timed] preset an all-day preset [offset] mirrors, and back.
  static int toTimed(int offset) => offset + dayStart;
  static int toAllDay(int offset) => offset - dayStart;

  /// The presets valid for an item with ([allDay] false) or without a time.
  static List<int> presetsFor({required bool allDay}) =>
      allDay ? InboxReminders.allDay : timed;

  /// When [offset] fires for local due moment [base] (wall-clock, DST-safe).
  static DateTime fireTime(DateTime base, int offset) => DateTime(
    base.year,
    base.month,
    base.day,
    base.hour,
    base.minute - offset,
    base.second,
    base.millisecond,
    base.microsecond,
  );

  /// The offset that fires at local wall-clock [at] for due moment [base].
  static int offsetFor(DateTime base, DateTime at) =>
      _wall(base).difference(_wall(at)).inMinutes;

  static DateTime _wall(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);
}

/// One Inbox entry (`workspaces/{wid}/inbox/{id}`, spec §5).
///
/// Dates are UTC [DateTime]s here; the repository maps them to Timestamps.
/// An all-day [dueAt] is UTC midnight of the calendar date.
final class InboxItem extends Equatable {
  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    this.details = '',
    this.dueAt,
    this.allDay = false,
    this.reminders = const [],
    this.link,
    required this.assigneeUid,
    required this.createdBy,
    this.done = false,
    this.doneAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static const titleMax = 500;
  static const detailsMax = 5000;

  final String id;
  final InboxKind kind;
  final String title;
  final String details;
  final DateTime? dueAt;
  final bool allDay;
  final List<int> reminders;
  final InboxLink? link;
  final String assigneeUid;
  final String createdBy;
  final bool done;
  final DateTime? doneAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTask => kind == InboxKind.task;
  bool get isOpen => !(isTask && done);

  /// The local calendar day the item belongs to, or null when undated.
  /// All-day: the UTC date parts (never `toLocal`); timed: the local date.
  DateTime? get day {
    final due = dueAt;
    if (due == null) return null;
    if (allDay) return DateTime(due.year, due.month, due.day);
    final l = due.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// The local due moment reminders count from: local midnight of [day]
  /// when all-day, else the local due time. Null when undated.
  DateTime? get reminderBase {
    final due = dueAt;
    if (due == null) return null;
    return allDay ? DateTime(due.year, due.month, due.day) : due.toLocal();
  }

  /// When each reminder fires, as local [DateTime]s in [reminders] order.
  /// Empty when undated or a done task.
  List<DateTime> get fireTimes {
    final base = reminderBase;
    if (base == null || !isOpen) return const [];
    return [for (final m in reminders) InboxReminders.fireTime(base, m)];
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'details': details,
    'dueAt': dueAt,
    'allDay': allDay,
    'reminders': reminders,
    'link': link?.toJson(),
    'assigneeUid': assigneeUid,
    'createdBy': createdBy,
    'done': done,
    'doneAt': doneAt,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// Throws [FormatException] for a malformed doc (the repository drops it).
  static InboxItem fromJson(String id, Map<String, Object?> json) {
    final kind =
        InboxKind.fromWire(json['kind']) ??
        (throw const FormatException('kind'));
    final title = _string(json['title']);
    final link = json['link'];
    final reminders = json['reminders'];
    return InboxItem(
      id: id,
      kind: kind,
      title: title,
      details: json['details'] is String ? json['details']! as String : '',
      dueAt: _date(json['dueAt']),
      allDay: json['allDay'] == true,
      reminders: [
        // A non-list is dropped, not a TypeError (readRecord skips only
        // FormatException).
        for (final r in reminders is List ? reminders : const [])
          if (r is num) r.toInt(),
      ],
      link: link is Map ? InboxLink.fromJson(link.cast()) : null,
      assigneeUid: _string(json['assigneeUid']),
      createdBy: _string(json['createdBy']),
      done: json['done'] == true,
      doneAt: _date(json['doneAt']),
      createdAt: _date(json['createdAt']) ?? DateTime.utc(1970),
      updatedAt: _date(json['updatedAt']) ?? DateTime.utc(1970),
    );
  }

  InboxItem copyWith({
    InboxKind? kind,
    String? title,
    String? details,
    DateTime? Function()? dueAt,
    bool? allDay,
    List<int>? reminders,
    InboxLink? Function()? link,
    String? assigneeUid,
    bool? done,
    DateTime? Function()? doneAt,
    DateTime? updatedAt,
  }) => InboxItem(
    id: id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    details: details ?? this.details,
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    allDay: allDay ?? this.allDay,
    reminders: reminders ?? this.reminders,
    link: link == null ? this.link : link(),
    assigneeUid: assigneeUid ?? this.assigneeUid,
    createdBy: createdBy,
    done: done ?? this.done,
    doneAt: doneAt == null ? this.doneAt : doneAt(),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    details,
    dueAt,
    allDay,
    reminders,
    link,
    assigneeUid,
    createdBy,
    done,
    doneAt,
    createdAt,
    updatedAt,
  ];
}

String _string(Object? v) =>
    v is String && v.isNotEmpty ? v : throw const FormatException('string');

DateTime? _date(Object? v) => v is DateTime ? v.toUtc() : null;
