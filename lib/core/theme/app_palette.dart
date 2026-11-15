import 'package:flutter/material.dart';

enum AppThemeVariant {
  obsidianPulse('Obsidian Pulse', 'Technical · Monospaced'),
  obsidianApplePrecision('Obsidian Apple Precision', 'Fluid · Glass');

  const AppThemeVariant(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

/// Design tokens that don't fit in [ColorScheme]. Access with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.variant,
    this.isDark = true,
    required this.base,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.accentGlow,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
    required this.textPrimary,
    required this.textMuted,
    required this.cardRadius,
    required this.controlRadius,
    required this.sheetRadius,
    required this.pillRadius,
    required this.checkboxRadius,
    required this.checkboxIsCircle,
    required this.usesGlass,
    required this.fontFamily,
    required this.monoNumerics,
  });

  final AppThemeVariant variant;
  final bool isDark;
  final Color base; // scaffold / canvas background
  final Color surface1; // cards
  final Color surface2; // modals / sheets / swipe backgrounds
  final Color surface3;
  final Color border;
  final Color accent; // neon green / mint
  final Color onAccent;
  final Color accentGlow;
  final Color warning; // amber / crimson (destructive)
  final Color warningBg;
  final Color warningBorder;
  final Color textPrimary;
  final Color textMuted;
  final double cardRadius;
  final double controlRadius;
  final double sheetRadius;
  final double pillRadius;
  final double checkboxRadius;
  final bool checkboxIsCircle;
  final bool usesGlass;
  final String? fontFamily;
  final bool monoNumerics;

  bool get isTerminal => variant == AppThemeVariant.obsidianPulse;

  // ── Obsidian Pulse Dark (Terminal, hairline borders, deep matrix green)
  static const pulse = AppPalette(
    variant: AppThemeVariant.obsidianPulse,
    isDark: true,
    base: Color(0xFF0D150E),
    surface1: Color(0xFF151E16),
    surface2: Color(0xFF19221A),
    surface3: Color(0xFF232C24),
    border: Color(0xFF3B4A3E),
    accent: Color(0xFF0CED84),
    onAccent: Color(0xFF00391B),
    accentGlow: Color(0x1F0CED84), // rgba(12,237,132,.12)
    warning: Color(0xFFFFDD78),
    warningBg: Color(0x1FFFDD78),
    warningBorder: Color(0xFFFFDD78),
    textPrimary: Color(0xFFDBE5D9),
    textMuted: Color(0xFF849586),
    cardRadius: 4,
    controlRadius: 4,
    sheetRadius: 8,
    pillRadius: 4,
    checkboxRadius: 2,
    checkboxIsCircle: false,
    usesGlass: false,
    fontFamily: 'JetBrains Mono',
    monoNumerics: true,
  );

  // ── Obsidian Pulse Light (Technical light terminal paper)
  static const pulseLight = AppPalette(
    variant: AppThemeVariant.obsidianPulse,
    isDark: false,
    base: Color(0xFFF2F5F2),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFFAFCFA),
    surface3: Color(0xFFE5EBE5),
    border: Color(0xFFC7D3C7),
    accent: Color(0xFF008744),
    onAccent: Color(0xFFFFFFFF),
    accentGlow: Color(0x20008744),
    warning: Color(0xFFB45309),
    warningBg: Color(0x1AB45309),
    warningBorder: Color(0x40B45309),
    textPrimary: Color(0xFF151E16),
    textMuted: Color(0xFF526354),
    cardRadius: 4,
    controlRadius: 4,
    sheetRadius: 8,
    pillRadius: 4,
    checkboxRadius: 2,
    checkboxIsCircle: false,
    usesGlass: false,
    fontFamily: 'JetBrains Mono',
    monoNumerics: true,
  );

  // ── Obsidian Apple Precision Dark (Pure and blackest black #000000, fluid glass)
  static const apple = AppPalette(
    variant: AppThemeVariant.obsidianApplePrecision,
    isDark: true,
    base: Color(0xFF000000), // Pure, blackest black
    surface1: Color(0xFF101216), // Subtle elevated card over true black
    surface2: Color(0xFF16181F),
    surface3: Color(0xFF1E2028),
    border: Color(0x1FFFFFFF), // rgba(255,255,255,.12)
    accent: Color(0xFF39FF94),
    onAccent: Color(0xFF000000),
    accentGlow: Color(0x4039FF94), // rgba(57,255,148,.25)
    warning: Color(0xFFFF6B6B),
    warningBg: Color(0x1FC82A2A),
    warningBorder: Color(0x40C82A2A),
    textPrimary: Color(0xFFF4F4F6),
    textMuted: Color(0xFF7E8494),
    cardRadius: 24,
    controlRadius: 20,
    sheetRadius: 32,
    pillRadius: 999,
    checkboxRadius: 10,
    checkboxIsCircle: true,
    usesGlass: true,
    fontFamily: null, // system SF on iOS / Roboto fallback elsewhere
    monoNumerics: false,
  );

  // ── Obsidian Apple Precision Light (Crisp Apple white canvas & fluid cards)
  static const appleLight = AppPalette(
    variant: AppThemeVariant.obsidianApplePrecision,
    isDark: false,
    base: Color(0xFFF7F8FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFFFF),
    surface3: Color(0xFFEBEEF2),
    border: Color(0xFFE1E5EB),
    accent: Color(0xFF00A854),
    onAccent: Color(0xFFFFFFFF),
    accentGlow: Color(0x2000A854),
    warning: Color(0xFFDC2626),
    warningBg: Color(0x14DC2626),
    warningBorder: Color(0x40DC2626),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    cardRadius: 24,
    controlRadius: 20,
    sheetRadius: 32,
    pillRadius: 999,
    checkboxRadius: 10,
    checkboxIsCircle: true,
    usesGlass: true,
    fontFamily: null,
    monoNumerics: false,
  );

  static AppPalette of(AppThemeVariant v, {bool isDark = true}) {
    if (v == AppThemeVariant.obsidianPulse) {
      return isDark ? pulse : pulseLight;
    }
    return isDark ? apple : appleLight;
  }

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 || other is! AppPalette ? this : other;
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
