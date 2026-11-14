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
  final Color base; // scaffold
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

  // ── Obsidian Pulse (DESIGN.md: JetBrains Mono, 4px corners, hairline borders)
  static const pulse = AppPalette(
    variant: AppThemeVariant.obsidianPulse,
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

  // ── Obsidian Apple Precision (DESIGN.md: SF Pro, 24/32px squircles, glass)
  static const apple = AppPalette(
    variant: AppThemeVariant.obsidianApplePrecision,
    base: Color(0xFF121317),
    surface1: Color(0xFF13151B),
    surface2: Color(0xFF1C1F26),
    surface3: Color(0xFF1F1F24),
    border: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    accent: Color(0xFF39FF94),
    onAccent: Color(0xFF0B0C10),
    accentGlow: Color(0x4039FF94), // rgba(57,255,148,.25)
    warning: Color(0xFFFF6B6B),
    warningBg: Color(0x1FC82A2A),
    warningBorder: Color(0x40C82A2A),
    textPrimary: Color(0xFFECECEC),
    textMuted: Color(0xFF6E7687),
    cardRadius: 24,
    controlRadius: 20,
    sheetRadius: 32,
    pillRadius: 999,
    checkboxRadius: 10,
    checkboxIsCircle: true, // today_tasks_1 uses round 20px checkboxes
    usesGlass: true,
    fontFamily: null, // system SF on iOS / Roboto fallback elsewhere
    monoNumerics: false,
  );

  static AppPalette of(AppThemeVariant v) =>
      v == AppThemeVariant.obsidianPulse ? pulse : apple;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 || other is! AppPalette ? this : other;
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
