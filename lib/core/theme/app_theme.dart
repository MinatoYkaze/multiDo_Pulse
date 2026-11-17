import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build(AppThemeVariant variant, {bool isDark = true}) =>
      variant == AppThemeVariant.obsidianPulse ? _pulse(isDark) : _apple(isDark);

  // ───────────────────────── Obsidian Pulse ─────────────────────────
  static ThemeData _pulse(bool isDark) {
    final p = isDark ? AppPalette.pulse : AppPalette.pulseLight;
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFA5FFBD),
            onPrimary: Color(0xFF00391B),
            primaryContainer: Color(0xFF0CED84),
            onPrimaryContainer: Color(0xFF006635),
            secondary: Color(0xFF88D89E),
            onSecondary: Color(0xFF00391B),
            secondaryContainer: Color(0xFF005D30),
            onSecondaryContainer: Color(0xFF84D49A),
            tertiary: Color(0xFFFFEAB1),
            onTertiary: Color(0xFF3C2F00),
            tertiaryContainer: Color(0xFFEDCC69),
            onTertiaryContainer: Color(0xFF6B5500),
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000A),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: Color(0xFF0D150E),
            onSurface: Color(0xFFDBE5D9),
            onSurfaceVariant: Color(0xFFBACBBA),
            surfaceContainerLowest: Color(0xFF081009),
            surfaceContainerLow: Color(0xFF151E16),
            surfaceContainer: Color(0xFF19221A),
            surfaceContainerHigh: Color(0xFF232C24),
            surfaceContainerHighest: Color(0xFF2E372F),
            surfaceDim: Color(0xFF0D150E),
            surfaceBright: Color(0xFF323B33),
            outline: Color(0xFF849586),
            outlineVariant: Color(0xFF3B4A3E),
            inverseSurface: Color(0xFFDBE5D9),
            onInverseSurface: Color(0xFF29332B),
            inversePrimary: Color(0xFF006D39),
            surfaceTint: Color(0xFF00E37E),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF008744),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFA5FFBD),
            onPrimaryContainer: Color(0xFF00391B),
            secondary: Color(0xFF4B6350),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFCDE8D1),
            onSecondaryContainer: Color(0xFF07210F),
            tertiary: Color(0xFF6B5500),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFFFEAB1),
            onTertiaryContainer: Color(0xFF3C2F00),
            error: Color(0xFFBA1A1A),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: Color(0xFFF2F5F2),
            onSurface: Color(0xFF151E16),
            onSurfaceVariant: Color(0xFF414941),
            outline: Color(0xFF717971),
            outlineVariant: Color(0xFFC7D3C7),
            inverseSurface: Color(0xFF2E312E),
            onInverseSurface: Color(0xFFF0F1ED),
            inversePrimary: Color(0xFF0CED84),
            surfaceTint: Color(0xFF008744),
          );

    TextStyle mono(double size, double h, FontWeight w, double ls,
            [Color? c]) =>
        GoogleFonts.jetBrainsMono(
          fontSize: size,
          height: h / size,
          fontWeight: w,
          letterSpacing: ls * size,
          color: c ?? p.textPrimary,
        );

    final text = TextTheme(
      displaySmall: mono(32, 40, FontWeight.w700, -0.04), // headline-lg
      headlineMedium: mono(26, 32, FontWeight.w700, -0.03), // headline-lg-mobile
      headlineSmall: mono(20, 28, FontWeight.w600, -0.02), // headline-md
      titleMedium: mono(16, 22, FontWeight.w600, -0.01), // headline-sm
      bodyLarge: mono(15, 24, FontWeight.w400, 0),
      bodyMedium: mono(13, 20, FontWeight.w400, 0.01),
      bodySmall: mono(11, 16, FontWeight.w400, 0.02, p.textMuted),
      labelLarge: mono(13, 16, FontWeight.w600, 0.04),
      labelMedium: mono(11, 14, FontWeight.w500, 0.06),
      labelSmall: mono(9, 12, FontWeight.w700, 0.08),
    );

    return _base(scheme, p, text, GoogleFonts.jetBrainsMono().fontFamily);
  }

  // ───────────────────── Obsidian Apple Precision ─────────────────────
  static ThemeData _apple(bool isDark) {
    final p = isDark ? AppPalette.apple : AppPalette.appleLight;
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF39FF94), // neon mint is the working "primary" accent
            onPrimary: Color(0xFF000000),
            primaryContainer: Color(0xFF39FF94),
            onPrimaryContainer: Color(0xFF00723C),
            secondary: Color(0xFFC6C6C6),
            onSecondary: Color(0xFF2F3131),
            secondaryContainer: Color(0xFF454747),
            onSecondaryContainer: Color(0xFFB4B5B5),
            tertiary: Color(0xFFFFD7D3),
            onTertiary: Color(0xFF680007),
            tertiaryContainer: Color(0xFFFFD7D3),
            onTertiaryContainer: Color(0xFFBF2325),
            error: Color(0xFFFF6B6B),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000A),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: Color(0xFF000000), // Purest and blackest black (#000000)
            onSurface: Color(0xFFECECEC),
            onSurfaceVariant: Color(0xFFBACBBA),
            surfaceContainerLowest: Color(0xFF000000), // Purest black (#000000)
            surfaceContainerLow: Color(0xFF0D0E12),
            surfaceContainer: Color(0xFF14161C),
            surfaceContainerHigh: Color(0xFF1C1E26),
            surfaceContainerHighest: Color(0xFF252832),
            surfaceDim: Color(0xFF000000), // Purest black (#000000)
            surfaceBright: Color(0xFF38393D),
            outline: Color(0xFF6E7687),
            outlineVariant: Color(0xFF252932),
            inverseSurface: Color(0xFFE3E2E7),
            onInverseSurface: Color(0xFF2F3035),
            inversePrimary: Color(0xFF006D39),
            surfaceTint: Color(0xFF39FF94),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF00A854),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFF98FFB9),
            onPrimaryContainer: Color(0xFF00210E),
            secondary: Color(0xFF526350),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFD5E8D1),
            onSecondaryContainer: Color(0xFF101F11),
            tertiary: Color(0xFF9C4146),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFFFDADA),
            onTertiaryContainer: Color(0xFF40000A),
            error: Color(0xFFDC2626),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: Color(0xFFF7F8FA),
            onSurface: Color(0xFF0F172A),
            onSurfaceVariant: Color(0xFF414942),
            outline: Color(0xFF717971),
            outlineVariant: Color(0xFFE1E5EB),
            inverseSurface: Color(0xFF2E312E),
            onInverseSurface: Color(0xFFF0F1ED),
            inversePrimary: Color(0xFF39FF94),
            surfaceTint: Color(0xFF00A854),
          );

    TextStyle sf(double size, double h, FontWeight w, double ls,
            [Color? c]) =>
        TextStyle(
          fontFamily: '.SF Pro Text',
          fontFamilyFallback: const ['SF Pro Display', 'Roboto', 'sans-serif'],
          fontSize: size,
          height: h / size,
          fontWeight: w,
          letterSpacing: ls * size,
          color: c ?? p.textPrimary,
        );

    final text = TextTheme(
      displaySmall: sf(34, 41, FontWeight.w800, -0.022),
      headlineMedium: sf(28, 34, FontWeight.w700, -0.019),
      headlineSmall: sf(22, 28, FontWeight.w600, -0.015),
      titleMedium: sf(17, 22, FontWeight.w600, -0.012),
      bodyLarge: sf(17, 24, FontWeight.w400, -0.01),
      bodyMedium: sf(15, 20, FontWeight.w400, -0.005),
      bodySmall: sf(13, 18, FontWeight.w300, 0, p.textMuted),
      labelLarge: sf(15, 18, FontWeight.w600, -0.008),
      labelMedium: sf(12, 16, FontWeight.w500, 0.015),
      labelSmall: sf(11, 14, FontWeight.w700, 0.03),
    );

    return _base(scheme, p, text, '.SF Pro Text');
  }

  // ─────────────────────────── shared builder ───────────────────────────
  static ThemeData _base(
      ColorScheme scheme, AppPalette p, TextTheme text, String? family) {
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(p.cardRadius),
      side: BorderSide(color: p.border),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(p.controlRadius),
      borderSide: BorderSide(color: p.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.base,
      canvasColor: p.base,
      fontFamily: family,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.base.withValues(alpha: 0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textPrimary, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.usesGlass
            ? (p.isDark ? const Color(0xFF1A1B20) : const Color(0xFFF1F3F6))
            : p.surface1,
        hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: p.accent, width: 1)),
        errorBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: p.warning, width: 1)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: text.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: p.onAccent),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  p.usesGlass ? 999 : p.controlRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(0, 48),
          backgroundColor: p.usesGlass
              ? (p.isDark ? const Color(0x0FFFFFFF) : const Color(0x08000000))
              : Colors.transparent,
          side: BorderSide(
              color: p.usesGlass
                  ? (p.isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000))
                  : p.border),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  p.usesGlass ? 999 : p.controlRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: p.accent, textStyle: text.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.usesGlass ? 20 : 4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.accent : p.surface3),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface2,
        modalBackgroundColor: p.surface2,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(p.sheetRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.usesGlass ? 32 : 8),
          side: BorderSide(color: p.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.base.withValues(alpha: 0.85),
        indicatorColor: p.accent.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
            text.labelSmall!.copyWith(
                color: s.contains(WidgetState.selected)
                    ? p.accent
                    : p.textMuted)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accent : p.textMuted)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface3,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(p.controlRadius)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.isDark ? const Color(0x0FFFFFFF) : const Color(0x14000000),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Decoration helpers so every screen draws cards identically per theme
