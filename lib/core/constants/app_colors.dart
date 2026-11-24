import 'package:flutter/material.dart';

class AppColors {
  // Deep Void Backgrounds & Volumetric Depth
  static const Color voidBlack = Color(0xFF030508);
  static const Color voidDark = Color(0xFF060911);
  static const Color background = Color(0xFF070B14);
  static const Color surface = Color(0xFF0E1524);
  static const Color surfaceLight = Color(0xFF131D31);
  static const Color elevated = Color(0xFF17243B);
  static const Color glassSurface = Color(0xCC0A101D);

  // Borders & Specular Highlights
  static const Color border = Color(0xFF1B283F);
  static const Color borderFocus = Color(0xFF00F0FF);
  static const Color borderSubtle = Color(0xFF253754);
  static const Color borderHighlight = Color(0x6600F0FF);

  // Cyber Neon & Holographic Palette
  static const Color cyberCyan = Color(0xFF00F0FF);
  static const Color skyBlue = Color(0xFF38BDF8);
  static const Color deepCyan = Color(0xFF0284C7);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color hologramPurple = Color(0xFFA855F7);
  static const Color laserPink = Color(0xFFFF007A);

  // Status & Telemetry
  static const Color neonEmerald = Color(0xFF00FF88);
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Typography & Overlays
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF334155);
  static const Color telemetryGreen = Color(0xFF10E79D);

  // Multidimensional Gradients
  static const LinearGradient cyberCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE610192A),
      Color(0xF2070B14),
    ],
  );

  static const LinearGradient glassSpecularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x3300F0FF),
      Color(0x0500F0FF),
      Color(0x228B5CF6),
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

  static const LinearGradient quantumPortalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00F0FF),
      Color(0xFF8B5CF6),
      Color(0xFF00FF88),
    ],
  );

  static const RadialGradient dimensionalCoreGradient = RadialGradient(
    colors: [
      Color(0x5500F0FF),
      Color(0x220284C7),
      Color(0x00000000),
    ],
    stops: [0.0, 0.5, 1.0],
  );
}
