import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/app_settings_service.dart';
import 'services/firebase_service.dart';
import 'services/livekit_service.dart';
import 'services/theme_controller.dart';
import 'services/youtube_sync_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't fetch fonts over the network at runtime.
  //
  // google_fonts downloads the font on first launch and caches it via
  // path_provider. On Windows that surfaced as an unhandled
  //   MissingPluginException(getApplicationSupportDirectory ...)
  // and it also means the UI depends on a network round-trip at startup.
  // With this off, google_fonts uses a bundled asset if present and
  // otherwise falls back to the platform font — no network, no
  // path_provider, no startup exception. See README for bundling Inter.
  GoogleFonts.config.allowRuntimeFetching = false;

  // A failed Firebase init used to take the whole app down with a bare
  // white screen. Let it start regardless — the room screens already
  // surface "couldn't reach the room server" toasts, which is far more
  // useful than a dead window.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Make Firestore work on restrictive networks.
    //
    // The SDK's default transport is WebChannel streaming, NOT plain REST.
    // Plenty of real-world networks (corporate proxies, some ISPs, VPNs,
    // captive portals, aggressive ad-blockers/shields) allow ordinary HTTPS
    // to firestore.googleapis.com but silently break the streaming
    // connection. The SDK then reports:
    //     [cloud_firestore/unavailable] ... the client is offline
    // even though the network is fine — which is exactly what we hit.
    //
    // autoDetectLongPolling makes the SDK notice the stream isn't working
    // and transparently fall back to long-polling, which survives those
    // networks. Persistence keeps the app usable on a flaky connection and
    // flushes queued writes once it recovers.
    //
    // NOTE: the webExperimental* flags apply to web only; they're ignored on
    // Android/iOS/desktop, where the native SDKs already handle this.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      webExperimentalAutoDetectLongPolling: true,
    );
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  // Load the user's saved LiveKit settings from secure storage before the app
  // paints, so the first room join already has the configuration.
  final settings = AppSettingsService();
  try {
    await settings.load();
  } catch (e) {
    debugPrint('Settings load failed: $e');
  }

  runApp(SimulApp(settings: settings));
}

class SimulApp extends StatelessWidget {
  final AppSettingsService settings;
  const SimulApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider<AppSettingsService>.value(value: settings),
        // LiveKitService reads live values from AppSettingsService. The proxy
        // keeps a single LiveKitService instance and re-attaches settings
        // whenever they change (e.g. after the user saves on Settings).
        ChangeNotifierProxyProvider<AppSettingsService, LiveKitService>(
          create: (_) => LiveKitService()..attachSettings(settings),
          update: (_, s, previous) =>
          (previous ?? LiveKitService())..attachSettings(s),
        ),
        ChangeNotifierProvider(create: (_) => YouTubeSyncService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeCtrl, _) {
          // Keep the system chrome (status bar / nav bar) in sync with theme.
          final isDark = themeCtrl.mode == ThemeMode.dark ||
              (themeCtrl.mode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
            isDark ? SimulPalette.dark.bg : SimulPalette.light.bg,
            systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
          ));

          TextTheme applyFont(ThemeData t) => GoogleFonts.interTextTheme(
            t.textTheme,
          ).apply(
            bodyColor: t.colorScheme.onSurface,
            displayColor: t.colorScheme.onSurface,
          );

          return MaterialApp(
            title: 'SIMUL',
            debugShowCheckedModeBanner: false,
            themeMode: themeCtrl.mode,
            theme: SimulTheme.light.copyWith(
              textTheme: applyFont(SimulTheme.light),
            ),
            darkTheme: SimulTheme.dark.copyWith(
              textTheme: applyFont(SimulTheme.dark),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}