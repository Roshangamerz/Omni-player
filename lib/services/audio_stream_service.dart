import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'echo_innertube_service.dart';

/// Production-Grade, Zero-Bloat Audio Stream Extractor
/// Extracts direct 256kbps Googlevideo CDN streams with in-flight deduplication and bounded cache.
class AudioStreamService {
  static final AudioStreamService _instance = AudioStreamService._internal();
  factory AudioStreamService() => _instance;
  AudioStreamService._internal();

  final YoutubeExplode _yt = YoutubeExplode();

  // Bounded memory cache: max 60 active streams to prevent memory leaks
  static const int _maxCacheSize = 60;
  static const int _streamTtlMs = 4 * 3600 * 1000; // 4-hour TTL

  final Map<String, _CachedEntry> _streamCache = {};
  final Map<String, Future<String?>> _inFlight = {};

  /// Extract highest quality stream URL directly from YouTube CDNs
  Future<String?> resolveStreamUrl(String rawVideoId) async {
    final videoId = rawVideoId.replaceAll('yt_', '').trim();
    if (videoId.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Instant 0ms memory cache lookup
    final cached = _streamCache[videoId];
    if (cached != null && cached.expireAtMs > now) {
      return cached.url;
    }

    // 2. In-flight request deduplication (prevents duplicate simultaneous network calls)
    if (_inFlight.containsKey(videoId)) {
      return _inFlight[videoId];
    }

    final future = _fetchStreamUrl(videoId, now);
    _inFlight[videoId] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlight.remove(videoId);
    }
  }

  Future<String?> _fetchStreamUrl(String videoId, int now) async {
    // Tier 1: Direct YoutubeExplode Googlevideo CDN Extraction (Prioritizing MP4/AAC for 100% Android MediaPlayer compatibility)
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(
        const Duration(seconds: 12),
      );
      
      final mp4Audio = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase() == 'mp4' || s.codec.mimeType.contains('mp4') || s.codec.mimeType.contains('aac'))
          .toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

      if (mp4Audio.isNotEmpty) {
        final url = mp4Audio.first.url.toString();
        _putCache(videoId, url, now + _streamTtlMs);
        return url;
      }

      final anyAudio = manifest.audioOnly.sortByBitrate();
      if (anyAudio.isNotEmpty) {
        final url = anyAudio.first.url.toString();
        _putCache(videoId, url, now + _streamTtlMs);
        return url;
      }
    } catch (e) {
      debugPrint('YoutubeExplode stream resolution manifest fallback for $videoId: $e');
    }

    // Tier 2: Echo InnerTube Direct Player API (ANDROID_VR / IOS)
    try {
      final directIt = await EchoInnerTubeService().resolveStreamUrlDirect(videoId);
      if (directIt != null && directIt.isNotEmpty) {
        _putCache(videoId, directIt, now + _streamTtlMs);
        return directIt;
      }
    } catch (_) {}

    // Tier 3: YouTube Direct HLS Stream Extraction (Fast .m3u8 stream)
    try {
      final hlsUrl = await _yt.videos.streamsClient.getHttpLiveStreamUrl(VideoId(videoId)).timeout(
        const Duration(seconds: 4),
      );
      if (hlsUrl.isNotEmpty) {
        _putCache(videoId, hlsUrl, now + _streamTtlMs);
        return hlsUrl;
      }
    } catch (_) {}

    // Tier 3: Piped API High-Speed Audio Stream Resolution Fallback (M4A / MP3)
    final pipedBases = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.privacydev.net',
      'https://pipedapi.tokhmi.xyz',
      'https://pipedapi.leptons.xyz',
      'https://pa.il.ax',
    ];

    for (final base in pipedBases) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);
        final request = await client.getUrl(Uri.parse('$base/streams/$videoId'));
        final response = await request.close().timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final audioStreams = data['audioStreams'] as List<dynamic>? ?? [];
          if (audioStreams.isNotEmpty) {
            // Prioritize Android-friendly AAC / M4A / MP3
            final aacStreams = audioStreams.where((s) {
              final mime = (s['mimeType'] as String? ?? '').toLowerCase();
              final format = (s['format'] as String? ?? '').toLowerCase();
              return mime.contains('mp4') || mime.contains('aac') || format.contains('m4a') || format.contains('mp3');
            }).toList();

            final targetList = aacStreams.isNotEmpty ? aacStreams : audioStreams;
            targetList.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
            final url = targetList.first['url'] as String?;
            if (url != null && url.isNotEmpty) {
              _putCache(videoId, url, now + _streamTtlMs);
              return url;
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  void _putCache(String videoId, String url, int expireAtMs) {
    if (_streamCache.length >= _maxCacheSize) {
      _streamCache.remove(_streamCache.keys.first);
    }
    _streamCache[videoId] = _CachedEntry(url, expireAtMs);
  }

  void clearCacheForId(String rawVideoId) {
    final videoId = rawVideoId.replaceAll('yt_', '').trim();
    _streamCache.remove(videoId);
    _inFlight.remove(videoId);
  }

  void clearCache() {
    _streamCache.clear();
    _inFlight.clear();
  }

  void dispose() {
    _yt.close();
    _streamCache.clear();
    _inFlight.clear();
  }
}

class _CachedEntry {
  final String url;
  final int expireAtMs;
  const _CachedEntry(this.url, this.expireAtMs);
}
