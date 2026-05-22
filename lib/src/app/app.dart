
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:folio/src/app/splash_screen.dart';

import 'app_theme.dart';

/// Root widget — applies the Studio theme and starts from [SplashScreen].
class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Folio',

      theme: AppTheme.theme,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      home: const SplashScreen(),

      debugShowCheckedModeBanner: false,
    );
  }
}
