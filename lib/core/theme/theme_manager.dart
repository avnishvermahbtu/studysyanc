import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<bool> isLightNotifier = ValueNotifier<bool>(false);

  static Future<void> init() async {
    isLightNotifier.value = false;
  }

  static bool get isLight => false;

  static Future<void> toggleTheme(bool isLight) async {
    isLightNotifier.value = false;
  }

  // Dynamic colors matching both styles
  static Color get bgColor => isLight ? const Color(0xfff1f5f9) : const Color(0xff020617);
  static Color get cardBg => isLight ? Colors.white : const Color(0xff0d0e15);
  static Color get textColor => isLight ? const Color(0xff0f172a) : Colors.white;
  static Color get textMuted => isLight ? const Color(0xff475569) : Colors.white54;
  static Color get textDim => isLight ? const Color(0xff94a3b8) : Colors.white30;
  static Color get border => isLight ? const Color(0xffcbd5e1) : Colors.white.withOpacity(0.08);
  static Color get glassColor => isLight ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.03);
  static Color get inputFill => isLight ? const Color(0xffe2e8f0) : Colors.white.withOpacity(0.01);
  static Color get dialogBg => isLight ? Colors.white : const Color(0xff0f172a);
}
