import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api.dart';
import '../collections/collections.dart';

/// The home surface — the user's collections.
///
/// Hosts a [CollectionsListCubit] bound to the workspace [DataRepository] and
/// renders the [CollectionsListView] (empty / loading / error / populated). The
/// shell only mounts this page once the session is ready (the router gate), so
/// the repository is already initialized when the cubit subscribes.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CollectionsListCubit(context.read<DataRepository>())..initialize(),
      child: const CollectionsListView(),
    );
  }
}
