// lib/theme.dart
//
// SarkariSewa Design System — canonical tokens.
// Source of truth: .claude/_design/project/colors_and_type.css
//
// Brand: deep purple-to-violet. Surfaces are flat white with hairline
// borders. Cards are FLAT — only primary CTAs cast a shadow. The splash
// logo gets an outer glow.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ─── Brand ──────────────────────────────────────────────────────────────
  // The "saffron" name is a legacy alias from a dark-theme era — it now
  // refers to the purple primary CTA color. Both names point at the same
  // value to keep older code compiling.
  static const primary      = Color(0xFF5624D0); // purple — main brand / CTA
  static const saffron      = Color(0xFF5624D0); // alias of primary
  static const saffronLight = Color(0xFF6B39E0); // hover
  static const saffronDark  = Color(0xFF401B9C); // pressed
  static const violet       = Color(0xFF8B5CF6); // gradient companion only

  // ─── Surfaces ───────────────────────────────────────────────────────────
  // No dark mode. White scaffold, off-white panels, slightly grayer inputs.
  static const navy      = Color(0xFFFFFFFF); // scaffold background
  static const navyLight = Color(0xFFF7F9FA); // elevated / off-white panel
  static const navyMid   = Color(0xFFFFFFFF); // app-bar / sheet
  static const cardBg    = Color(0xFFFFFFFF);
  static const inputBg   = Color(0xFFFAFAFA);

  // ─── Semantic accents ───────────────────────────────────────────────────
  static const gold    = Color(0xFFE59819); // gold tier, coins, achievements
  static const emerald = Color(0xFF10B981); // success, free tier, enrolled
  static const ruby    = Color(0xFFEF4444); // errors, danger
  static const sky     = Color(0xFF38BDF8); // silver tier, info
  static const rose    = Color(0xFFF43F5E); // (still used by some screens)
  static const teal    = Color(0xFF14B8A6); // (still used by some screens)

  // ─── Text ───────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1C1D1F);
  static const textSecondary = Color(0xFF6A6F73);
  static const textMuted     = Color(0xFF9CA3A8);

  // ─── Borders ────────────────────────────────────────────────────────────
  // ONE border color, ONE weight. The design system explicitly forbids
  // multiple border colors. `borderSoft` is kept as an alias of the same
  // value to avoid sprinkling color changes through every screen.
  static const border     = Color(0xFFD1D7DC);
  static const borderSoft = Color(0xFFD1D7DC);
}

/// Shadow tokens — the design system uses **one** shadow recipe for CTAs
/// and **one** glow for the splash logo. Cards are flat. We expose the
/// other elevations (`sm/md/lg`) as no-op empty lists so older code that
/// references them keeps compiling without leaking shadows everywhere.
class AppShadows {
  /// Cards: flat (no shadow). Use a hairline border instead.
  static const List<BoxShadow> sm = <BoxShadow>[];
  static const List<BoxShadow> md = <BoxShadow>[];
  static const List<BoxShadow> lg = <BoxShadow>[];

  /// Soft glow under primary CTAs.
  static List<BoxShadow> get brand => [
    BoxShadow(
      color: AppColors.primary.withAlpha(61), // ≈ 0.24 alpha
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Outer glow for the splash logo only.
  static List<BoxShadow> get splashGlow => [
    BoxShadow(
      color: AppColors.primary.withAlpha(102), // ≈ 0.40 alpha
      blurRadius: 32,
      spreadRadius: 4,
    ),
  ];

  /// Modal / bottom-sheet drop shadow.
  static List<BoxShadow> get modal => [
    BoxShadow(
      color: const Color(0xFF1C1D1F).withAlpha(30), // ≈ 0.12 alpha
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Spacing scale — mirrors the CSS `--space-*` tokens.
class AppSpace {
  static const double x1  = 4;
  static const double x2  = 8;
  static const double x3  = 12;
  static const double x4  = 16;  // most common gutter
  static const double x5  = 20;
  static const double x6  = 24;
  static const double x8  = 32;
  static const double x10 = 40;
}

/// Radii — mirrors the CSS `--radius-*` tokens.
///   sm 8 · md 10 (inputs) · lg 12 (buttons) · xl 14 (nav pills) ·
///   xxl 16 (cards) · xxxl 20 (sheets, hero blocks) · pill 9999.
class AppRadius {
  static const double sm   = 8;
  static const double md   = 10;
  static const double lg   = 12;
  static const double xl   = 14;
  static const double xxl  = 16;
  static const double xxxl = 20;
  static const double pill = 9999;
}

/// Brand gradients.
class AppGradients {
  /// Solid brand gradient — used for primary CTAs, splash mark, dashboard
  /// avatar, the Battle promo card. The only "fully saturated" surface.
  static const brand = LinearGradient(
    colors: [AppColors.primary, AppColors.violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft tinted gradient — `saffron @ 15% → violet @ 8%` over white.
  /// Used on the dashboard greeting card and splash background.
  static LinearGradient get brandSoft => LinearGradient(
    colors: [
      AppColors.primary.withAlpha(38), // 0.15
      AppColors.violet.withAlpha(20),  // 0.08
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Battleground promo — light → deep purple.
  static const battle = LinearGradient(
    colors: [AppColors.violet, AppColors.primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Legacy aliases retained for screens already using them.
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
      // Cards are flat with a hairline border — never elevated.
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
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
      // Inputs: filled #FAFAFA, radius 10, hairline border, 1.5px purple
      // border on focus, leading icon at textMuted.
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Buttons: padding 14×24, weight 600, size 15. Primary CTA gets the
      // single brand shadow; AppButton applies the rest.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dividerColor: AppColors.border,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      // Type — Outfit (display) + Inter (body), Devanagari fallback.
      // Mirrors `lib/theme.dart` original textTheme + the CSS spec.
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamilyFallback: const [
          'Noto Sans Devanagari',
          'Noto Color Emoji',
          'Segoe UI Emoji',
        ],
      ).copyWith(
        // Display + headlines use Outfit.
        displayLarge: GoogleFonts.outfit(
          fontSize: 38, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          letterSpacing: -0.5, height: 1.1,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          letterSpacing: -0.3, height: 1.15,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          height: 1.15,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          height: 1.3,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        // Body uses Inter.
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
