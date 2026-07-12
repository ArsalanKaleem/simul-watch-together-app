import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_service.dart';
import 'services/livekit_service.dart';
import 'services/youtube_sync_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SimulApp());
}

class SimulApp extends StatelessWidget {
  const SimulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(
          create: (_) => LiveKitService(
            liveKitUrl   : AppConfig.liveKitUrl,
            tokenEndpoint: AppConfig.liveKitTokenUrl,
          ),
        ),
        ChangeNotifierProvider(create: (_) => YouTubeSyncService()),
      ],
      child: MaterialApp(
        title: 'SIMUL',
        debugShowCheckedModeBanner: false,
        color: SimulColors.black,
        theme: SimulColors.theme.copyWith(
          textTheme:
              GoogleFonts.interTextTheme(SimulColors.theme.textTheme).apply(
            bodyColor: SimulColors.white,
            displayColor: SimulColors.white,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
