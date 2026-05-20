
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme for the Studio design direction.
class AppTheme {
  const AppTheme._();

  static const Color darkChrome = Color(0xFF1A1A1A);
  static const Color pageBackground = Color(0xFFFAFAF8);
  static const Color cardBackground = Color(0xFFF3EFE9);
  static const Color accent = Color(0xFFD4845A);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color divider = Color(0xFFE0DDD8);

  /// Il `ThemeData` completo applicato da MaterialApp.
  static ThemeData get theme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: pageBackground,

      colorScheme: const ColorScheme.light(
        primary: darkChrome,
        secondary: accent,
        surface: pageBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: darkChrome,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.lora(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkChrome,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: divider),
        ),
        margin: EdgeInsets.zero,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkChrome,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      textTheme: base.textTheme.copyWith(
        displayLarge: GoogleFonts.lora(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.55,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: textSecondary,
          height: 1.4,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          color: textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
