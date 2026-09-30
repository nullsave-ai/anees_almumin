import 'package:flutter/material.dart';

class AppColors {
  static const green = Color(0xFF1F6F5C);
  static const deep = Color(0xFF14483C);
  static const ink = Color(0xFF16302B);
  static const sand = Color(0xFFF6F3EC);
  static const gold = Color(0xFFB8934A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, surface: AppColors.sand);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.sand,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.sand,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.green.withAlpha(30),
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
    ),
  );
}
