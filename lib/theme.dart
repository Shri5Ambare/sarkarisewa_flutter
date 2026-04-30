// lib/theme.dart — SarkariSewa modernized light theme
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ─── Brand / accent ────────────────────────────────────────────────────────
  // Primary brand: deep indigo-violet. Crisp, modern, exam-prep premium feel.
  static const primary      = Color(0xFF4F46E5); // indigo-600
  static const saffron      = Color(0xFF4F46E5); // alias kept for backwards compat
  static const saffronLight = Color(0xFF6366F1); // indigo-500 (hover)
  static const saffronDark  = Color(0xFF3730A3); // indigo-800 (pressed)

  // Surface / background
  static const navy         = Color(0xFFFAFAFB); // page background — very soft gray
  static const navyLight    = Color(0xFFF4F5F7); // elevated surface tint
  static const navyMid      = Color(0xFFFFFFFF); // app bar / sheet
  static const cardBg       = Color(0xFFFFFFFF);
  static const inputBg      = Color(0xFFF8F9FB);

  // Functional colors
  static const gold         = Color(0xFFF59E0B); // amber-500
  static const emerald      = Color(0xFF10B981); // emerald-500
  static const ruby         = Color(0xFFEF4444); // red-500
  static const violet       = Color(0xFF8B5CF6); // violet-500
  static const sky          = Color(0xFF0EA5E9); // sky-500
  static const rose         = Color(0xFFF43F5E); // rose-500 (NEW)
  static const teal         = Color(0xFF14B8A6); // teal-500 (NEW)

  // Text colors
  static const textPrimary  = Color(0xFF0F172A); // slate-900
  static const textSecondary= Color(0xFF475569); // slate-600
  static const textMuted    = Color(0xFF94A3B8); // slate-400

  // Borders
  static const border       = Color(0xFFE2E8F0); // slate-200
  static const borderSoft   = Color(0xFFF1F5F9); // slate-100 (NEW)
}

/// Elevation / shadow tokens — use these instead of ad-hoc BoxShadows.
class AppShadows {
  // Subtle floating card shadow.
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Card / elevated surface.
  static List<BoxShadow> get md => [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Hero / featured card.
  static List<BoxShadow> get lg => [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(20),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  // Brand-tinted primary shadow (for CTAs, hero blocks).
  static List<BoxShadow> get brand => [
    BoxShadow(
      color: AppColors.primary.withAlpha(40),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Spacing scale (4-pt grid) — use these constants instead of magic numbers.
class AppSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
}

/// Radius tokens.
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;
}

/// Brand gradients reused across hero blocks.
class AppGradients {
  static const brand = LinearGradient(
    colors: [AppColors.primary, AppColors.violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const sunset = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ocean = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const forest = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.navy,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.primary,
        secondary: AppColors.violet,
        surface:   AppColors.navyMid,
        error:     AppColors.ruby,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navyLight,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.ruby, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.ruby, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dividerColor: AppColors.borderSoft,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamilyFallback: const ['Noto Sans Devanagari', 'Noto Color Emoji', 'Segoe UI Emoji'],
      ).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          letterSpacing: -0.8, height: 1.1,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          letterSpacing: -0.5, height: 1.15,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          letterSpacing: -0.3, height: 1.2,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          letterSpacing: -0.2, height: 1.25,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          height: 1.3,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          height: 1.35,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, color: AppColors.textPrimary, height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, color: AppColors.textSecondary, height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textMuted, height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
