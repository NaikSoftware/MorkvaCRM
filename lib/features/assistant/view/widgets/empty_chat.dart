import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import '../../bloc/assistant_state.dart';
import 'assistant_scope.dart';
import 'sparkle_icon.dart';

/// The first open: a greeting with the user's first name, what the assistant
/// can reach, and Ask / Analyze / Act suggestions filled with the
/// workspace's real collection names. Before the workspace opted in, the
/// suggestions give way to the data-use disclosure and "Enable Ask Morkva".
class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key, required this.state});

  final AssistantState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = state.collectionNames;
    final name = state.userFirstName?.trim();
    final l10n = context.l10n;
    final consent = state.availability is AvailabilityNeedsConsent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 16),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.onSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SparkleIcon(size: 28, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            name == null || name.isEmpty
                ? l10n.assistantGreeting
                : l10n.assistantGreetingNamed(name),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          names.length == 1
              ? l10n.assistantIntroOne(names.single)
              : l10n.assistantIntro(names.length),
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        if (consent)
          _ConsentCard(
            freeTier: (state.availability as AvailabilityNeedsConsent).freeTier,
          )
        else
          for (final group in suggestionGroups(
            names,
            focused: state.focus?.collectionName,
            l10n: l10n,
          )) ...[
            _SuggestionGroup(group: group, enabled: state.availability.canSend),
            const SizedBox(height: 22),
          ],
      ],
    );
  }
}

/// One of the empty state's suggestion groups.
typedef SuggestionGroup = ({
  String title,
  SuggestionKind kind,
  List<String> items,
});

enum SuggestionKind { ask, analyze, act }

/// Ask / Analyze / Act prompts: generic templates filled with the first
/// collections' names, or plain starters when there are none. The
/// [focused] collection (the one on screen) fills Ask and Analyze. English
/// without [l10n].
List<SuggestionGroup> suggestionGroups(
  List<String> names, {
  String? focused,
  AppLocalizations? l10n,
}) {
  final t = l10n ?? lookupAppLocalizations(const Locale('en'));
  if (names.isEmpty) {
    return [
      (
        title: t.assistantSuggestAsk,
        kind: SuggestionKind.ask,
        items: [t.assistantSuggestHelp],
      ),
      (
        title: t.assistantSuggestAct,
        kind: SuggestionKind.act,
        items: [
          t.assistantSuggestCreateClients,
          t.assistantSuggestSetUpOrders,
        ],
      ),
    ];
  }
  final a = names[0];
  final b = names.length > 1 ? names[1] : names[0];
  final f = focused == null || focused.isEmpty ? null : focused;
  return [
    (
      title: t.assistantSuggestAsk,
      kind: SuggestionKind.ask,
      items: [
        t.assistantSuggestHowMany(f ?? a),
        t.assistantSuggestNewest(f ?? b),
      ],
    ),
    (
      title: t.assistantSuggestAnalyze,
      kind: SuggestionKind.analyze,
      items: [
        t.assistantSuggestByMonth(f ?? a),
        t.assistantSuggestCompare(f ?? b),
      ],
    ),
    (
      title: t.assistantSuggestAct,
      kind: SuggestionKind.act,
      items: [t.assistantSuggestLinked(a), t.assistantSuggestNotes(b)],
    ),
  ];
}

class _SuggestionGroup extends StatelessWidget {
  const _SuggestionGroup({required this.group, required this.enabled});

  final SuggestionGroup group;

  /// Whether a tap can send (it cannot while the composer is disabled).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final actions = AssistantScope.of(context).actions;
    final tints = scheme.brightness == Brightness.dark
        ? CollectionTints.dark
        : CollectionTints.light;
    // sky = ask, leaf = analyze, carrot = act (as drawn).
    final (tint, icon) = switch (group.kind) {
      SuggestionKind.ask => (tints[2], Icons.search_rounded),
      SuggestionKind.analyze => (tints[1], Icons.bar_chart_rounded),
      SuggestionKind.act => (tints[0], Icons.edit_outlined),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            group.title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.88,
            ),
          ),
        ),
        for (final text in group.items) ...[
          const SizedBox(height: Spacing.xs),
          PressableScale(
            onPressed: enabled ? () => actions.suggest(text) : null,
            semanticLabel: text,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: tint.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: tint.foreground),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The data-use disclosure shown before the workspace opts in.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.freeTier});

  final bool freeTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AssistantColors.of(context);
    final actions = AssistantScope.of(context).actions;
    final body = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.assistantConsentTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            context.l10n.assistantConsentData,
            style: body,
          ),
          if (freeTier) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              context.l10n.assistantConsentFreeTier,
              style: body,
            ),
          ],
          const SizedBox(height: Spacing.xs),
          Text(context.l10n.assistantDisclaimer, style: body),
          const SizedBox(height: Spacing.md),
          PrimaryButton(
            label: context.l10n.assistantEnable,
            icon: Icons.check_rounded,
            onPressed: actions.grantConsent,
          ),
        ],
      ),
    );
  }
}

/// Ask Morkva can't run here: the flag is off, it isn't set up, or the
/// service refused. The chat behind stays hidden.
class AssistantUnavailable extends StatelessWidget {
  const AssistantUnavailable({super.key, required this.availability});

  final Availability availability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, message) = switch (availability) {
      AvailabilityDisabledByFlag() => (
        l10n.assistantOffTitle,
        l10n.assistantOffBody,
      ),
      AvailabilityNotSetUp() => (
        l10n.assistantNotSetUpTitle,
        l10n.assistantNotSetUpBody,
      ),
      AvailabilityUnavailable(:final message) => (
        l10n.assistantUnavailableTitle,
        message,
      ),
      _ => (l10n.assistantUnavailableTitle, l10n.assistantTryLater),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.lg),
        child: EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: title,
          message: message,
        ),
      ),
    );
  }
}
