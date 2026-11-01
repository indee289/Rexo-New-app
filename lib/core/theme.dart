import 'package:flutter/material.dart';

/// Light theme only. There is no dark variant by design.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2563EB);
  static const Color surface = Color(0xFFF6F7FB);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE4E7EC);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);

  static const Color ok = Color(0xFF15803D);
  static const Color okBg = Color(0xFFE7F6EC);
  static const Color low = Color(0xFFDC2626);
  static const Color lowBg = Color(0xFFFDEAEA);
  static const Color out = Color(0xFF6B7280);
  static const Color outBg = Color(0xFFF0F1F3);

  /// Minimum heights, so touch targets stay usable with one thumb.
  static const double buttonHeight = 56;
  static const double qtyButtonHeight = 64;
  static const double rowHeight = 76;

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(surface: surface);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(buttonHeight),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(buttonHeight),
          side: const BorderSide(color: line),
          foregroundColor: text,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 16),
        hintStyle: const TextStyle(color: muted, fontSize: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        height: 72,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: const TextStyle(fontSize: 16, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 17, color: text),
        bodyMedium: TextStyle(fontSize: 16, color: text),
        bodySmall: TextStyle(fontSize: 14, color: muted),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
