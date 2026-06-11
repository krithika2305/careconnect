import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// CareConnect — Calm Teal & Cream (accessible, warm clinical UX).
class CareTheme {
  // ── Core palette ─────────────────────────────────────────────
  static const Color background = Color(0xFFFDF8F0); // Soft cream
  static const Color backgroundDeep = Color(0xFFF5EDE0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFE8E4DE);

  /// Primary accent (kept name `accentPink` for backward compatibility).
  static const Color accentPink = Color(0xFF2B9B7A); // Calm teal
  static const Color accentPinkSoft = Color(0xFF5DB896);
  static const Color accentPeach = Color(0xFFFFB347); // Warm peach

  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF5A5A5A);
  static const Color textMuted = Color(0xFF8E8E8E);

  static const Color success = Color(0xFF6A994E);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFE76F51);

  // Legacy aliases used by dashboards
  static const Color lightBg = background;
  static const Color lightCard = surface;
  static const Color lightText = textPrimary;
  static const Color lightTextMuted = textMuted;

  static TextStyle get displaySerif => GoogleFonts.playfairDisplay(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle get bodySans => GoogleFonts.inter(
        color: textSecondary,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get buttonLabel => GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );

  static SystemUiOverlayStyle get lightOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.dark,
      );

  /// @deprecated Use [lightOverlay]. Kept for existing call sites.
  static SystemUiOverlayStyle get darkOverlay => lightOverlay;

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  /// Fallback — same calm light palette (caregiver screens still reference this).
  static ThemeData get darkTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: accentPink,
        onPrimary: Colors.white,
        secondary: accentPeach,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      textTheme: TextTheme(
        headlineLarge: displaySerif.copyWith(fontSize: 32),
        headlineMedium: displaySerif.copyWith(fontSize: 26),
        titleLarge: bodySans.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: bodySans.copyWith(fontSize: 16, color: textSecondary),
        bodyMedium: bodySans.copyWith(fontSize: 14, color: textMuted),
        labelLarge: buttonLabel.copyWith(fontSize: 15, color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textPrimary,
        titleTextStyle: bodySans.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        systemOverlayStyle: lightOverlay,
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: surfaceLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: bodySans.copyWith(color: textMuted, fontSize: 14),
        labelStyle: bodySans.copyWith(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: accentPink, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPink,
          foregroundColor: Colors.white,
          elevation: 0,
          // Finite min width — infinity breaks buttons inside Row/Flex.
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: buttonLabel.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentPink,
          minimumSize: const Size(64, 54),
          side: const BorderSide(color: accentPink, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: buttonLabel.copyWith(fontSize: 15, color: accentPink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentPink),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentPink;
          return surfaceLight;
        }),
        side: BorderSide(color: textMuted.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerColor: surfaceLight,
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accentPink),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPink,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: bodySans.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: bodySans.copyWith(color: textPrimary, fontSize: 16),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          labelStyle: bodySans.copyWith(color: textSecondary),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: bodySans.copyWith(color: textPrimary, fontSize: 16),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textPrimary,
        textColor: textPrimary,
        titleTextStyle: bodySans.copyWith(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: bodySans.copyWith(color: textMuted, fontSize: 13),
      ),
    );
  }

  /// Readable dropdown field styling (selected value + menu items).
  static TextStyle get dropdownItemStyle => bodySans.copyWith(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );
}

/// Legacy alias used across dashboards — maps to shared brand tokens.
class MedicalTheme {
  static const Color primaryTeal = CareTheme.accentPink;
  static const Color secondaryMint = CareTheme.accentPinkSoft;
  static const Color lightBg = CareTheme.lightBg;
  static const Color accentCoral = CareTheme.error;
  static const Color accentOrange = CareTheme.warning;
  static const Color accentGreen = CareTheme.success;
  static const Color darkSlate = CareTheme.lightText;
  static const Color lightSlate = CareTheme.lightTextMuted;

  static ThemeData get lightTheme => CareTheme.lightTheme;
}
