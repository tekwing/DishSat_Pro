import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF081120);
  static const card = Color(0xFF111C2E);

  static const primary = Color(0xFF3B82F6);
  static const accent = Color(0xFF22C55E);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,

    scaffoldBackgroundColor: AppColors.background,

    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
