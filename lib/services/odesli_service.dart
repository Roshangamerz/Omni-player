import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Reverse-engineered Echo Music Song.link (Odesli) Cross-Platform Sharing + Set as Ringtone
class OdesliService {
  static const MethodChannel _sysChannel = MethodChannel('com.omniplayer.music/system_actions');

  static Future<String> getUniversalShareLink(Track track) async {
    final vid = track.cleanVideoId;
    final ytmUrl = vid.length == 11
        ? 'https://music.youtube.com/watch?v=$vid'
        : (track.streamUrl.startsWith('http') ? track.streamUrl : '');

    if (ytmUrl.isNotEmpty) {
      try {
        final uri = Uri.https('api.song.link', '/v1-alpha.1/links', {'url': ytmUrl});
        final resp = await http.get(uri).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final pageUrl = json['pageUrl']?.toString() ?? '';
          if (pageUrl.isNotEmpty) return pageUrl;
        }
      } catch (_) {}
      return ytmUrl;
    }
    return '${track.title} — ${track.artist}';
  }

  static Future<void> shareTrack(Track track) async {
    final link = await getUniversalShareLink(track);
    final text = '🎵 ${track.title} — ${track.artist}\nListen on Omni Player:\n$link';
    try {
      await _sysChannel.invokeMethod('shareText', {
        'title': 'Share ${track.title}',
        'text': text,
      });
    } catch (_) {}
  }

  static Future<void> sharePlainText(String title, String text) async {
    try {
      await _sysChannel.invokeMethod('shareText', {'title': title, 'text': text});
    } catch (_) {}
  }

  static Future<({bool ok, bool needsPermission})> setRingtone(
      String filePath, String title) async {
    try {
      final res = await _sysChannel.invokeMapMethod<String, dynamic>('setRingtone', {
        'filePath': filePath,
        'title': title,
      });
      return (
        ok: res?['ok'] == true,
        needsPermission: res?['needsPermission'] == true,
      );
    } catch (_) {
      return (ok: false, needsPermission: false);
    }
  }
}
