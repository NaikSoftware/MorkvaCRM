import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../../collection_views_cubit.dart';
import '../../modes/view_mode.dart';
import '../object_card.dart';

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Mon 4 Nov".
String dayLabel(DateTime day) =>
    '${weekdayNames[day.weekday - 1]} ${day.day} ${_monthNames[day.month - 1]}';

/// Local midnight of [moment]'s calendar day (the [DayBuckets] key form).
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// The Monday on or before [day]. Built from components, never by adding
/// durations, so DST shifts can't skew the day.
DateTime weekStartOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Text-coloured carrot (AA on paper).
Color primaryTextColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<MorkvaSemanticColors>()?.primaryText ??
      theme.colorScheme.primary;
}

/// Moves [objectId] to [day] (null clears the date) and offers Undo.
void moveObjectToDay(
  BuildContext context,
  ViewModeData data,
  String objectId,
  DateTime? day,
) {
  final object = data.state.objectById(objectId);
  if (object == null) return;
  final undo = context.read<CollectionViewsCubit>().moveToDay(objectId, day);
  if (undo == null) return;
  final title = titleOf(data.state.activeView, data.state.collection, object);
  data.notify(
    day == null
        ? 'Cleared the date of "$title"'
        : 'Moved "$title" to ${dayLabel(day)}',
    undo: undo,
  );
}

/// A 24 px pill the user can drag to a day or the "No date" tray.
class CalendarPill extends StatelessWidget {
  const CalendarPill({super.key, required this.object, required this.data});

  final MorkvaObject object;
  final ViewModeData data;

  static const double feedbackWidth = 180;

  @override
  Widget build(BuildContext context) {
    final state = data.state;
    Widget pill({VoidCallback? onTap}) => ObjectCard(
      object: object,
      collection: state.collection,
      view: state.activeView,
      density: ObjectCardDensity.pill,
      referenceLabels: state.referenceLabels,
      onTap: onTap,
    );
    final child = pill(onTap: () => data.openObject(object));
    final feedback = Material(
      type: MaterialType.transparency,
      child: Container(
        width: feedbackWidth,
        decoration: const BoxDecoration(
          borderRadius: Radii.smAll,
          boxShadow: MorkvaElevation.level2,
        ),
        child: pill(),
      ),
    );
    final dragging = Opacity(opacity: 0.4, child: child);
    // A mouse drags at once; touch needs a long press so swipes still scroll.
    return _TouchDraggable(
      data: object.id,
      feedback: feedback,
      childWhenDragging: dragging,
      child: _MouseDraggable(
        data: object.id,
        feedback: feedback,
        childWhenDragging: dragging,
        child: child,
      ),
    );
  }
}

class _MouseDraggable extends Draggable<String> {
  const _MouseDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => ImmediateMultiDragGestureRecognizer(
    supportedDevices: const {PointerDeviceKind.mouse},
    allowedButtonsFilter: allowedButtonsFilter,
  )..onStart = onStart;
}

class _TouchDraggable extends LongPressDraggable<String> {
  const _TouchDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
  });

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => DelayedMultiDragGestureRecognizer(
    delay: delay,
    supportedDevices: const {
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.unknown,
    },
    allowedButtonsFilter: allowedButtonsFilter,
  )..onStart = onStart;
}
