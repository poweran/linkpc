import 'package:flutter/material.dart';

class AppColors {
  // Deep Void Backgrounds (from vless.linkpc.net)
  static const Color voidBlack = Color(0xFF040508);
  static const Color voidDark = Color(0xFF07090F);
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF0F1623);
  static const Color surfaceLight = Color(0xFF141C2B);
  static const Color elevated = Color(0xFF121727);

  // Borders & Dividers
  static const Color border = Color(0xFF1A2436);
  static const Color borderFocus = Color(0xFF00F0FF);
  static const Color borderSubtle = Color(0xFF243248);

  // Cyber Neon Accents
  static const Color cyberCyan = Color(0xFF00F0FF);
  static const Color skyBlue = Color(0xFF38BDF8);
  static const Color deepCyan = Color(0xFF0284C7);

  // Status & Telemetry
  static const Color neonEmerald = Color(0xFF00FF88);
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF334155);

  // Gradients
  static const LinearGradient cyberCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0F1623),
      Color(0xFF080C14),
    ],
  );

  static const LinearGradient activeGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FF88),
      Color(0xFF00F0FF),
    ],
  );

  static const LinearGradient cyanGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF38BDF8),
      Color(0xFF00F0FF),
      Color(0xFF0284C7),
    ],
  );
}
