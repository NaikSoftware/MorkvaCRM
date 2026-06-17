import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/auth/auth_cubit.dart';
import '../../app/shell/brand_wordmark.dart';
import '../../design/design.dart';

/// The first screen a signed-out user sees: brand presence, a one-line value
/// proposition, and a single prominent "Continue with Google" action.
///
/// Dumb by design — it renders [AuthState] from [AuthCubit] and forwards the
/// button tap to [AuthCubit.signInWithGoogle]. No business logic lives here.
///
/// Layout follows the "Warm Carrot" system and `DESIGN.md` §8:
/// - On the expanded breakpoint (web / tablet ≥ 840dp) the content sits in a
///   centered [SurfaceCard] capped at [_cardMaxWidth] so the form has a calm,
///   focused measure on the cream canvas.
/// - On compact widths the same content fills the width with comfortable
///   gutters and touch targets, no card chrome competing for attention.
///
/// Errors are shown inline in a quiet warning area (never a dialog / JS alert),
/// so a failed sign-in reads as recoverable guidance rather than an alarm.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  /// Comfortable max measure for the centered sign-in card on wide screens.
  static const double _cardMaxWidth = 400;

  /// At/above this width we show the focused, centered card layout.
  static const double _expandedBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use the LayoutBuilder's own measurement of available width;
                // in this full-bleed scaffold it reflects the screen width.
                final isExpanded = constraints.maxWidth >= _expandedBreakpoint;
                final content = const _SignInContent();

                if (!isExpanded) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                    child: content,
                  );
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: SurfaceCard(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The brand + value line + sign-in action + inline error, shared by both the
/// compact and expanded layouts so the two never drift apart.
class _SignInContent extends StatelessWidget {
  const _SignInContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final loading = state is AuthLoading;
        final errorMessage = state is AuthError ? state.message : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand anchor — reuse the shell wordmark for one consistent mark.
            const Align(
              alignment: Alignment.centerLeft,
              child: BrandWordmark(extended: true),
            ),
            const SizedBox(height: Spacing.xl),
            Text('Welcome to your workspace', style: textTheme.headlineSmall),
            const SizedBox(height: Spacing.sm),
            Text(
              'One tidy home for your collections and cards — synced securely '
              'across every device you sign in on.',
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            _GoogleSignInButton(loading: loading),
            // While a sign-in is in flight, offer a way out: on web the Google
            // popup can be dismissed without the future ever settling, which
            // would otherwise leave this screen spinning forever.
            if (loading) ...[
              const SizedBox(height: Spacing.xs),
              TextActionButton(
                label: 'Cancel',
                onPressed: () => context.read<AuthCubit>().cancelSignIn(),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: Spacing.md),
              _InlineError(message: errorMessage),
            ],
            const SizedBox(height: Spacing.md),
            Text(
              'We only use your Google account to sign you in. '
              'Your data stays yours.',
              style: textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

/// Full-width carrot CTA carrying the inline Google "G" glyph. Delegates the
/// press to [AuthCubit.signInWithGoogle] and shows the [PrimaryButton] spinner
/// while a sign-in is in flight.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    // The carrot fill already carries the primary emphasis; the leading glyph
    // is the small white "G" disc so it reads as Google without a second
    // accent color competing with the carrot.
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = !loading;
    final fg = scheme.onPrimary;
    final bg = enabled
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.38);

    return PressableScale(
      onPressed: enabled
          ? () => context.read<AuthCubit>().signInWithGoogle()
          : null,
      semanticLabel: 'Continue with Google',
      borderRadius: Radii.mdAll,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        decoration: BoxDecoration(color: bg, borderRadius: Radii.mdAll),
        child: AnimatedSize(
          duration: reduceMotion ? MotionDurations.none : MotionDurations.fast,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else ...[
                const _GoogleGlyph(size: 18),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(
                    'Continue with Google',
                    style: textStyle?.copyWith(color: fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The Google "G" mark, drawn inline so we add no asset or dependency.
///
/// Rendered as the brand-correct four-color glyph on a white disc so it stays
/// legible on the carrot button fill. Decorative — hidden from semantics
/// because the surrounding button already announces "Continue with Google".
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size + Spacing.xs,
        height: size + Spacing.xs,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size.square(size * 0.78),
          painter: _GoogleGlyphPainter(),
        ),
      ),
    );
  }
}

/// Paints the multi-color Google "G" using its four official brand hues. These
/// are fixed brand constants (not theme colors) and intentionally exempt from
/// the no-hardcoded-color rule, like a logo asset would be.
class _GoogleGlyphPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, h - stroke);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs around the ring, in Google's color order (radians).
    void arc(double startDeg, double sweepDeg, Color color) {
      paint.color = color;
      canvas.drawArc(
        rect,
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-10, -80, _yellow); // lower-right rising to right
    arc(-90, -100, _green); // bottom-left
    arc(150, -90, _red); // top-left
    arc(60, -70, _blue); // top-right

    // The horizontal crossbar of the "G".
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, h * 0.42, w * 0.5 - stroke / 2, stroke),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGlyphPainter oldDelegate) => false;
}

/// A quiet, non-blocking inline error: a warning-tinted rounded strip with a
/// small icon and the failure [message]. Uses the semantic `warning` role (an
/// auth failure is recoverable guidance, not a hard system error) so it reads
/// as "try again", never as an alarm.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final fg = semantic.onWarning;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: semantic.warning.withValues(alpha: 0.16),
          borderRadius: Radii.mdAll,
          border: Border.all(color: semantic.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: fg),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
