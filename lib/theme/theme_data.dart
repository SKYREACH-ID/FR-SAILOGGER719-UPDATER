import 'package:flutter/material.dart';

class CustomTheme {

  static ThemeData lightThemeData(BuildContext context) {
    return ThemeData(
    colorScheme: ColorScheme.light(
      primary: Color(0xFFF29124), //primary //secondary
      background: Color(0xFFF3F3F3), //background
      
      ),
    );
  }

  static ThemeData darkThemeData() {
    return ThemeData(
       colorScheme: ColorScheme.dark(
      primary: Color(0xFFF29124), //primary //secondary
      background: Color(0xFFF3F3F3), //background
      ),
    );
  }
}