/// (hairline border for Pulse; glass rim + top highlight for Apple Precision).
class AppDecor {
  AppDecor._();

  static BoxDecoration card(AppPalette p,
          {bool glowing = false, bool dimmed = false, Color? color}) =>
      BoxDecoration(
        color: color ??
            (dimmed
                ? (p.isDark ? const Color(0xFF08090C) : const Color(0xFFEEF1F5))
                : p.surface1),
        borderRadius: BorderRadius.circular(p.cardRadius),
        border: Border.all(
            color: glowing ? p.accent : p.border, width: 1),
        boxShadow: [
          if (glowing)
            BoxShadow(color: p.accentGlow, blurRadius: 20, spreadRadius: 0),
          if (p.usesGlass && !glowing)
            p.isDark
                ? const BoxShadow(
                    color: Color(0x0AFFFFFF),
                    blurRadius: 0,
                    offset: Offset(0, 1),
                    blurStyle: BlurStyle.inner)
                : const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 2)),
        ],
      );

  static BoxDecoration sheet(AppPalette p) => BoxDecoration(
        color: p.surface2,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(p.sheetRadius)),
        border: Border.all(color: p.border),
        boxShadow: p.usesGlass
            ? [
                BoxShadow(
                    color: p.isDark
                        ? const Color(0xA6000000)
                        : const Color(0x26000000),
                    blurRadius: 40,
                    offset: const Offset(0, 16))
              ]
            : null,
      );
}
