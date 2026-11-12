import 'dart:ui';
import 'package:flutter/material.dart';

enum AppThemeMode {
  oledNeonLime,  // Dark Planty (Emerald / Forest)
  dim,           // Dim / Slate Midnight
  pink,          // Barbie / Neon Bubblegum Pink
  marvels,       // Creator's Choice / Hero Themes
  custom,        // User Custom Color
  echoRose,      // Echo Music Signature Rose & Nothing OS Pure Black OLED
}

class AppTheme {
  final AppThemeMode mode;
  final bool isGlassEnabled;
  final bool isLiquidGlassEnabled;
  final bool isDarkMode;
  final Color? customPrimary;
  final Color? customBg;
  final String marvelHero;

  AppTheme({
    required this.mode,
    this.isGlassEnabled = true,
    this.isLiquidGlassEnabled = true,
    this.isDarkMode = true,
    this.customPrimary,
    this.customBg,
    this.marvelHero = 'iron_man',
  });

  bool get isDim => mode == AppThemeMode.dim;
  bool get isPink => mode == AppThemeMode.pink;
  bool get isCreatorsChoice => mode == AppThemeMode.marvels;
  bool get isMarvels => mode == AppThemeMode.marvels;
  bool get isCustom => mode == AppThemeMode.custom;

