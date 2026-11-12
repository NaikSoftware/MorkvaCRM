import '../../../api/data/data_repository.dart' show WriteOrigin;
import 'capability.dart';
import 'envelope.dart';
import 'screen_context.dart';

export 'screen_context.dart';

/// What the user is looking at: the turn's [ScreenContext] snapshot.
typedef HarnessFocus = ScreenContext;

/// Everything a call runs under, set by the transport, never by the request.
///
/// The harness never reads the clock: [now] and [today] come from the host so
/// relative dates ("this month") are computed in the user's zone and tests can
/// inject any day.
final class HarnessContext {
  HarnessContext({
    required this.workspaceId,
    required this.actor,
    required this.grants,
    required this.now,
    required DateTime today,
    this.timeZoneName = '',
    this.focus,
    this.turnId,
    this.events,
    this.origin,
  }) : today = DateTime(today.year, today.month, today.day);

  /// The workspace the call reads and plans against (from `WorkspaceResolver`).
  final String workspaceId;
  final Actor actor;

  /// The effective grants: the user's access ∩ the client's grants.
  final Grants grants;

  /// The current instant.
  final DateTime now;

  /// The user's calendar day as a local-midnight [DateTime] (the same form
  /// `calendarDayOf` returns). Relative dates and `today`/`+3d` inputs expand
  /// from it.
  final DateTime today;

  /// Display text only (`Europe/Kyiv`); the harness has no tz database.
  final String timeZoneName;

  /// The screen the user sent the message from; null when they removed the
  /// context chip (then `@screen`, `@card` and `@selected` are refused).
  final HarnessFocus? focus;

  /// The turn this call belongs to, minted by `Harness.openTurn` for [actor].
  /// A request's own `turnId` wins over it.
  final String? turnId;

  /// Where progress events go; null when the caller does not listen.
  final Sink<HarnessEvent>? events;

  /// Who the card writes of a commit or undo are attributed to (the
  /// trigger seam, D5); null = a UI write.
  final WriteOrigin? origin;

  /// Sends [event] to [events], if anyone listens.
  void emit(HarnessEvent event) => events?.add(event);

  /// The same context bound to [turnId].
  HarnessContext withTurn(String? turnId) => HarnessContext(
    workspaceId: workspaceId,
    actor: actor,
    grants: grants,
    now: now,
    today: today,
    timeZoneName: timeZoneName,
    focus: focus,
    turnId: turnId,
    events: events,
    origin: origin,
  );
}
