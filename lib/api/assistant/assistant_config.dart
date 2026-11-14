import 'package:equatable/equatable.dart';

/// How much the model thinks before answering. `off` maps to the lowest level
/// the model supports (`ThinkingLevel.minimal` on Gemini 3.x).
enum AssistantThinking { off, low, medium, high }

/// The assistant's effective configuration: the admin-written global doc
/// (`config/assistant`), the user's feature flag (`featureFlags/{uid}`), merged over compiled defaults so a missing or malformed
/// doc never blocks the assistant.
///
/// Defaults follow the owner decisions and the T0 spike: one model
/// (`gemini-3.5-flash-lite`), no fallback, thinking off, 12 RPM (the free tier
/// allows 15), 6 rounds.
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
  });

  /// Builds the effective config from the raw docs; `null` means the doc is
  /// missing (or unreadable). Each field that is absent or of the wrong type
  /// falls back to its default on its own.
  factory AssistantConfig.resolve({
    Map<String, Object?>? global,
    Map<String, Object?>? userFlags,
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
  ];
}