  Color get primary {
    if (isCustom && customPrimary != null) return customPrimary!;
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF0284C7);
      case AppThemeMode.pink:
        return const Color(0xFFFF2A85);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFFFF2A4D); // Iconic Spidey Scarlet Web Red
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFFA855F7); // Wakandan Vibranium Violet
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF2563EB); // First Avenger Shield Cobalt Blue
        if (marvelHero == 'infinity') return const Color(0xFFFFD700); // Celestial Reality Gauntlet Gold
        if (marvelHero == 'thor') return const Color(0xFF00E5FF); // Bifrost Lightning Sky Cyan
        if (marvelHero == 'deadpool') return const Color(0xFFFF003C); // Merc Tactical Crimson
        return const Color(0xFFFF1E42); // Stark Hotrod Crimson Red Armor
      case AppThemeMode.custom:
        return customPrimary ?? (isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669));
      case AppThemeMode.echoRose:
        return const Color(0xFFED5564); // Echo Music signature seed
      case AppThemeMode.oledNeonLime:
        return isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669); // Warm Lush Emerald Green
    }
  }

  Color get primaryGlow {
    if (isCustom && customPrimary != null) return customPrimary!;
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF38BDF8);
      case AppThemeMode.pink:
        return const Color(0xFFFF007F);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFFFF5277);
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFFC084FC);
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF60A5FA);
        if (marvelHero == 'infinity') return const Color(0xFFFACC15);
        if (marvelHero == 'thor') return const Color(0xFF38BDF8);
        if (marvelHero == 'deadpool') return const Color(0xFFFF4D6D);
        return const Color(0xFFFFD700); // Stark Hotrod Gold Glow
      case AppThemeMode.custom:
        return customPrimary ?? const Color(0xFF34D399);
      case AppThemeMode.echoRose:
        return const Color(0xFFFF7A88);
      case AppThemeMode.oledNeonLime:
        return const Color(0xFF34D399); // Warm Emerald Glow
    }
  }

  Color get primaryForeground => (mode == AppThemeMode.marvels && (marvelHero == 'infinity' || marvelHero == 'thor')) ? Colors.black : Colors.white;

  Color get secondary {
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF0EA5E9);
      case AppThemeMode.pink:
        return const Color(0xFFF43F5E);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFF00D4FF); // Stark Tech Web-Shooter Cyan
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFFFACC15); // Wakandan Gold
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFFEF4444); // Shield Outer Crimson Red
        if (marvelHero == 'infinity') return const Color(0xFF8B5CF6); // Power Gem Violet
        if (marvelHero == 'thor') return const Color(0xFFF1F5F9); // Mjolnir Uru Steel
        if (marvelHero == 'deadpool') return const Color(0xFFE2E8F0); // Tactical Gunmetal Silver
        return const Color(0xFFFFC300); // Stark Gold Accents
      case AppThemeMode.custom:
        return (customPrimary ?? const Color(0xFF10B981)).withValues(alpha: 0.8);
      case AppThemeMode.echoRose:
        return const Color(0xFFFB7185);
      case AppThemeMode.oledNeonLime:
        return const Color(0xFFA3E635); // Warm Botanical Lime Olive Accent
    }
  }

  Color get scaffoldBg {
    if (!isDarkMode) return const Color(0xFFF1F5F9);
    if (isCustom && customBg != null) return customBg!;
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF0B1120);
      case AppThemeMode.pink:
        return const Color(0xFF160512);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFF060914); // Queens Midnight Noir
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFF08020F); // Wakandan Obsidian
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF060B18); // Stealth Navy
        if (marvelHero == 'infinity') return const Color(0xFF0A0314); // Titan Void
        if (marvelHero == 'thor') return const Color(0xFF030C16); // Asgardian Deep Space
        if (marvelHero == 'deadpool') return const Color(0xFF080808); // Pitch Tactical Noir
        return const Color(0xFF120307); // Stark Crimson Armor Dark
      case AppThemeMode.custom:
        return customBg ?? const Color(0xFF050E08);
      case AppThemeMode.echoRose:
        return const Color(0xFF000000); // Pure Black OLED (Nothing OS / Echo)
      case AppThemeMode.oledNeonLime:
        return const Color(0xFF050E08); // Warm Botanical Deep Moss Obsidian
    }
  }

  Color get cardBg {
    if (!isDarkMode) {
      return Colors.white;
    }
    if (!isGlassEnabled) {
      switch (mode) {
        case AppThemeMode.dim:
          return const Color(0xFF1E293B);
        case AppThemeMode.pink:
          return const Color(0xFF320E26);
        case AppThemeMode.marvels:
          if (marvelHero == 'deadpool') return const Color(0xFF141414);
          if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFF1E0B2B);
          if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFF0C1428);
          if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF0D1830);
          if (marvelHero == 'thor') return const Color(0xFF081827);
          if (marvelHero == 'infinity') return const Color(0xFF1C0830);
          return const Color(0xFF22070E); // Stark Armor Crimson
        case AppThemeMode.custom:
          return const Color(0xFF0D1424);
        case AppThemeMode.echoRose:
          return const Color(0xFF121216);
        case AppThemeMode.oledNeonLime:
          return const Color(0xFF08140E);
      }
    }
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF0284C7).withValues(alpha: 0.08);
      case AppThemeMode.pink:
        return const Color(0xFFBE185D).withValues(alpha: 0.08);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFFFF2A4D).withValues(alpha: 0.10);
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFF7E22CE).withValues(alpha: 0.10);
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF1E3A8A).withValues(alpha: 0.12);
        if (marvelHero == 'infinity') return const Color(0xFFD97706).withValues(alpha: 0.10);
        if (marvelHero == 'thor') return const Color(0xFF0284C7).withValues(alpha: 0.10);
        if (marvelHero == 'deadpool') return const Color(0xFFFF003C).withValues(alpha: 0.08);
        return const Color(0xFFFF1E42).withValues(alpha: 0.10); // Stark Crimson Armor
      case AppThemeMode.custom:
        return (customPrimary ?? const Color(0xFF10B981)).withValues(alpha: 0.08);
      case AppThemeMode.echoRose:
        return const Color(0xFFFFFFFF).withValues(alpha: 0.07);
      case AppThemeMode.oledNeonLime:
        return const Color(0xFF10B981).withValues(alpha: 0.08); // Frosted Warm Botanical Glass
    }
  }

  Color get cardBorder {
    if (!isDarkMode) {
      return const Color(0xFFCBD5E1);
    }
    if (!isGlassEnabled) {
      switch (mode) {
        case AppThemeMode.dim:
          return const Color(0xFF38BDF8).withValues(alpha: 0.2);
        case AppThemeMode.pink:
          return const Color(0xFFFF2A85).withValues(alpha: 0.3);
        case AppThemeMode.marvels:
          if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFFFF2A4D).withValues(alpha: 0.40);
          if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFFA855F7).withValues(alpha: 0.40);
          if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF3B82F6).withValues(alpha: 0.40);
          if (marvelHero == 'infinity') return const Color(0xFFFFD700).withValues(alpha: 0.45);
          if (marvelHero == 'thor') return const Color(0xFF00E5FF).withValues(alpha: 0.40);
          if (marvelHero == 'deadpool') return const Color(0xFFFF003C).withValues(alpha: 0.40);
          return const Color(0xFFFFD700).withValues(alpha: 0.40); // Stark Gold Border
        case AppThemeMode.custom:
          return (customPrimary ?? const Color(0xFF10B981)).withValues(alpha: 0.25);
        case AppThemeMode.echoRose:
          return const Color(0xFFED5564).withValues(alpha: 0.25);
        case AppThemeMode.oledNeonLime:
          return const Color(0xFF10B981).withValues(alpha: 0.25);
      }
    }
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF38BDF8).withValues(alpha: 0.25);
      case AppThemeMode.pink:
        return const Color(0xFFFF2A85).withValues(alpha: 0.28);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFFFF2A4D).withValues(alpha: 0.35);
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFFA855F7).withValues(alpha: 0.35);
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF3B82F6).withValues(alpha: 0.35);
        if (marvelHero == 'infinity') return const Color(0xFFFFD700).withValues(alpha: 0.38);
        if (marvelHero == 'thor') return const Color(0xFF00E5FF).withValues(alpha: 0.35);
        if (marvelHero == 'deadpool') return const Color(0xFFFF003C).withValues(alpha: 0.35);
        return const Color(0xFFFFD700).withValues(alpha: 0.35); // Stark Gold Glow
      case AppThemeMode.custom:
        return (customPrimary ?? Colors.white).withValues(alpha: 0.25);
      case AppThemeMode.echoRose:
        return const Color(0xFFFFFFFF).withValues(alpha: 0.14);
      case AppThemeMode.oledNeonLime:
        return const Color(0xFF10B981).withValues(alpha: 0.28); // Warm Emerald Border
    }
  }

  Color get navBarBg {
    if (!isDarkMode) {
      return Colors.white;
    }
    if (!isGlassEnabled) {
      switch (mode) {
        case AppThemeMode.dim:
          return const Color(0xFF0F172A);
        case AppThemeMode.pink:
          return const Color(0xFF1F0819);
        case AppThemeMode.marvels:
          if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFF080D1A);
          if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFF150624);
          if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF0A1226);
          if (marvelHero == 'infinity') return const Color(0xFF120524);
          if (marvelHero == 'thor') return const Color(0xFF05101C);
          if (marvelHero == 'deadpool') return const Color(0xFF121212);
          return const Color(0xFF1E060C);
        case AppThemeMode.custom:
          return const Color(0xFF080D18);
        case AppThemeMode.echoRose:
          return const Color(0xFF0E0E10);
        case AppThemeMode.oledNeonLime:
          return const Color(0xFF06120B);
      }
    }
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF0B1120).withValues(alpha: 0.12);
      case AppThemeMode.pink:
        return const Color(0xFF22081C).withValues(alpha: 0.12);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFF080D1A).withValues(alpha: 0.16);
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFF1E0A30).withValues(alpha: 0.15);
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFF0C1938).withValues(alpha: 0.15);
        if (marvelHero == 'infinity') return const Color(0xFF1C0830).withValues(alpha: 0.15);
        if (marvelHero == 'thor') return const Color(0xFF0A1828).withValues(alpha: 0.15);
        if (marvelHero == 'deadpool') return const Color(0xFF141414).withValues(alpha: 0.20);
        return const Color(0xFF1F060D).withValues(alpha: 0.18);
      case AppThemeMode.custom:
      case AppThemeMode.oledNeonLime:
        return const Color(0xFF041008).withValues(alpha: 0.10);
      case AppThemeMode.echoRose:
        return const Color(0xFF121214).withValues(alpha: 0.45);
    }
  }

  Color get textPrimary => isDarkMode ? Colors.white : const Color(0xFF0F172A);

  Color get textSecondary {
    if (!isDarkMode) return const Color(0xFF475569);
    switch (mode) {
      case AppThemeMode.dim:
        return const Color(0xFF94A3B8);
      case AppThemeMode.pink:
        return const Color(0xFFFBCFE8);
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') return const Color(0xFFBAE6FD); // Web Silk Light Blue
        if (marvelHero == 'panther' || marvelHero == 'black_panther') return const Color(0xFFE9D5FF); // Vibranium Lavender
        if (marvelHero == 'cap' || marvelHero == 'captain_america') return const Color(0xFFE2E8F0); // Star Silver
        if (marvelHero == 'deadpool') return const Color(0xFFCBD5E1); // Katana Steel
        if (marvelHero == 'infinity') return const Color(0xFFFDE68A); // Celestial Gold
        if (marvelHero == 'thor') return const Color(0xFFBAE6FD); // Thunder Sky Mist
        return const Color(0xFFFDE68A); // Stark Gold Amber
      case AppThemeMode.custom:
      case AppThemeMode.oledNeonLime:
        return const Color(0xFFA7F3D0).withValues(alpha: 0.75);
      case AppThemeMode.echoRose:
        return const Color(0xFFB3B3B8);
    }
  }

  LinearGradient get bgGradient {
    if (!isDarkMode) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
      );
    }
    if (isCustom && customBg != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [customBg!, customBg!.withValues(alpha: 0.8), Colors.black],
      );
    }
    switch (mode) {
      case AppThemeMode.dim:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
        );
      case AppThemeMode.pink:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF380928), Color(0xFF1A0413), Color(0xFF080006)],
        );
      case AppThemeMode.marvels:
        if (marvelHero == 'spider' || marvelHero == 'spiderman') {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22050E), Color(0xFF0A1028), Color(0xFF02040A)],
          );
        }
        if (marvelHero == 'deadpool') {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF180306), Color(0xFF0A0204), Color(0xFF000000)],
          );
        }
        if (marvelHero == 'panther' || marvelHero == 'black_panther') {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C0A33), Color(0xFF0E041C), Color(0xFF040108)],
          );
        }
        if (marvelHero == 'cap' || marvelHero == 'captain_america') {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1836), Color(0xFF050D1E), Color(0xFF02050C)],
          );
        }
        if (marvelHero == 'thor') {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06182C), Color(0xFF030E1A), Color(0xFF01050A)],
          );
        }
        if (marvelHero == 'infinity') {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22083A), Color(0xFF10031E), Color(0xFF05010A)],
          );
        }
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF28050E), Color(0xFF140207), Color(0xFF080103)], // Rich Stark Crimson Metallic
        );
      case AppThemeMode.custom:
      case AppThemeMode.oledNeonLime:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF081C10), Color(0xFF040E08), Color(0xFF010503)],
        );
      case AppThemeMode.echoRose:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14090C), Color(0xFF060608), Color(0xFF000000)],
        );
    }
  }

  ThemeData get themeData => ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: scaffoldBg,
        primaryColor: primary,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          primary: primary,
          onPrimary: primaryForeground,
          secondary: secondary,
          onSecondary: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
          surface: cardBg,
          onSurface: textPrimary,
        ),
        useMaterial3: true,
      );
}

/// Frosted glass card widget — crisp solid styling in Light mode, frosted blur in Dark mode.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool isGlass;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.blur = 16.0,
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.shadows,
    this.onTap,
    this.isGlass = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget content;

    if (!isDark) {
      // Pristine, crisp, high-contrast solid card for Light Mode
      content = Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? const Color(0xFFE2E8F0),
            width: borderWidth,
          ),
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
    } else if (!isGlass) {
      content = Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.1),
            width: borderWidth,
          ),
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
    } else {
      content = Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.04),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: color ?? Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: borderColor ?? Colors.white.withValues(alpha: 0.22),
                  width: borderWidth,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.03),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}
