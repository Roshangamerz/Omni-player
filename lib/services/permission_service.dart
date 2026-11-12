import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  static final AppPermissionService _instance = AppPermissionService._internal();
  factory AppPermissionService() => _instance;
  AppPermissionService._internal();

  bool _hasRequested = false;

  /// Request all required permissions for flawless background playback, notifications, and local audio access
  Future<void> requestAllPermissions() async {
    if (_hasRequested) return;
    _hasRequested = true;

    try {
      // 1. Notification Permission (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // 2. Battery Optimization Exemption for 100% Uninterrupted Background Playback
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // 3. Audio & Storage Permissions
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isDenied) {
        await Permission.audio.request();
      }

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        await Permission.storage.request();
      }
    } catch (e) {
      debugPrint('Permission request exception: $e');
    }
  }
}
