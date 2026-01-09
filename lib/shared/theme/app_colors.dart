import 'package:flutter/material.dart';

/// Dark cyberpunk color palette for AShare.
abstract final class AppColors {
  // Primary colors - Neon cyan accent
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryDark = Color(0xFF00B8D4);
  static const Color primaryLight = Color(0xFF6EFFFF);

  // Secondary colors - Electric purple accent
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryDark = Color(0xFF651FFF);
  static const Color secondaryLight = Color(0xFFB388FF);

  // Background colors - Deep space dark
  static const Color background = Color(0xFF0D0D0F);
  static const Color backgroundElevated = Color(0xFF1A1A1F);
  static const Color backgroundCard = Color(0xFF242429);
  static const Color backgroundInput = Color(0xFF2A2A30);

  // Surface colors
  static const Color surface = Color(0xFF1E1E23);
  static const Color surfaceElevated = Color(0xFF28282E);

  // Text colors
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textTertiary = Color(0xFF6B6B6B);
  static const Color textDisabled = Color(0xFF4A4A4A);

  // Status colors
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB00);
  static const Color warningDark = Color(0xFFFF8F00);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD50000);
  static const Color info = Color(0xFF40C4FF);

  // Special states
  static const Color encrypted = Color(0xFF00E5FF);
  static const Color syncing = Color(0xFF7C4DFF);
  static const Color locked = Color(0xFFFF5252);
  static const Color unlocked = Color(0xFF00E676);

  // Border and divider
  static const Color border = Color(0xFF3A3A40);
  static const Color borderSubtle = Color(0xFF2A2A30);
  static const Color divider = Color(0xFF2A2A30);

  // Overlay
  static const Color overlay = Color(0xCC000000);
  static const Color overlayLight = Color(0x80000000);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Color(0xFF0A0A0C)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundCard, Color(0xFF1A1A1F)],
  );

  // Shadow color for elevated surfaces
  static const Color shadow = Color(0x40000000);
}
