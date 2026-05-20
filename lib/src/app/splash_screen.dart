import 'package:flutter/material.dart';
import 'package:folio/src/ui/home/home_screen.dart';
import 'package:folio/src/ui/widgets/animated_folio_logo.dart';

import 'app_theme.dart';

/// Splash screen con logo animato.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), _goHome);
  }

  /// Sostituisce lo splash con la [HomeScreen] tramite un fade.
  Future<void> _goHome() async {
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const HomeScreen(),

        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: Center(child: AnimatedFolioLogo(size: 120)),
    );
  }
}
