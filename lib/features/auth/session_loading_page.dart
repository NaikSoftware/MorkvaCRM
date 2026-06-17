import 'package:flutter/material.dart';

import '../../design/design.dart';

/// The neutral interstitial shown while the session settles: the first auth
/// state is resolving, or a signed-in user's [DataRepository] is still being
/// initialized for their workspace.
///
/// Gating routing on this screen guarantees feature pages never mount before
/// `DataRepository.initialize()` completes — their `watch*` calls require an
/// initialized repository (the `_wid` getter throws otherwise).
class SessionLoadingPage extends StatelessWidget {
  const SessionLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const SafeArea(child: Center(child: LoadingIndicator())),
    );
  }
}
