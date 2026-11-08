import 'package:flutter/material.dart';

import '../collections/collections.dart';

/// The `/` page: All collections. Its [CollectionsListCubit] is the shell's,
/// shared with the sidebar.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      type: MaterialType.transparency,
      child: CollectionsListView(),
    );
  }
}
