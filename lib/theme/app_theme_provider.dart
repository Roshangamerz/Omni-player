import 'package:flutter/material.dart';
import 'app_theme.dart';

/// InheritedWidget that holds the current [AppTheme].
/// Widgets call [AppThemeProvider.of(context)] to get the theme
/// without triggering full tree rebuilds on every state change.
class AppThemeProvider extends InheritedWidget {
  final AppTheme theme;

  const AppThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  static AppTheme of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppThemeProvider>();
    assert(provider != null, 'No AppThemeProvider found in widget tree');
    return provider!.theme;
  }

  static AppTheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppThemeProvider>()
        ?.theme;
  }

  @override
  bool updateShouldNotify(AppThemeProvider oldWidget) {
    // Only trigger rebuilds when the theme actually changes
    return theme.mode != oldWidget.theme.mode ||
        theme.isDarkMode != oldWidget.theme.isDarkMode ||
        theme.isGlassEnabled != oldWidget.theme.isGlassEnabled ||
        theme.isLiquidGlassEnabled != oldWidget.theme.isLiquidGlassEnabled ||
        theme.customPrimary != oldWidget.theme.customPrimary ||
        theme.customBg != oldWidget.theme.customBg ||
        theme.marvelHero != oldWidget.theme.marvelHero;
  }
}
