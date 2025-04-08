import 'package:flutter/material.dart';

class FocusFlowTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.black, // Keep as background base
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF121212),
      dividerColor: const Color(0xFF222222),
      hintColor: const Color(0xFF888888),
      fontFamily: 'Inter', // Set "Inter" as the default font (variable font)
      // Define a bluish color scheme
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueAccent, // Main bluish color for widgets
        onPrimary: Colors.white, // Text/icons on primary color
        secondary: Colors.blueAccent, // Accent color (replaces accentColor)
        onSecondary: Colors.white, // Text/icons on secondary color
        surface: Color(0xFF121212), // Matches cardColor
        onSurface: Color(0xFFE0E0E0), // Text/icons on surface
        background: Colors.black, // Matches scaffoldBackgroundColor
        onBackground: Color(0xFFE0E0E0), // Text/icons on background
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700, // Bold
          color: Colors.white,
        ),
        displayMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600, // Semi-bold
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400, // Regular
          color: Color(0xFFE0E0E0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400, // Regular
          color: Color(0xFFBBBBBB),
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600, // Semi-bold
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.blueAccent),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF121212),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
        hintStyle: TextStyle(color: Color(0xFF888888)),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600, // Semi-bold
          color: Colors.white,
          fontFamily: 'Inter', // Optional, inherited from ThemeData
        ),
      ),
    );
  }
}
