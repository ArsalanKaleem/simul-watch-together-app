import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../screens/auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _slide = Tween<double>(begin: 24, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) => const AuthScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SimulColors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Logo mark
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: SimulColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SimulColors.border),
                  ),
                  child: const Center(
                    child: Text('S', style: TextStyle(
                      color: SimulColors.white, fontSize: 36,
                      fontWeight: FontWeight.w700, letterSpacing: -1,
                    )),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('SIMUL', style: TextStyle(
                  color: SimulColors.white, fontSize: 36,
                  fontWeight: FontWeight.w700, letterSpacing: 2,
                )),
                const SizedBox(height: 8),
                const Text('Watch together, in sync.', style: TextStyle(
                  color: SimulColors.faint, fontSize: 15, letterSpacing: 0.2,
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
