import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xff233743);
  static const Color secondaryColor = Color(0xff748288);
  static const Color backgroundColor = Color(0xffEEF1F3);
  static const Color surfaceColor = Colors.white;
  static const Color lightTextColor = Color(0xff939393);
  static const Color iconButtonColor = Color(0xFF4A90E2); // Using a more descriptive name

  static final ThemeData themeData = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'NotoSerif',
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: surfaceColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: iconButtonColor,
        foregroundColor: surfaceColor,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 2,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: surfaceColor,
        textStyle: const TextStyle(fontSize: 20),
      ),
    ),
  );
}