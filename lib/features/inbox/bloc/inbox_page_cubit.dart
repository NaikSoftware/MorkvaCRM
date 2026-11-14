import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/inbox/inbox.dart';

/// What an item will be once saved: the composer's and the editor's
/// working copy. [date] is a local calendar day (midnight), [minutes] the
/// time of day (null = all-day).
final class InboxDraft extends Equatable {
  const InboxDraft({
    this.kind = InboxKind.task,
    this.title = '',
    this.details = '',
    this.date,
    this.minutes,
    this.reminders = const [],
    this.link,
  });

  factory InboxDraft.of(InboxItem item) {
    final due = item.dueAt;
    final local = due?.toLocal();
    return InboxDraft(
      kind: item.kind,
      title: item.title,
      details: item.details,
      date: item.day,
      minutes: local == null || item.allDay
          ? null
          : local.hour * 60 + local.minute,
      reminders: item.reminders,
      link: item.link,
    );
  }

  final InboxKind kind;
  final String title;
  final String details;
  final DateTime? date;
  final int? minutes;
  final List<int> reminders;
  final InboxLink? link;

  bool get allDay => minutes == null;

  /// The stored `dueAt`: UTC midnight of [date] when all-day, else the
  /// local instant as UTC.
  DateTime? get dueAt {
    final d = date;
    if (d == null) return null;
    final m = minutes;
    if (m == null) return allDayDue(d);
    return DateTime(d.year, d.month, d.day, m ~/ 60, m % 60).toUtc();
  }

  InboxDraft copyWith({
    InboxKind? kind,
    String? title,
    String? details,
    InboxLink? Function()? link,
  }) => InboxDraft(
    kind: kind ?? this.kind,
    title: title ?? this.title,
    details: details ?? this.details,
    date: date,
    minutes: minutes,
    reminders: reminders,
    link: link == null ? this.link : link(),
  );

  /// Clearing the date clears the time and the reminders (they need one).
  InboxDraft withDate(DateTime? date) => InboxDraft(
    kind: kind,
    title: title,
    details: details,
    date: date == null ? null : DateTime(date.year, date.month, date.day),
    minutes: date == null ? null : minutes,
    reminders: date == null ? const [] : reminders,
    link: link,
  );

  /// Setting a time adds "At time"; switching between timed and all-day
  /// drops the reminders no longer valid. Needs a [date].
  InboxDraft withMinutes(int? minutes) {
    if (date == null) return this;
    final allDay = minutes == null;
    return InboxDraft(
      kind: kind,
      title: title,
      details: details,
      date: date,
      minutes: minutes,
      reminders: validReminders([
        ...reminders,
        if (this.minutes == null && !allDay) InboxReminders.atTime,
      ], allDay: allDay),
      link: link,
    );
  }

  /// Adds or removes reminder [minutes]; at most [InboxReminders.max].
  InboxDraft toggleReminder(int offset) => InboxDraft(
    kind: kind,
    title: title,
    details: details,
    date: date,
    minutes: minutes,
    reminders: reminders.contains(offset)
        ? [
            for (final r in reminders)
              if (r != offset) r,
          ]
        : validReminders([...reminders, offset], allDay: allDay),
    link: link,
  );

  /// The new item this draft describes (title trimmed).
  InboxItem toItem({
    required String id,
    required String uid,
    required DateTime now,
  }) => InboxItem(
    id: id,
    kind: kind,
    title: _clamp(title.trim(), InboxItem.titleMax),
    details: _clamp(details.trim(), InboxItem.detailsMax),
    dueAt: dueAt,
    allDay: date != null && allDay,
    reminders: date == null ? const [] : reminders,
    link: link,
    assigneeUid: uid,
    createdBy: uid,
    createdAt: now.toUtc(),
    updatedAt: now.toUtc(),
  );

  /// The fields of [original] this draft changes, as `InboxItem.toJson`
  /// keys and values (a `done` set elsewhere is never overwritten).
  Map<String, Object?> changesFrom(InboxItem original) {
    final next = toItem(
      id: original.id,
      uid: original.createdBy,
      now: original.createdAt,
    );
    // The draft holds minutes: rebuilding an unchanged dueAt can move it
    // (seconds, the second 01:30 of a DST fall-back), so compare drafts.
    final base = InboxDraft.of(original);
    return {
      if (next.kind != original.kind) 'kind': next.kind.name,
      if (next.title != original.title) 'title': next.title,
      if (next.details != original.details) 'details': next.details,
      if (date != base.date || minutes != base.minutes) 'dueAt': next.dueAt,
      if (next.allDay != original.allDay) 'allDay': next.allDay,
      if (!listEquals(next.reminders, original.reminders))
        'reminders': next.reminders,
      if (next.link != original.link) 'link': next.link?.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    kind,
    title,
    details,
    date,
    minutes,
    reminders,
    link,
  ];
}

/// The item editor's working copy, from [initial].
class InboxDraftCubit extends Cubit<InboxDraft> {
  InboxDraftCubit(this.initial) : super(initial);

