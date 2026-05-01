// lib/core/theme/color/app_colors.dart
import 'package:flutter/material.dart';
import '../../../main.dart';

class AppColors {
  AppColors._();

  static bool get _isDark => darkModeNotifier.value;

  // Primary colors remain static
  static const primary    = Color(0xFF05BCFF);
  static const secondary  = Color(0xFF312E81);
  static const accent     = Color(0xFF6366F1);

  static const gradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // --- DYNAMIC GETTERS ---
  static Color get background => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get surface    => _isDark ? const Color(0xFF1E293B) : Colors.white;
  static Color get border     => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  static Color get text       => _isDark ? Colors.white : const Color(0xFF0F172A);
  static Color get subtext    => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);
}