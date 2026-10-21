import 'package:flutter/material.dart';

/// Semantic design tokens ported from the original app's constants/colors.ts.
class AppColors {
  final Color text;
  final Color tint;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final double radius;

  const AppColors({
    required this.text,
    required this.tint,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    this.radius = 8,
  });

  static const light = AppColors(
    text: Color(0xFF16382f),
    tint: Color(0xFF216b52),
    background: Color(0xFFf7f5ef),
    foreground: Color(0xFF18382f),
    card: Color(0xFFffffff),
    cardForeground: Color(0xFF18382f),
    primary: Color(0xFF216b52),
    primaryForeground: Color(0xFFffffff),
    secondary: Color(0xFFe9eee8),
    secondaryForeground: Color(0xFF294b40),
    muted: Color(0xFFeeeee8),
    mutedForeground: Color(0xFF6e7d75),
    accent: Color(0xFFf2e7ce),
    accentForeground: Color(0xFF715c2f),
    destructive: Color(0xFFef4444),
    destructiveForeground: Color(0xFFffffff),
    border: Color(0xFFe4e5dc),
    input: Color(0xFFdfe2d9),
  );

  static const dark = AppColors(
    text: Color(0xFFedf3ed),
    tint: Color(0xFF8cc8a6),
    background: Color(0xFF111c18),
    foreground: Color(0xFFedf3ed),
    card: Color(0xFF1a2922),
    cardForeground: Color(0xFFedf3ed),
    primary: Color(0xFF8cc8a6),
    primaryForeground: Color(0xFF10251a),
    secondary: Color(0xFF26372e),
    secondaryForeground: Color(0xFFe3eee5),
    muted: Color(0xFF223129),
    mutedForeground: Color(0xFFa5b2a8),
    accent: Color(0xFF443b27),
    accentForeground: Color(0xFFf0d28c),
    destructive: Color(0xFFf87171),
    destructiveForeground: Color(0xFFffffff),
    border: Color(0xFF304138),
    input: Color(0xFF384940),
  );

  static AppColors of(BuildContext context) {
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? dark
        : light;
  }
}

const _arabicFontFallback = <String>['NotoSansArabic'];

ThemeData buildAppTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansArabic'],
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.primaryForeground,
      secondary: c.secondary,
      onSecondary: c.secondaryForeground,
      error: c.destructive,
      onError: c.destructiveForeground,
      surface: c.card,
      onSurface: c.foreground,
    ),
  );

  final fg = c.foreground;
  final muted = c.mutedForeground;
  final textTheme = TextTheme(
    displaySmall: TextStyle(
        fontSize: 27, fontWeight: FontWeight.w700, color: fg),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: fg),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
    bodyMedium: TextStyle(fontSize: 14, color: fg),
    bodySmall: TextStyle(fontSize: 12, color: muted),
  ).apply(fontFamily: 'Inter', fontFamilyFallback: _arabicFontFallback);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: c.background,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primary.withValues(alpha: 0.25),
    ),
  );
}
