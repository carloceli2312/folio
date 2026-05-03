import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'app_theme.dart';
import 'home_screen.dart';
import 'widgets/animated_folio_logo.dart';

void main() {
  runApp(const FolioApp());
}

/// Root widget — applies the Studio theme and starts from [SplashScreen].
class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Folio',
      theme: AppTheme.theme,
      localizationsDelegates: const [FlutterQuillLocalizations.delegate],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Splash screen con logo animato.
///
/// Mostra [AnimatedFolioLogo] per un ciclo completo di blink (2.8s) poi
/// transisce con un fade verso [HomeScreen]. Non richiede pacchetti esterni.
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
