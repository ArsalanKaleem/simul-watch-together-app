import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SimulColors {
  static const Color black   = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color card    = Color(0xFF1A1A1A);
  static const Color border  = Color(0xFF2A2A2A);
  static const Color muted   = Color(0xFF3A3A3A);
  static const Color subtle  = Color(0xFF555555);
  static const Color faint   = Color(0xFF888888);
  static const Color white   = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F5);
  static const Color accent  = Color(0xFFE0E0E0);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // Screen-share accent
  static const Color shareActive = Color(0xFF8B5CF6);

  // Legacy aliases
  static const Color pink      = accent;
  static const Color pinkLight = faint;
  static const Color darkGray  = card;

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: black,
    primaryColor: white,
    colorScheme: const ColorScheme.dark(
      primary: white,
      secondary: accent,
      surface: surface,
      error: error,
      onPrimary: black,
      onSecondary: black,
      onSurface: white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: black,
      elevation: 0,
      iconTheme: IconThemeData(color: white),
      titleTextStyle: TextStyle(
        color: white, fontSize: 17,
        fontWeight: FontWeight.w600, letterSpacing: -0.3,
      ),
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: white, width: 1.5),
      ),
      labelStyle: const TextStyle(color: faint),
      hintStyle: const TextStyle(color: subtle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: white,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    cardColor: card,
  );
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
///
/// LOCAL DEV DEFAULTS — these match `livekit-server --dev` and the token
/// server from the SETUP_GUIDE running on their default ports. Switch
/// [useProduction] to true (or better, use --dart-define) once you've
/// deployed a real server.
class AppConfig {
  // Set via: flutter run --dart-define=USE_PRODUCTION=true
  static const bool useProduction =
      bool.fromEnvironment('USE_PRODUCTION', defaultValue: false);

  // ── Local development (livekit-server --dev + local token server) ────────
  static const String _liveKitUrlDev = 'ws://localhost:7880';
  static const String _liveKitTokenUrlDev = 'http://localhost:5000/token';

  // ── Production — replace with your real deployed domain ──────────────────
  // Set via: flutter run --dart-define=LIVEKIT_URL=wss://livekit.yourdomain.com
  //          --dart-define=LIVEKIT_TOKEN_URL=https://livekit.yourdomain.com/token
  static const String _liveKitUrlProd = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://livekit.yourdomain.com',
  );
  static const String _liveKitTokenUrlProd = String.fromEnvironment(
    'LIVEKIT_TOKEN_URL',
    defaultValue: 'https://livekit.yourdomain.com/token',
  );

  static String get liveKitUrl =>
      useProduction ? _liveKitUrlProd : _liveKitUrlDev;

  static String get liveKitTokenUrl =>
      useProduction ? _liveKitTokenUrlProd : _liveKitTokenUrlDev;

  /// Screen/tab sharing via LiveKit's getDisplayMedia wrapper is available
  /// on Web and desktop (Windows/macOS/Linux). Not available out of the box
  /// on iOS (needs a Broadcast Extension) or Android (needs MediaProjection
  /// setup) — both require extra native configuration beyond this package.
  static bool get isScreenShareSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}

// Legacy alias so existing imports still compile
class SoanyaColors extends SimulColors {}
class AppColors extends SimulColors {}
