import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Echo Music Backup & Restore Service (JSON Snapshot of Library, Playlists, Settings & Addons)
class BackupService {
  static const List<String> _keysToExport = [
    'omni_liked_tracks',
    'omni_user_playlists',
    'omni_history',
    'omni_listening_stats_v1',
    'echo_extension_addons_v1',
    'omni_find_recognition_history',
    'omni_user_name',
    'omni_theme_mode',
    'omni_player_style',
  ];

  static Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'app': 'OmniPlayer',
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': <String, dynamic>{},
    };
    final dataMap = payload['data'] as Map<String, dynamic>;
    for (final k in _keysToExport) {
      final v = prefs.get(k);
      if (v != null) dataMap[k] = v;
    }
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<int> importBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid Omni Player backup format');
    }
    final prefs = await SharedPreferences.getInstance();
    final dataMap = decoded['data'] as Map<String, dynamic>;
    int restored = 0;
    for (final entry in dataMap.entries) {
      if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
        restored++;
      } else if (entry.value is bool) {
        await prefs.setBool(entry.key, entry.value as bool);
        restored++;
      } else if (entry.value is int) {
        await prefs.setInt(entry.key, entry.value as int);
        restored++;
      }
    }
    return restored;
  }
}
