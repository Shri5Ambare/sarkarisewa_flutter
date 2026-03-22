// lib/theme.dart — SarkariSewa light theme (Udemy style)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ─── Brand / accent ────────────────────────────────────────────────────────
  // primary == saffron: the main purple CTA color (Udemy-style).
  // NOTE: these were originally named for a dark theme (saffron=orange, navy=dark).
  // After migration to a light theme the constants were remapped so existing
  // widget code kept compiling. Rename in a future refactor if desired.
  static const primary      = Color(0xFF5624D0); // purple — main brand
  static const saffron      = Color(0xFF5624D0); // alias for primary (buttons/accents)
  static const saffronLight = Color(0xFF6B39E0); // lighter purple hover
  static const saffronDark  = Color(0xFF401B9C); // darker purple pressed

  // ─── Surface / background ──────────────────────────────────────────────────
  // navy / navyLight / navyMid are light-theme surface colors (originally dark).
  static const navy         = Color(0xFFFFFFFF); // scaffold background (white)
  static const navyLight    = Color(0xFFF7F9FA); // elevated surface (off-white)
  static const navyMid      = Color(0xFFFFFFFF); // app bar / modal background
  
  static const gold         = Color(0xFFE59819);
  static const emerald      = Color(0xFF10B981);
  static const ruby         = Color(0xFFEF4444);
  static const violet       = Color(0xFF8B5CF6);
  static const sky          = Color(0xFF38BDF8);

  // Text colors for light theme
  static const textPrimary  = Color(0xFF1C1D1F);
  static const textSecondary= Color(0xFF6A6F73); // medium gray — subtitles, labels
  static const textMuted    = Color(0xFF9CA3A8); // light gray — placeholders, hints

  static const border       = Color(0xFFD1D7DC);
  static const cardBg       = Color(0xFFFFFFFF);
  static const inputBg      = Color(0xFFFAFAFA);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.navy,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.saffron,
        secondary: AppColors.primary,
        surface:   AppColors.navyMid,
        error:     AppColors.ruby,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.saffron, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.saffron,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.saffron),
      ),
      dividerColor: AppColors.border,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamilyFallback: const ['Noto Sans Devanagari', 'Noto Color Emoji', 'Segoe UI Emoji'],
      ).copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textMuted,
        ),
      ),
    );
  }
}
