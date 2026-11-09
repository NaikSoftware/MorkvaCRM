import 'package:equatable/equatable.dart';

/// How much the model thinks before answering. `off` maps to the lowest level
/// the model supports (`ThinkingLevel.minimal` on Gemini 3.x).
enum AssistantThinking { off, low, medium, high }

/// The Gemini data-use terms the project runs under; drives the consent
/// disclosure ("on the free tier, may be used to improve Google products").
enum AssistantDataUse { free, paid }

/// Per-workspace opt-in to Ask Morkva
/// (`workspaces/{wid}/config/assistant {consentedBy, consentedAt}`).
final class AssistantConsent extends Equatable {
  const AssistantConsent({required this.consentedBy, this.consentedAt});

  /// The uid that enabled the assistant for the workspace.
  final String consentedBy;

  /// When it was enabled (UTC), if recorded.
  final DateTime? consentedAt;

  @override
  List<Object?> get props => [consentedBy, consentedAt];
}

/// The assistant's effective configuration: the admin-written global doc
/// (`config/assistant`), the user's feature flag (`featureFlags/{uid}`) and the
/// workspace consent, merged over compiled defaults so a missing or malformed
/// doc never blocks the assistant.
///
/// Defaults follow the owner decisions and the T0 spike: one model
/// (`gemini-3.5-flash-lite`), no fallback, thinking off, 12 RPM (the free tier
/// allows 15), 6 rounds, free-tier data use.
final class AssistantConfig extends Equatable {
  const AssistantConfig({
    this.enabled = true,
    this.model = defaultModel,
    this.fallbackModel,
    this.thinking = AssistantThinking.off,
    this.rpm = 12,
    this.tpm,
    this.maxRounds = 6,
    this.dailyTurnsSoft = 200,
    this.leaseTtlMinutes = 5,
    this.dataUse = AssistantDataUse.free,
    this.consent,
  });

  /// Builds the effective config from the raw docs; `null` means the doc is
  /// missing (or unreadable). Each field that is absent or of the wrong type
  /// falls back to its default on its own.
  factory AssistantConfig.resolve({
    Map<String, Object?>? global,
    Map<String, Object?>? userFlags,
    AssistantConsent? consent,
  }) {
    final g = global ?? const {};
    return AssistantConfig(
      enabled: switch ((userFlags?['assistant'], g['enabled'])) {
        (final bool flag, _) => flag,
        (_, final bool enabled) => enabled,
        _ => true,
      },
      model: _name(g['model']) ?? defaultModel,
      fallbackModel: _name(g['fallbackModel']),
      thinking:
          AssistantThinking.values.asNameMap()[g['thinking']] ??
          AssistantThinking.off,
      rpm: _positive(g['rpm']) ?? 12,
      tpm: _positive(g['tpm']),
      maxRounds: _positive(g['maxRounds']) ?? 6,
      dailyTurnsSoft: _positive(g['dailyTurnsSoft']) ?? 200,
      leaseTtlMinutes: _positive(g['leaseTtlMinutes']) ?? 5,
      dataUse:
          AssistantDataUse.values.asNameMap()[g['dataUse']] ??
          AssistantDataUse.free,
      consent: consent,
    );
  }

  /// The compiled model id.
  static const defaultModel = 'gemini-3.5-flash-lite';

  /// The config with no docs at all.
  static const defaults = AssistantConfig();

  /// Global switch, overridden per user by `featureFlags/{uid}.assistant`.
  /// UX only, not a security control.
  final bool enabled;

  final String model;

  /// Used only after quota errors, and only when an admin sets one.
  final String? fallbackModel;

  final AssistantThinking thinking;

  /// Client requests-per-minute bucket (advisory; the real limit is server-side).
  final int rpm;

  /// Client tokens-per-minute bucket; `null` means no TPM bucket.
  final int? tpm;

  /// Model rounds per user turn; the last one must answer in text.
  final int maxRounds;

  /// Local daily turn counter's soft limit.
  final int dailyTurnsSoft;

  /// Idle minutes before a released collection lease is unsubscribed.
  final int leaseTtlMinutes;

  final AssistantDataUse dataUse;

  /// The workspace's opt-in; `null` until a member enables the assistant.
  final AssistantConsent? consent;

  bool get consented => consent != null;

  static String? _name(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int? _positive(Object? value) =>
      value is num && value.isFinite && value >= 1 ? value.toInt() : null;

  @override
  List<Object?> get props => [
    enabled,
    model,
    fallbackModel,
    thinking,
    rpm,
    tpm,
    maxRounds,
    dailyTurnsSoft,
    leaseTtlMinutes,
    dataUse,
    consent,
  ];
}
