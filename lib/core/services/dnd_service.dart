import 'package:flutter/services.dart';
import 'dart:io';

class DNDService {
  static const _channel = MethodChannel('com.example.studysync/dnd');

  /// Checks if the Notification Policy Access (DND setting toggle permission) is granted.
  static Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Opens the system Do Not Disturb Access permission settings page.
  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } on PlatformException catch (_) {}
  }

  /// Enables or disables Do Not Disturb (Priority Only Mode).
  static Future<void> setDND(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      final granted = await isPermissionGranted();
      if (granted) {
        await _channel.invokeMethod('setDND', {'enable': enable});
      }
    } on PlatformException catch (_) {}
  }
}
