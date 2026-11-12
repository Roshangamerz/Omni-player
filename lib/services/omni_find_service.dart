import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/echo_models.dart';

/// Reverse-engineered Echo Find (ShazamKit) Audio Recognition Service
/// Captures 16kHz PCM audio via native Android AudioRecord + ShazamSignatureGenerator
/// and identifies tracks via https://amp.shazam.com/discovery/v5/
class OmniFindService extends ChangeNotifier {
  static final OmniFindService _instance = OmniFindService._internal();
  factory OmniFindService() => _instance;
  OmniFindService._internal();

  static const MethodChannel _channel = MethodChannel('com.omniplayer.music/shazam_recorder');
  static const String _historyKey = 'omni_find_recognition_history';

  static const List<String> _userAgents = [
    'Dalvik/2.1.0 (Linux; U; Android 5.0.2; VS980 4G Build/LRX22G)',
    'Dalvik/2.1.0 (Linux; U; Android 6.0.1; SM-G920F Build/MMB29K)',
    'Dalvik/2.1.0 (Linux; U; Android 5.1.1; SM-P905V Build/LMY47X)',
  ];

  static const List<String> _timezones = [
    'Asia/Kolkata',
    'America/New_York',
    'Europe/London',
    'Asia/Tokyo',
  ];

  final List<ShazamMatchResult> _history = [];
  bool _isListening = false;
  String _statusText = 'Tap to identify music playing around you';

  List<ShazamMatchResult> get history => List.unmodifiable(_history);
  bool get isListening => _isListening;
  String get statusText => _statusText;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _history
          ..clear()
          ..addAll(list.map((e) => ShazamMatchResult.fromJson(e as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<ShazamMatchResult?> recognizeFromMicrophone({int durationMs = 5500}) async {
    if (_isListening) return null;
    _isListening = true;
    _statusText = 'Listening to ambient audio...';
    notifyListeners();

    try {
      final rec = await _channel.invokeMapMethod<String, dynamic>('recordAndSign', {
        'durationMs': durationMs,
      });
      if (rec == null || rec['signature'] == null) {
        throw Exception('No audio signature captured');
      }

      _statusText = 'Matching acoustic fingerprint...';
      notifyListeners();

      final signature = rec['signature'].toString();
      final sampleMs = (rec['durationMs'] as num?)?.toInt() ?? durationMs;
      final match = await _queryShazam(signature, sampleMs);

      if (match != null) {
        _history.removeWhere(
            (m) => m.title.toLowerCase() == match.title.toLowerCase() && m.artist.toLowerCase() == match.artist.toLowerCase());
        _history.insert(0, match);
        if (_history.length > 40) _history.removeRange(40, _history.length);
        await _saveHistory();
        _statusText = 'Match found!';
      } else {
        _statusText = 'No song matched. Try moving closer to the speaker.';
      }
      return match;
    } catch (e) {
      _statusText = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> cancelListening() async {
    _isListening = false;
    _statusText = 'Tap to identify music playing around you';
    notifyListeners();
    try {
      await _channel.invokeMethod('cancelRecord');
    } catch (_) {}
  }

  Future<ShazamMatchResult?> _queryShazam(String signature, int sampleMs) async {
    final rng = Random();
    final uuid1 = _uuidV4(rng).toUpperCase();
    final uuid2 = _uuidV4(rng);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final uri = Uri.https(
      'amp.shazam.com',
      '/discovery/v5/en/US/android/-/tag/$uuid1/$uuid2',
      {
        'sync': 'true',
        'webv3': 'true',
        'sampling': 'true',
        'connected': '',
        'shazamapiversion': 'v3',
        'sharehub': 'true',
        'video': 'v3',
      },
    );

    final body = jsonEncode({
      'geolocation': {
        'altitude': rng.nextDouble() * 400 + 100,
        'latitude': rng.nextDouble() * 180 - 90,
        'longitude': rng.nextDouble() * 360 - 180,
      },
      'signature': {
        'samplems': sampleMs,
        'timestamp': timestamp,
        'uri': signature,
      },
      'timestamp': timestamp,
      'timezone': _timezones[rng.nextInt(_timezones.length)],
    });

    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': _userAgents[rng.nextInt(_userAgents.length)],
            'Content-Language': 'en_US',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final track = json['track'] as Map<String, dynamic>?;
      if (track == null) return null;

      final title = track['title']?.toString() ?? '';
      final artist = track['subtitle']?.toString() ?? 'Unknown Artist';
      if (title.isEmpty) return null;

      final images = track['images'] as Map<String, dynamic>?;
      final artwork = (images?['coverarthq'] ?? images?['coverart'] ?? images?['background'])
              ?.toString() ??
          '';
      final shazamUrl = track['url']?.toString() ?? '';
      final genre = track['genres']?['primary']?.toString() ?? '';

      String album = '';
      String year = '';
      final sections = track['sections'] as List<dynamic>? ?? const [];
      for (final sec in sections) {
        if (sec is Map<String, dynamic> && sec['type'] == 'SONG') {
          final meta = sec['metadata'] as List<dynamic>? ?? const [];
          for (final m in meta) {
            final t = m['title']?.toString() ?? '';
            if (t == 'Album') album = m['text']?.toString() ?? '';
            if (t == 'Released') year = m['text']?.toString() ?? '';
          }
        }
      }

      return ShazamMatchResult(
        title: title,
        artist: artist,
        album: album,
        artworkUrl: artwork,
        shazamUrl: shazamUrl,
        genre: genre,
        releaseYear: year,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_history.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  String _uuidV4(Random rng) {
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
