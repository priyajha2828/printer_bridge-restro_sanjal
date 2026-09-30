import 'package:flutter/material.dart';

/// Every colour used by the Print Bridge UI lives here.
/// Change a value once and the whole app updates.
class AppColors {
  AppColors._();

  // --- Brand ---------------------------------------------------------------
  static const Color pageBg = Color(0xFFF0FAF3);
  static const Color green = Color(0xFF1E7D3C);
  static const Color greenDark = Color(0xFF145C2C);
  static const Color deepGreen = Color(0xFF004532);
  static const Color copper = Color(0xFFC45C20);
  static const Color cream = Color(0xFFF1E9DB);
  static const Color creamBorder = Color(0xFFE2D5BC);
  static const Color creamBox = Color(0xFFF7F5F0);
  static const Color brown = Color(0xFF5B4636);

  // --- Text ----------------------------------------------------------------
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color subtle = Color(0xFF9CA3AF);

  // --- Surfaces / inputs ---------------------------------------------------
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color inputBg = Color(0xFFF9F9FF);
  static const Color inputDisabledBg = Color(0xFFF3F4F6);
  static const Color pillBg = Color(0xFFE6F8E9);
  static const Color pillBorder = Color(0xFFB8E8C8);

  // --- States --------------------------------------------------------------
  static const Color error = Color(0xFFB3261E);
  static const Color progress = Color(0xFF1976D2);

  // --- Status dot ----------------------------------------------------------
  static const Color statusConnected = Color(0xFF4CAF50);
  static const Color statusConnecting = Color(0xFFFF9800);
  static const Color statusError = Color(0xFFF44336);
  static const Color statusDisconnected = Color(0xFFBDBDBD);

  // --- Buttons -------------------------------------------------------------
  static const List<Color> connectGradient = [
    Color(0xFF0E5511),
    Color(0xFF1FBB25),
  ];
  static const List<Color> disconnectGradient = [
    Color(0xFF9B1C15),
    Color(0xFFB3261E),
  ];

  // --- Activity log terminal ----------------------------------------------
  static const Color terminalBg = Color(0xFF0F172A);
  static const Color terminalText = Color(0xFFE5E7EB);
  static const Color terminalTime = Color(0xFF6B7280);
  static const Color logError = Color(0xFFEF4444);
  static const Color logWarn = Color(0xFFF59E0B);
  static const Color logInfo = Color(0xFF38BDF8);
  static const Color logDebug = Color(0xFF9CA3AF);

  // --- Splash --------------------------------------------------------------
  static const Color splashBg = Color(0xFFFFFFFF);
  static const Color splashAccent = Color(0xFFB3120F);
}