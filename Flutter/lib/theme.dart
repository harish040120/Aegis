import 'package:flutter/material.dart';

class AegisTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Color(0xFF005A8D),
      scaffoldBackgroundColor: Color(0xFFF5F7FA),
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}