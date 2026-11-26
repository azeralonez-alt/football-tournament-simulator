
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna, tipografi, dan tema utama aplikasi (Clean Sports Data UI - FotMob Light Mode).
class AppTheme {
  AppTheme._();

  // ===========================================================================
  // 1. Warna Dasar & Permukaan (Surface)
  // ===========================================================================
  static const Color backgroundCanvas = Color(0xFFF4F5F7);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFEEF0F4);
  static const Color borderHairline = Color(0xFFE5E7EB);

  // ===========================================================================
  // 2. Warna Aksi & Teks
  // ===========================================================================
  static const Color primaryBrand = Color(0xFF00A859);
  static const Color secondaryAccent = Color(0xFF1D4ED8);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // ===========================================================================
  // 3. Warna Zona Kualifikasi Klasemen (Indikator Garis Kiri 4px)
  // ===========================================================================
  /// Peringkat 1–4: Champions League
  static const Color zoneChampions = Color(0xFF2563EB);

  /// Peringkat 5–8: Winner League
  static const Color zoneWinner = Color(0xFFEA580C);

  /// Peringkat 9–12: Federation League
  static const Color zoneFederation = Color(0xFF7C3AED);

  /// Peringkat 13–17: Mid Range League
  static const Color zoneMidRange = Color(0xFF0D9488);

  /// Peringkat 18–20: Challenger League
  static const Color zoneChallenger = Color(0xFFD97706);

  /// Zona Eliminasi / Gugur (untuk League Phase Kontinental rank 25–32)
  static const Color zoneEliminated = Color(0xFFDC2626);

  /// Mengembalikan warna zona klasemen Liga Lokal berdasarkan peringkat (1–20).
  static Color? localLeagueZoneColor(int rank) {
    if (rank >= 1 && rank <= 4) return zoneChampions;
    if (rank >= 5 && rank <= 8) return zoneWinner;
    if (rank >= 9 && rank <= 12) return zoneFederation;
    if (rank >= 13 && rank <= 17) return zoneMidRange;
    if (rank >= 18 && rank <= 20) return zoneChallenger;
    return null;
  }

  /// Mengembalikan warna zona klasemen League Phase Kontinental berdasarkan peringkat (1–32).
  static Color? continentalLeaguePhaseZoneColor(int rank) {
    if (rank >= 1 && rank <= 8) return zoneChampions;
    if (rank >= 9 && rank <= 24) return zoneWinner;
    if (rank >= 25 && rank <= 32) return zoneEliminated;
    return null;
  }

  // ===========================================================================
  // 4. Warna Indikator OVR & Event Khusus
  // ===========================================================================
  static const Color ovrEliteBg = Color(0xFFECFDF5);
  static const Color ovrEliteText = Color(0xFF059669);

  static const Color ovrMidBg = Color(0xFFEFF6FF);
  static const Color ovrMidText = Color(0xFF2563EB);

  static const Color ovrLowBg = Color(0xFFF1F5F9);
  static const Color ovrLowText = Color(0xFF475569);

  static const Color ovrUp = Color(0xFF16A34A);
  static const Color ovrDown = Color(0xFFDC2626);

  static const Color chaoticBg = Color(0xFFFEF3C7);
  static const Color chaoticText = Color(0xFFB45309);

  static const Color eventInfoBg = Color(0xFFEFF6FF);
  static const Color eventInfoBorder = Color(0xFFBFDBFE);

  /// Mengembalikan pasangan warna (latar, teks) untuk badge pill OVR.
  static ({Color background, Color foreground}) ovrColors(int ovr) {
    if (ovr >= 85) {
      return (background: ovrEliteBg, foreground: ovrEliteText);
    }
    if (ovr >= 75) {
      return (background: ovrMidBg, foreground: ovrMidText);
    }
    return (background: ovrLowBg, foreground: ovrLowText);
  }

  // ===========================================================================
  // 5. Konstanta Layout & Border Radius Standar
  // ===========================================================================
  static const double radiusCard = 12.0;
  static const double radiusButton = 8.0;
  static const double radiusInput = 8.0;
  static const double radiusPill = 20.0;

  static const double screenPadding = 16.0;
  static const double cardSpacing = 10.0;
  static const double cardPadding = 12.0;
  static const double cardPaddingLarge = 16.0;
  static const double zoneIndicatorWidth = 4.0;

  // ===========================================================================
  // 6. Tipografi & TextStyle (dengan Tabular Figures untuk angka)
  // ===========================================================================
  static const List<FontFeature> tabularFeatures = [
    FontFeature.tabularFigures(),
  ];

  static TextStyle get _baseFont => GoogleFonts.inter();

  static TextStyle get appBarTitle => _baseFont.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get sectionHeader => _baseFont.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get cardTitle => _baseFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.35,
      );

  static TextStyle get matchScore => _baseFont.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        fontFeatures: tabularFeatures,
        height: 1.2,
      );

  static TextStyle get body => _baseFont.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
      );

  static TextStyle get bodyPrimary => _baseFont.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.4,
      );

  static TextStyle get caption => _baseFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        height: 1.3,
      );

  static TextStyle get badge => _baseFont.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        fontFeatures: tabularFeatures,
        height: 1.2,
      );

  static TextStyle get tableHeader => _baseFont.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        height: 1.2,
      );

  static TextStyle get tabularNumber => _baseFont.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        fontFeatures: tabularFeatures,
        height: 1.3,
      );

  static TextStyle get tabularNumberBold => _baseFont.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFeatures: tabularFeatures,
        height: 1.3,
      );

  // ===========================================================================
  // 7. ThemeData Light Mode
  // ===========================================================================
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundCanvas,
      colorScheme: const ColorScheme.light(
        primary: primaryBrand,
        onPrimary: Colors.white,
        secondary: secondaryAccent,
        onSecondary: Colors.white,
        surface: surfaceCard,
        onSurface: textPrimary,
        outline: borderHairline,
        error: ovrDown,
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: appBarTitle,
        titleMedium: sectionHeader,
        titleSmall: cardTitle,
        bodyMedium: body,
        bodySmall: caption,
        labelSmall: badge,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceCard,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: appBarTitle,
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
        shape: const Border(
          bottom: BorderSide(color: borderHairline, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: borderHairline, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderHairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceCard,
        elevation: 0,
        indicatorColor: const Color(0xFFE6F6EE),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return _baseFont.copyWith(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? primaryBrand : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? primaryBrand : textSecondary,
            size: 22,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceCard,
        selectedItemColor: primaryBrand,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: _baseFont.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: _baseFont.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryBrand,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryBrand,
        dividerColor: borderHairline,
        labelStyle: _baseFont.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: _baseFont.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceSubtle,
          disabledForegroundColor: textMuted,
          elevation: 0,
          textStyle: _baseFont.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderHairline, width: 1),
          textStyle: _baseFont.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: body.copyWith(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderHairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderHairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryBrand, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSubtle,
        selectedColor: primaryBrand,
        labelStyle: caption,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
    );
  }
}
