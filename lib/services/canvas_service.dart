import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/echo_models.dart';

/// Reverse-engineered Looping Canvas & Motion Artwork Service
/// Combines EchoMusic Canvas, Tidal Canvas, and Apple Music Motion Artwork (AMP).
class CanvasService {
  static final CanvasService _instance = CanvasService._internal();
  factory CanvasService() => _instance;
  CanvasService._internal();

  static const String _echoCanvasUrl = 'https://canvas.echomusic.fun/canvas.json';
  static const String _tidalBase = 'https://api.tidal.com/v1/';
  static const String _tidalToken = 'vNVdglQOjFJJGG2U';
  static const String _ampBase = 'https://amp-api.music.apple.com';

  final http.Client _client = http.Client();
  final Map<String, CanvasArtworkResult?> _cache = {};
  List<dynamic>? _echoManifest;
  DateTime? _echoManifestExpiry;
  String? _appleToken;

  Future<CanvasArtworkResult?> getCanvasForTrack({
    required String song,
    required String artist,
    String album = '',
  }) async {
    final cleanSong = _clean(song);
    final cleanArtist = artist.split(RegExp(r'[,&x/•]')).first.trim();
    if (cleanSong.isEmpty || cleanArtist.isEmpty) return null;

    final key = '${cleanSong.toLowerCase()}|${cleanArtist.toLowerCase()}';
    if (_cache.containsKey(key)) return _cache[key];

    // 1. EchoMusic Canvas manifest (fast, curated MP4 loops)
    final echoRes = await _fetchEchoCanvas(cleanSong, cleanArtist);
    if (echoRes != null) {
      _cache[key] = echoRes;
      return echoRes;
    }

    // 2. Tidal Canvas (MP4 1280x1280 videoCover)
    final tidalRes = await _fetchTidalCanvas(cleanSong, cleanArtist, album);
    if (tidalRes != null) {
      _cache[key] = tidalRes;
      return tidalRes;
    }

    // 3. Apple Music Editorial Video (HLS motion artwork)
    final appleRes = await _fetchAppleMotionCanvas(cleanSong, cleanArtist);
    _cache[key] = appleRes;
    return appleRes;
  }

  Future<CanvasArtworkResult?> _fetchEchoCanvas(String song, String artist) async {
    try {
      if (_echoManifest == null ||
          _echoManifestExpiry == null ||
          DateTime.now().isAfter(_echoManifestExpiry!)) {
        final resp = await _client
            .get(Uri.parse(_echoCanvasUrl))
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body);
          _echoManifest = json['items'] as List<dynamic>? ?? const [];
          _echoManifestExpiry = DateTime.now().add(const Duration(minutes: 2));
        }
      }
      final items = _echoManifest;
      if (items == null) return null;
      final sLower = song.toLowerCase();
      final aLower = artist.toLowerCase();
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final isong = (item['song']?.toString() ?? '').toLowerCase();
        final iart = (item['artist']?.toString() ?? '').toLowerCase();
        final url = item['url']?.toString() ?? '';
        if (url.isNotEmpty &&
            isong.isNotEmpty &&
            iart.isNotEmpty &&
            (sLower.contains(isong) || isong.contains(sLower)) &&
            (aLower.contains(iart) || iart.contains(aLower))) {
          return CanvasArtworkResult(videoUrl: url, provider: 'EchoCanvas');
        }
      }
    } catch (_) {}
    return null;
  }

  Future<CanvasArtworkResult?> _fetchTidalCanvas(
      String song, String artist, String album) async {
    try {
      final q = album.isNotEmpty ? '$album $artist $song' : '$artist $song';
      final uri = Uri.parse('${_tidalBase}search').replace(queryParameters: {
        'query': q,
        'limit': '8',
        'types': 'TRACKS',
        'countryCode': 'US',
      });
      final resp = await _client.get(uri, headers: {
        'X-Tidal-Token': _tidalToken,
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = json['tracks']?['items'] as List<dynamic>? ?? const [];
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final rTitle = (item['title']?.toString() ?? '').toLowerCase();
          if (!rTitle.contains(song.toLowerCase()) && !song.toLowerCase().contains(rTitle)) {
            continue;
          }
          final videoCover = item['album']?['videoCover']?.toString() ?? '';
          final parts = videoCover.split('-');
          if (parts.length == 5) {
            final mp4Url =
                'https://resources.tidal.com/videos/${parts[0]}/${parts[1]}/${parts[2]}/${parts[3]}/${parts[4]}/1280x1280.mp4';
            return CanvasArtworkResult(videoUrl: mp4Url, provider: 'Tidal Canvas');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _getAppleToken() async {
    if (_appleToken != null) return _appleToken;
    try {
      final htmlResp = await _client
          .get(Uri.parse('https://beta.music.apple.com'))
          .timeout(const Duration(seconds: 5));
      if (htmlResp.statusCode == 200) {
        final match = RegExp(r'src="(/assets/index-[^"]+\.js)"').firstMatch(htmlResp.body);
        if (match != null) {
          final jsResp = await _client
              .get(Uri.parse('https://beta.music.apple.com${match.group(1)}'))
              .timeout(const Duration(seconds: 6));
          final jwtMatch =
              RegExp(r'eyJ[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+')
                  .firstMatch(jsResp.body);
          if (jwtMatch != null) {
            _appleToken = jwtMatch.group(0);
            return _appleToken;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<CanvasArtworkResult?> _fetchAppleMotionCanvas(String song, String artist) async {
    try {
      final token = await _getAppleToken();
      if (token == null || token.isEmpty) return null;

      final uri = Uri.parse('$_ampBase/v1/catalog/us/search').replace(queryParameters: {
        'term': '$song $artist',
        'types': 'albums',
        'limit': '3',
        'extend': 'editorialVideo',
      });
      final resp = await _client.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Origin': 'https://music.apple.com',
        'Referer': 'https://music.apple.com/',
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final albums = json['results']?['albums']?['data'] as List<dynamic>? ?? const [];
        for (final album in albums) {
          final ev = album['attributes']?['editorialVideo'];
          if (ev is Map<String, dynamic>) {
            final video = ev['motionDetailSquare']?['video'] ??
                ev['motionSquareVideo1x1']?['video'] ??
                ev['motionDetailTall']?['video'];
            if (video is String && video.isNotEmpty) {
              return CanvasArtworkResult(videoUrl: video, provider: 'Apple Motion');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Apple Motion Canvas error: $e');
    }
    return null;
  }

  String _clean(String raw) => raw
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'\[.*?\]'), '')
      .replaceAll(RegExp(r'official.*|lyrics.*|video.*|audio.*', caseSensitive: false), '')
      .trim();
}
