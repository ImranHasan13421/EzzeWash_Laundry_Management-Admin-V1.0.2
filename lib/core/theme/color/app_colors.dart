// lib/core/theme/color/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Modern Indigo & Slate Theme
  static const primary    = Color(0xFF4F46E5); // Indigo 600
  static const secondary  = Color(0xFF312E81); // Indigo 900
  static const accent     = Color(0xFF6366F1); // Indigo 500

  static const gradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const background  = Color(0xFFF8FAFC); // Slate 50
  static const surface     = Colors.white;
  static const border      = Color(0xFFE2E8F0); // Slate 200
  static const text        = Color(0xFF0F172A); // Slate 900
  static const subtext     = Color(0xFF64748B); // Slate 500

  static const success = Color(0xFF10B981); // Emerald 500
  static const warning = Color(0xFFF59E0B); // Amber 500
  static const error   = Color(0xFFEF4444); // Red 500
  static const info    = Color(0xFF3B82F6); // Blue 500
}