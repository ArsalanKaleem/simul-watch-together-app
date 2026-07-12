import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_service.dart';
import 'services/livekit_service.dart';
import 'services/theme_controller.dart';
import 'services/youtube_sync_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SimulApp());
}

class SimulApp extends StatelessWidget {
  const SimulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(
          create: (_) => LiveKitService(
            liveKitUrl   : AppConfig.liveKitUrl,
            tokenEndpoint: AppConfig.liveKitTokenUrl,
          ),
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
