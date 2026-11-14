import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/automation/widgets/action_buttons.dart' show maybeRead;
import '../../features/inbox/bloc/inbox_cubit.dart';

/// Builds with the Inbox badge count (my open tasks overdue or due today),
/// 0 where no [InboxCubit] is provided. Re-counts every minute too: the
/// cubit does not re-emit when the day turns over.
class InboxCountBuilder extends StatefulWidget {
  const InboxCountBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, int count) builder;

  @override
  State<InboxCountBuilder> createState() => _InboxCountBuilderState();
}

class _InboxCountBuilderState extends State<InboxCountBuilder> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = maybeRead<InboxCubit>(context);
    if (cubit == null) return widget.builder(context, 0);
    _tick ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
    return BlocBuilder<InboxCubit, InboxState>(
      bloc: cubit,
      builder: (context, _) => widget.builder(context, cubit.badgeCount),
    );
  }
}

/// The carrot count badge on an Inbox icon (rail, phone bar); none at 0.
class InboxBadgeIcon extends StatelessWidget {
  const InboxBadgeIcon({super.key, required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InboxCountBuilder(
      builder: (context, count) => Badge(
        isLabelVisible: count > 0,
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        label: Text('$count'),
        child: icon,
      ),
    );
  }
}