  final InboxDraft initial;

  bool get dirty => state != initial;

  void edit(InboxDraft Function(InboxDraft d) change) => emit(change(state));
}

/// The Inbox page: the selected day and the composer's chips.
final class InboxPageState extends Equatable {
  const InboxPageState({
    required this.day,
    required this.today,
    this.draft = const InboxDraft(),
    this.dateTouched = false,
  });

  /// The selected local day (midnight).
  final DateTime day;

  /// Today's local day, as of the last selection.
  final DateTime today;

  /// The composer's kind, time, reminders and link; its date is
  /// [draft.date] only once [dateTouched], else [composerDate].
  final InboxDraft draft;

  /// The user picked or cleared the date: a kind toggle keeps it.
  final bool dateTouched;

  /// A task defaults to the selected day (today when that is past, so a
  /// task is never born overdue); a note to No date.
  DateTime? get composerDate {
    if (dateTouched) return draft.date;
    if (draft.kind == InboxKind.note) return null;
    return day.isBefore(today) ? today : day;
  }

  /// The composer's draft with its effective date.
  InboxDraft get composer {
    final date = composerDate;
    return InboxDraft(
      kind: draft.kind,
      date: date,
      minutes: date == null ? null : draft.minutes,
      reminders: date == null ? const [] : draft.reminders,
      link: draft.link,
    );
  }

  InboxPageState copyWith({
    DateTime? day,
    DateTime? today,
    InboxDraft? draft,
    bool? dateTouched,
  }) => InboxPageState(
    day: day ?? this.day,
    today: today ?? this.today,
    draft: draft ?? this.draft,
    dateTouched: dateTouched ?? this.dateTouched,
  );

  @override
  List<Object?> get props => [day, today, draft, dateTouched];
}

/// The Inbox page's selected day and composer draft.
class InboxPageCubit extends Cubit<InboxPageState> {
  InboxPageCubit({DateTime? day, DateTime Function() now = DateTime.now})
    : _now = now,
      super(
        InboxPageState(
          day: day == null
              ? localDay(now())
              : DateTime(day.year, day.month, day.day),
          today: localDay(now()),
        ),
      );

  final DateTime Function() _now;

  DateTime get now => _now();

  void selectDay(DateTime day) => emit(
    state.copyWith(
      day: DateTime(day.year, day.month, day.day),
      today: localDay(_now()),
    ),
  );

  /// Moves the selection by [weeks].
  void moveWeek(int weeks) {
    final d = state.day;
    selectDay(DateTime(d.year, d.month, d.day + 7 * weeks));
  }

  void toggleKind() => _edit(
    (d) => d.copyWith(
      kind: d.kind == InboxKind.task ? InboxKind.note : InboxKind.task,
    ),
  );

  void setDate(DateTime? date) => emit(
    state.copyWith(draft: state.composer.withDate(date), dateTouched: true),
  );

  void setMinutes(int? minutes) => _edit((d) => d.withMinutes(minutes));

  void toggleReminder(int offset) => _edit((d) => d.toggleReminder(offset));

  void setLink(InboxLink? link) => _edit((d) => d.copyWith(link: () => link));

  /// The composer's chips over the effective date, so time/reminder edits
  /// apply to what is shown.
  void _edit(InboxDraft Function(InboxDraft d) change) {
    final composer = state.composer;
    final next = change(composer);
    emit(
      state.copyWith(
        draft: state.dateTouched
            ? next
            : InboxDraft(
                kind: next.kind,
                // Untouched: the date stays derived (follows day and kind).
                minutes: next.minutes,
                reminders: next.reminders,
                link: next.link,
              ),
      ),
    );
  }

  /// The item [title] makes, or null when blank. Resets the chips (the
  /// kind stays) for the next one.
  InboxItem? create({
    required String title,
    required String id,
    required String uid,
  }) {
    if (title.trim().isEmpty) return null;
    // A tab left open past midnight: "today" is now.
    emit(state.copyWith(today: localDay(_now())));
    final item = state.composer
        .copyWith(title: title)
        .toItem(id: id, uid: uid, now: _now());
    emit(
      InboxPageState(
        day: state.day,
        today: localDay(_now()),
        draft: InboxDraft(kind: state.draft.kind),
      ),
    );
    return item;
  }
}

String _clamp(String s, int max) => s.length > max ? s.substring(0, max) : s;
