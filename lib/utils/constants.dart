import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// SimulColors
///
/// The original static consts are KEPT UNCHANGED (they are the DARK palette)
/// so every existing `SimulColors.black` / `.white` reference still compiles.
///
/// For the new light/dark system, use `SimulColors.of(context)` which returns
/// a [SimulPalette] whose values flip with the active [Brightness]. Any widget
/// you migrate to light-mode should read colors from that palette instead of
/// the static consts.
/// ─────────────────────────────────────────────────────────────────────────
class SimulColors {
  // ── DARK palette (legacy static consts — do not remove) ──────────────────
  static const Color black    = Color(0xFF0A0A0A);
  static const Color surface  = Color(0xFF111111);
  static const Color card     = Color(0xFF1A1A1A);
  static const Color border   = Color(0xFF2A2A2A);
  static const Color muted    = Color(0xFF3A3A3A);
  static const Color subtle   = Color(0xFF555555);
  static const Color faint    = Color(0xFF888888);
  static const Color white    = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F5);
  static const Color accent   = Color(0xFFE0E0E0);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // Screen-share accent (theme independent)
  static const Color shareActive = Color(0xFF8B5CF6);

  // Legacy aliases
  static const Color pink      = accent;
  static const Color pinkLight = faint;
  static const Color darkGray  = card;

  /// Returns the palette that matches the current theme brightness.
  /// Usage: `final c = SimulColors.of(context); ... color: c.text`
  static SimulPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? SimulPalette.light
          : SimulPalette.dark;

  /// Backwards-compatible getter — returns the DARK theme.
  /// Prefer `SimulTheme.dark` / `SimulTheme.light` directly.
  static ThemeData get theme => SimulTheme.dark;
}

/// A brightness-aware set of semantic colors. Migrate widgets to read from
/// this (via `SimulColors.of(context)`) so they respond to light/dark.
@immutable
class SimulPalette {
  final Color bg;        // scaffold background
  final Color surface;   // panels / sidebars
  final Color card;      // cards / inputs
  final Color border;    // hairlines
  final Color muted;     // disabled / dividers
  final Color subtle;    // tertiary text
  final Color faint;     // secondary text
  final Color text;      // primary text
  final Color textInverse; // text on primary buttons
  final Color accent;
  final Color shadow;

  const SimulPalette({
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.muted,
    required this.subtle,
    required this.faint,
    required this.text,
    required this.textInverse,
    required this.accent,
    required this.shadow,
  });

  // Theme-independent semantic colors.
  Color get success => SimulColors.success;
  Color get warning => SimulColors.warning;
  Color get error   => SimulColors.error;
  Color get info    => SimulColors.info;
  Color get shareActive => SimulColors.shareActive;

  static const SimulPalette dark = SimulPalette(
    bg:          Color(0xFF0A0A0A),
    surface:     Color(0xFF111111),
    card:        Color(0xFF1A1A1A),
    border:      Color(0xFF2A2A2A),
    muted:       Color(0xFF3A3A3A),
    subtle:      Color(0xFF555555),
    faint:       Color(0xFF888888),
    text:        Color(0xFFFFFFFF),
    textInverse: Color(0xFF0A0A0A),
    accent:      Color(0xFFE0E0E0),
    shadow:      Color(0x66000000),
  );

  static const SimulPalette light = SimulPalette(
    bg:          Color(0xFFFAFAFA),
    surface:     Color(0xFFFFFFFF),
    card:        Color(0xFFF2F2F3),
    border:      Color(0xFFE2E2E5),
    muted:       Color(0xFFCFCFD4),
    subtle:      Color(0xFF9A9AA2),
    faint:       Color(0xFF6B6B73),
    text:        Color(0xFF14141A),
    textInverse: Color(0xFFFFFFFF),
    accent:      Color(0xFF2A2A2A),
    shadow:      Color(0x22000000),
  );
}

/// Both ThemeData objects. Wire them into MaterialApp as `theme:` /
/// `darkTheme:` and drive with `themeMode`.
class SimulTheme {
  static ThemeData _base(SimulPalette p, Brightness b) => ThemeData(
        brightness: b,
        scaffoldBackgroundColor: p.bg,
        primaryColor: p.text,
        colorScheme: ColorScheme(
          brightness: b,
          primary: p.text,
          onPrimary: p.textInverse,
          secondary: p.accent,
          onSecondary: p.textInverse,
          surface: p.surface,
          onSurface: p.text,
          error: SimulColors.error,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: p.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: p.text),
          titleTextStyle: TextStyle(
            color: p.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: p.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: p.text, width: 1.5),
          ),
          labelStyle: TextStyle(color: p.faint),
          hintStyle: TextStyle(color: p.subtle),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: p.text,
            foregroundColor: p.textInverse,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: p.text,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: DividerThemeData(color: p.border, thickness: 1),
        cardColor: p.card,
        canvasColor: p.surface,
      );

  static ThemeData get dark  => _base(SimulPalette.dark, Brightness.dark);
  static ThemeData get light => _base(SimulPalette.light, Brightness.light);
}

class AppStrings {
  static const String appName  = 'SIMUL';
  static const String tagline  = 'Watch together, in sync.';
  static const String waitingForPartner = 'Waiting for someone to join…';
  static const String partnerJoined    = 'Partner joined';
  static const String connected        = 'Live';
  static const String disconnected     = 'Offline';
}

/// LiveKit + backend configuration.
class AppConfig {
  // Set via: flutter run --dart-define=USE_PRODUCTION=true
  static const bool useProduction =
      bool.fromEnvironment('USE_PRODUCTION', defaultValue: false);

  // ── Local development (livekit-server --dev + local token server) ────────
  static const String _liveKitUrlDev = 'ws://localhost:7880';
  static const String _liveKitTokenUrlDev = 'http://localhost:5000/token';

  // ── Production — replace with your real deployed domain OR your LiveKit
  //    Cloud project URL. Set via --dart-define at build time:
  //    --dart-define=LIVEKIT_URL=wss://<your-project>.livekit.cloud
  //    --dart-define=LIVEKIT_TOKEN_URL=https://<your-token-server>/token
  //    If you prefer, you can also just paste your values as the
  //    defaultValue strings below instead of passing --dart-define.
  static const String _liveKitUrlProd = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://PASTE_YOUR_PROJECT.livekit.cloud',
  );
  static const String _liveKitTokenUrlProd = String.fromEnvironment(
    'LIVEKIT_TOKEN_URL',
    defaultValue: 'https://PASTE_YOUR_TOKEN_SERVER/token',
  );

  static String get liveKitUrl =>
      useProduction ? _liveKitUrlProd : _liveKitUrlDev;

  static String get liveKitTokenUrl =>
      useProduction ? _liveKitTokenUrlProd : _liveKitTokenUrlDev;

  /// Screen/tab sharing via getDisplayMedia is available on Web and desktop
  /// (Windows/macOS/Linux). Not available out of the box on iOS/Android.
  static bool get isScreenShareSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}

// Legacy aliases so existing imports still compile
class SoanyaColors extends SimulColors {}
class AppColors extends SimulColors {}
