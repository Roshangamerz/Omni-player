import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import '../models/track.dart';

class LyricsFetchResult {
  final String provider;
  final List<LyricLine> lines;
  final bool hasWordSync;
  final bool isFallback;

  const LyricsFetchResult({
    required this.provider,
    required this.lines,
    this.hasWordSync = false,
    this.isFallback = false,
  });
}

/// Echo-Music Grade Multi-Provider Synced & Word-by-Word Lyrics Engine
/// Integrates BetterLyrics (TTML), YouLyPlus (6 KPoe servers), SimpMusic, Paxsenix,
/// Unison, KuGou, LRCLib, Netease, JioSaavn, plus AI Translation & Per-Song Timing Offset.
class LyricsService {
  static final Map<String, LyricsFetchResult> _cache = {};

  static const List<String> allProviders = [
    'BetterLyrics',
    'YouLyPlus',
    'SimpMusic',
    'Paxsenix',
    'Unison',
    'LRCLib',
    'KuGou',
    'Netease',
    'JioSaavn',
  ];

  static const List<String> _youlyServers = [
    'https://lyricsplus.prjktla.my.id',
    'https://lyricsplus.atomix.one',
    'https://lyricsplus.binimum.org',
    'https://lyricsplus.prjktla.workers.dev',
    'https://lyricsplus-seven.vercel.app',
    'https://lyrics-plus-backend.vercel.app',
  ];

  static String? _lastWorkingYouly;

  /// Backwards-compatible helper returning lines directly
  static Future<List<LyricLine>> getLyricsForTrack(Track track) async {
    final res = await fetchRichLyrics(track);
    return res.lines;
  }

  /// Fetch best available lyrics with provider attribution & word-sync metadata
  static Future<LyricsFetchResult> fetchRichLyrics(
    Track track, {
    String? preferredProvider,
    bool forceRefresh = false,
  }) async {
    if (track.lyrics.isNotEmpty && !forceRefresh) {
      return LyricsFetchResult(
        provider: 'Embedded',
        lines: track.lyrics,
        hasWordSync: track.lyrics.any((l) => l.words.isNotEmpty),
      );
    }

    final cacheKey =
        '${track.title.toLowerCase().trim()}|${track.artist.toLowerCase().trim()}|${preferredProvider ?? "auto"}';
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh && preferredProvider == null) {
      final savedLrc = prefs.getString('omni_lyrics_$cacheKey');
      final savedProv = prefs.getString('omni_lyrics_prov_$cacheKey') ?? 'Cached';
      if (savedLrc != null && savedLrc.isNotEmpty) {
        final parsed = Track.parseLrc(savedLrc);
        if (parsed.isNotEmpty) {
          final res = LyricsFetchResult(
            provider: savedProv,
            lines: parsed,
            hasWordSync: parsed.any((l) => l.words.isNotEmpty),
          );
          _cache[cacheKey] = res;
          return res;
        }
      }
    }

    final enabledSet = _getEnabledProviders(prefs);
    final cleanTitle = _cleanTitle(track.title);
    final cleanArtist = _cleanArtist(track.artist);
    final videoId = track.cleanVideoId;

    // If user explicitly switched provider pill in Lyrics view
    if (preferredProvider != null) {
      final direct = await _querySingleProvider(
        preferredProvider,
        track: track,
        cleanTitle: cleanTitle,
        cleanArtist: cleanArtist,
        videoId: videoId,
      );
      if (direct != null && direct.lines.isNotEmpty) {
        _cache[cacheKey] = direct;
        return direct;
      }
    }

    // Tier 1: Word-by-word & high-precision providers in parallel
    final tier1Futures = <Future<LyricsFetchResult?>>[
      if (enabledSet.contains('BetterLyrics'))
        _betterLyrics(cleanTitle, cleanArtist, track.duration, track.album),
      if (enabledSet.contains('YouLyPlus'))
        _youLyPlus(cleanTitle, cleanArtist, track.duration, track.album, videoId),
      if (enabledSet.contains('SimpMusic') && videoId.length == 11)
        _simpMusic(videoId, track.duration),
      if (enabledSet.contains('Paxsenix'))
        _paxsenix(cleanTitle, cleanArtist, track.duration),
    ];

    if (tier1Futures.isNotEmpty) {
      final t1 = await Future.wait(tier1Futures)
          .timeout(const Duration(seconds: 7), onTimeout: () => const []);
      // Prefer results with word-level sync first
      final withWord = t1.whereType<LyricsFetchResult>().where((r) => r.hasWordSync && r.lines.isNotEmpty);
      if (withWord.isNotEmpty) {
        final best = withWord.first;
        _cache[cacheKey] = best;
        _saveLyricsToDisk(cacheKey, best);
        return best;
      }
      final anyT1 = t1.whereType<LyricsFetchResult>().where((r) => r.lines.isNotEmpty);
      if (anyT1.isNotEmpty) {
        final best = anyT1.first;
        _cache[cacheKey] = best;
        _saveLyricsToDisk(cacheKey, best);
        return best;
      }
    }

    // Tier 2: Line-synced & regional providers in parallel
    final tier2Futures = <Future<LyricsFetchResult?>>[
      if (enabledSet.contains('LRCLib'))
        _lrclibGet(trackName: cleanTitle, artistName: cleanArtist, duration: track.duration),
      if (enabledSet.contains('Unison'))
        _unisonLyrics(videoId, cleanTitle, cleanArtist, track.album, track.duration),
      if (enabledSet.contains('KuGou'))
        _kugouLyrics(cleanTitle, cleanArtist, track.duration),
      if (enabledSet.contains('Netease'))
        _neteaseSearch(cleanTitle, cleanArtist),
      if (enabledSet.contains('JioSaavn'))
        _jioSaavnLyrics(cleanTitle, cleanArtist, track.duration),
      if (enabledSet.contains('LRCLib'))
        _lrclibSearch('$cleanTitle $cleanArtist', track.duration),
      _lyricsOvh(cleanTitle, cleanArtist, track.duration),
    ];

    final t2 = await Future.wait(tier2Futures)
        .timeout(const Duration(seconds: 7), onTimeout: () => const []);
    for (final res in t2) {
      if (res != null && res.lines.isNotEmpty) {
        _cache[cacheKey] = res;
        _saveLyricsToDisk(cacheKey, res);
        return res;
      }
    }

    // Tier 3: Relaxed phonetic & raw title fallback
    final transliterated = cleanTitle
        .replaceAll('oo', 'u')
        .replaceAll('ee', 'i')
        .replaceAll('aa', 'a');
    final t3 = await Future.wait([
      _lrclibSearch(track.title, track.duration),
      _neteaseSearch(transliterated, cleanArtist),
      _jioSaavnLyrics(transliterated, '', track.duration),
    ]).timeout(const Duration(seconds: 5), onTimeout: () => const []);

    for (final res in t3) {
      if (res != null && res.lines.isNotEmpty) {
        _cache[cacheKey] = res;
        _saveLyricsToDisk(cacheKey, res);
        return res;
      }
    }

    final fallback = LyricsFetchResult(
      provider: 'Instrumental / No Lyrics',
      lines: _buildFallback(track),
      isFallback: true,
    );
    _cache[cacheKey] = fallback;
    return fallback;
  }

  static Future<LyricsFetchResult?> _querySingleProvider(
    String provider, {
    required Track track,
    required String cleanTitle,
    required String cleanArtist,
    required String videoId,
  }) async {
    switch (provider) {
      case 'BetterLyrics':
        return _betterLyrics(cleanTitle, cleanArtist, track.duration, track.album);
      case 'YouLyPlus':
        return _youLyPlus(cleanTitle, cleanArtist, track.duration, track.album, videoId);
      case 'SimpMusic':
        return _simpMusic(videoId, track.duration);
      case 'Paxsenix':
        return _paxsenix(cleanTitle, cleanArtist, track.duration);
      case 'Unison':
        return _unisonLyrics(videoId, cleanTitle, cleanArtist, track.album, track.duration);
      case 'KuGou':
        return _kugouLyrics(cleanTitle, cleanArtist, track.duration);
      case 'LRCLib':
        return await _lrclibGet(
                trackName: cleanTitle, artistName: cleanArtist, duration: track.duration) ??
            await _lrclibSearch('$cleanTitle $cleanArtist', track.duration);
      case 'Netease':
        return _neteaseSearch(cleanTitle, cleanArtist);
      case 'JioSaavn':
        return _jioSaavnLyrics(cleanTitle, cleanArtist, track.duration);
      default:
        return null;
    }
  }

  static Set<String> _getEnabledProviders(SharedPreferences prefs) {
    final disabled = prefs.getStringList('omni_disabled_lyrics_providers') ?? const [];
    return allProviders.where((p) => !disabled.contains(p)).toSet();
  }

  static Future<List<String>> getDisabledProviders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('omni_disabled_lyrics_providers') ?? const [];
  }

  static Future<void> setProviderEnabled(String provider, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final disabled = (prefs.getStringList('omni_disabled_lyrics_providers') ?? const []).toList();
    if (enabled) {
      disabled.remove(provider);
    } else if (!disabled.contains(provider)) {
      disabled.add(provider);
    }
    await prefs.setStringList('omni_disabled_lyrics_providers', disabled);
  }

  static Future<int> getTrackOffsetMs(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('omni_lyric_offset_$trackId') ?? 0;
  }

  static Future<void> setTrackOffsetMs(String trackId, int offsetMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('omni_lyric_offset_$trackId', offsetMs);
  }

  static String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'feat\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'ft\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'lyrics', caseSensitive: false), '')
        .replaceAll(RegExp(r'official.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'video', caseSensitive: false), '')
        .replaceAll(RegExp(r'audio', caseSensitive: false), '')
        .replaceAll(RegExp(r'from\s+".*?"', caseSensitive: false), '')
        .replaceAll(RegExp(r'from\s+.*', caseSensitive: false), '')
        .trim();
  }

  static String _cleanArtist(String raw) {
    return raw
        .split(RegExp(r'[,&x/•]'))
        .first
        .replaceAll(RegExp(r'feat\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'ft\..*', caseSensitive: false), '')
        .trim();
  }

  // ─── 1. BETTERLYRICS (TTML WORD-BY-WORD) ────────────────────────────────────
  static Future<LyricsFetchResult?> _betterLyrics(
    String title,
    String artist,
    Duration duration,
    String album,
  ) async {
    if (title.isEmpty || artist.isEmpty) return null;
    try {
      final uri = Uri.https('lyrics-api.boidu.dev', '/getLyrics', {
        's': title,
        'a': artist,
        if (duration.inSeconds > 0) 'd': duration.inSeconds.toString(),
        if (album.isNotEmpty) 'al': album,
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final ttml = json['ttml']?.toString() ?? '';
        if (ttml.isNotEmpty) {
          final lines = _parseTtml(ttml);
          if (lines.isNotEmpty) {
            return LyricsFetchResult(
              provider: 'BetterLyrics',
              lines: lines,
              hasWordSync: lines.any((l) => l.words.isNotEmpty),
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 2. YOULYPLUS / LYRICSPLUS (6 KPOE SERVERS) ────────────────────────────
  static Future<LyricsFetchResult?> _youLyPlus(
    String title,
    String artist,
    Duration duration,
    String album,
    String videoId,
  ) async {
    if (title.isEmpty || artist.isEmpty) return null;
    final servers = [
      if (_lastWorkingYouly != null) _lastWorkingYouly!,
      ..._youlyServers.where((s) => s != _lastWorkingYouly),
    ];

    for (final base in servers) {
      try {
        final uri = Uri.parse(base).replace(path: '/v2/lyrics/get', queryParameters: {
          'title': title,
          'artist': artist,
          if (duration.inSeconds > 0) 'duration': duration.inSeconds.toString(),
          if (album.isNotEmpty) 'album': album,
          if (videoId.length == 11) 'id': videoId,
        });
        final resp = await http.get(uri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final lyricsArr = data['lyrics'] as List<dynamic>?;
          if (lyricsArr != null && lyricsArr.isNotEmpty) {
            final lines = <LyricLine>[];
            for (final item in lyricsArr) {
              if (item is! Map<String, dynamic>) continue;
              final timeMs = (item['time'] as num?)?.toInt() ?? 0;
              final text = item['text']?.toString().trim() ?? '';
              final syllabus = item['syllabus'] as List<dynamic>?;
              final words = <LyricWord>[];
              bool isBg = false;
              if (syllabus != null && syllabus.isNotEmpty) {
                final buf = StringBuffer();
                var curWord = StringBuffer();
                int wordStart = timeMs;
                int wordEnd = timeMs + 300;
                for (final syl in syllabus) {
                  if (syl is! Map<String, dynamic>) continue;
                  if (syl['isBackground'] == true) isBg = true;
                  final st = syl['text']?.toString() ?? '';
                  final sTime = (syl['time'] as num?)?.toInt() ?? wordStart;
                  final sDur = (syl['duration'] as num?)?.toInt() ?? 250;
                  buf.write(st);
                  if (st.startsWith(' ') && curWord.isNotEmpty) {
                    words.add(LyricWord(
                      start: Duration(milliseconds: wordStart),
                      end: Duration(milliseconds: wordEnd),
                      text: curWord.toString().trim(),
                    ));
                    curWord.clear();
                    wordStart = sTime;
                  }
                  if (curWord.isEmpty) wordStart = sTime;
                  curWord.write(st);
                  wordEnd = sTime + sDur;
                  if (st.endsWith(' ')) {
                    words.add(LyricWord(
                      start: Duration(milliseconds: wordStart),
                      end: Duration(milliseconds: wordEnd),
                      text: curWord.toString().trim(),
                    ));
                    curWord.clear();
                  }
                }
                if (curWord.isNotEmpty) {
                  words.add(LyricWord(
                    start: Duration(milliseconds: wordStart),
                    end: Duration(milliseconds: wordEnd),
                    text: curWord.toString().trim(),
                  ));
                }
                final lineTxt = text.isNotEmpty ? text : buf.toString().trim();
                if (lineTxt.isNotEmpty) {
                  lines.add(LyricLine(
                    time: Duration(milliseconds: timeMs),
                    text: lineTxt,
                    words: words,
                    isBackground: isBg,
                  ));
                }
              } else if (text.isNotEmpty) {
                lines.add(LyricLine(time: Duration(milliseconds: timeMs), text: text));
              }
            }
            if (lines.isNotEmpty) {
              _lastWorkingYouly = base;
              return LyricsFetchResult(
                provider: 'YouLyPlus',
                lines: lines,
                hasWordSync: lines.any((l) => l.words.isNotEmpty),
              );
            }
          }
          final synced = data['syncedLyrics']?.toString() ?? '';
          if (synced.isNotEmpty) {
            final parsed = Track.parseLrc(synced);
            if (parsed.isNotEmpty) {
              _lastWorkingYouly = base;
              return LyricsFetchResult(
                provider: 'YouLyPlus',
                lines: parsed,
                hasWordSync: parsed.any((l) => l.words.isNotEmpty),
              );
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ─── 3. SIMPMUSIC LYRICS API ────────────────────────────────────────────────
  static Future<LyricsFetchResult?> _simpMusic(String videoId, Duration duration) async {
    if (videoId.isEmpty) return null;
    for (final base in [
      'https://api-lyrics.simpmusic.org/v1/',
      'https://vivi-yt-music-server.onrender.com/v1/',
    ]) {
      try {
        final resp = await http.get(
          Uri.parse('$base$videoId'),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'SimpMusicLyrics/1.0',
          },
        ).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          if (json['success'] == true && json['data'] is List) {
            final tracks = json['data'] as List<dynamic>;
            if (tracks.isEmpty) continue;
            final targetSec = duration.inSeconds;
            tracks.sort((a, b) {
              final da = ((a['duration'] as num?)?.toInt() ?? targetSec) - targetSec;
              final db = ((b['duration'] as num?)?.toInt() ?? targetSec) - targetSec;
              return da.abs().compareTo(db.abs());
            });
            final best = tracks.first as Map<String, dynamic>;
            final rich = best['richSyncLyrics']?.toString() ?? '';
            final synced = best['syncedLyrics']?.toString() ?? '';
            final plain = best['plainLyrics']?.toString() ?? '';
            final raw = rich.isNotEmpty ? rich : synced;
            if (raw.isNotEmpty) {
              final parsed = Track.parseLrc(raw);
              if (parsed.isNotEmpty) {
                return LyricsFetchResult(
                  provider: 'SimpMusic',
                  lines: parsed,
                  hasWordSync: parsed.any((l) => l.words.isNotEmpty),
                );
              }
            }
            if (plain.isNotEmpty) {
              return LyricsFetchResult(
                provider: 'SimpMusic',
                lines: _distributeLines(plain, duration),
              );
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ─── 4. PAXSENIX APPLE-MUSIC WORD-SYNCED LYRICS ─────────────────────────────
  static Future<LyricsFetchResult?> _paxsenix(
    String title,
    String artist,
    Duration duration,
  ) async {
    if (title.isEmpty) return null;
    try {
      final searchUri = Uri.https('lyrics.paxsenix.org', '/apple-music/search', {
        'q': '$title $artist'.trim(),
      });
      final sResp = await http
          .get(searchUri, headers: {'User-Agent': 'omniplayer/2.5'})
          .timeout(const Duration(seconds: 4));
      if (sResp.statusCode != 200) return null;
      final results = jsonDecode(sResp.body);
      if (results is! List || results.isEmpty) return null;

      final firstId = results.first['id']?.toString();
      if (firstId == null || firstId.isEmpty) return null;

      final lUri = Uri.https('lyrics.paxsenix.org', '/apple-music/lyrics', {'id': firstId});
      final lResp = await http
          .get(lUri, headers: {'User-Agent': 'omniplayer/2.5'})
          .timeout(const Duration(seconds: 5));
      if (lResp.statusCode != 200) return null;
      final data = jsonDecode(lResp.body) as Map<String, dynamic>;

      final ttml = data['ttmlContent']?.toString() ?? '';
      if (ttml.isNotEmpty) {
        final parsed = _parseTtml(ttml);
        if (parsed.isNotEmpty) {
          return LyricsFetchResult(
            provider: 'Paxsenix',
            lines: parsed,
            hasWordSync: parsed.any((l) => l.words.isNotEmpty),
          );
        }
      }
      final elrc = (data['elrcMultiPerson'] ?? data['elrc'])?.toString() ?? '';
      if (elrc.isNotEmpty) {
        final parsed = Track.parseLrc(elrc);
        if (parsed.isNotEmpty) {
          return LyricsFetchResult(
            provider: 'Paxsenix',
            lines: parsed,
            hasWordSync: parsed.any((l) => l.words.isNotEmpty),
          );
        }
      }
      final content = data['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        final lines = <LyricLine>[];
        for (final item in content) {
          if (item is! Map<String, dynamic>) continue;
          final ts = (item['timestamp'] as num?)?.toInt() ?? 0;
          final wordItems = item['text'] as List<dynamic>? ?? const [];
          final words = <LyricWord>[];
          final buf = StringBuffer();
          for (final w in wordItems) {
            if (w is Map<String, dynamic>) {
              final wt = w['text']?.toString().trim() ?? '';
              if (wt.isEmpty) continue;
              if (buf.isNotEmpty) buf.write(' ');
              buf.write(wt);
              final wStart = (w['timestamp'] as num?)?.toInt() ?? ts;
              final wEnd = (w['endtime'] as num?)?.toInt() ?? (wStart + 350);
              words.add(LyricWord(
                start: Duration(milliseconds: wStart),
                end: Duration(milliseconds: wEnd),
                text: wt,
              ));
            }
          }
          if (buf.isNotEmpty) {
            lines.add(LyricLine(
              time: Duration(milliseconds: ts),
              text: buf.toString(),
              words: words,
              isBackground: item['background'] == true,
            ));
          }
        }
        if (lines.isNotEmpty) {
          return LyricsFetchResult(
            provider: 'Paxsenix',
            lines: lines,
            hasWordSync: lines.any((l) => l.words.isNotEmpty),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 5. UNISON LYRICS API ───────────────────────────────────────────────────
  static Future<LyricsFetchResult?> _unisonLyrics(
    String videoId,
    String title,
    String artist,
    String album,
    Duration duration,
  ) async {
    try {
      Uri uri;
      if (videoId.length == 11) {
        uri = Uri.https('unison.boidu.dev', '/lyrics', {'v': videoId});
      } else {
        uri = Uri.https('unison.boidu.dev', '/lyrics', {
          'song': title,
          'artist': artist,
          if (album.isNotEmpty) 'album': album,
          if (duration.inSeconds > 0) 'duration': duration.inSeconds.toString(),
        });
      }
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          final lrc = json['data']?['lyrics']?.toString() ?? '';
          if (lrc.isNotEmpty) {
            final parsed = Track.parseLrc(lrc);
            if (parsed.isNotEmpty) {
              return LyricsFetchResult(
                provider: 'Unison',
                lines: parsed,
                hasWordSync: parsed.any((l) => l.words.isNotEmpty),
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 6. KUGOU LYRICS API ────────────────────────────────────────────────────
  static Future<LyricsFetchResult?> _kugouLyrics(
    String title,
    String artist,
    Duration duration,
  ) async {
    if (title.isEmpty) return null;
    try {
      final keyword = '$title - $artist'.trim();
      final sUri = Uri.https('lyrics.kugou.com', '/search', {
        'ver': '1',
        'man': 'yes',
        'client': 'pc',
        if (duration.inSeconds > 0) 'duration': (duration.inSeconds * 1000).toString(),
        'keyword': keyword,
      });
      final sResp = await http.get(sUri).timeout(const Duration(seconds: 4));
      if (sResp.statusCode != 200) return null;
      final sJson = jsonDecode(sResp.body) as Map<String, dynamic>;
      final candidates = sJson['candidates'] as List<dynamic>? ?? const [];
      if (candidates.isEmpty) return null;

      final first = candidates.first as Map<String, dynamic>;
      final id = first['id']?.toString() ?? '';
      final accesskey = first['accesskey']?.toString() ?? '';
      if (id.isEmpty || accesskey.isEmpty) return null;

      final dUri = Uri.https('lyrics.kugou.com', '/download', {
        'fmt': 'lrc',
        'charset': 'utf8',
        'client': 'pc',
        'ver': '1',
        'id': id,
        'accesskey': accesskey,
      });
      final dResp = await http.get(dUri).timeout(const Duration(seconds: 4));
      if (dResp.statusCode != 200) return null;
      final dJson = jsonDecode(dResp.body) as Map<String, dynamic>;
      final b64 = dJson['content']?.toString() ?? '';
      if (b64.isEmpty) return null;
      final lrc = utf8.decode(base64Decode(b64), allowMalformed: true);
      final parsed = Track.parseLrc(lrc);
      if (parsed.isNotEmpty) {
        return LyricsFetchResult(provider: 'KuGou', lines: parsed);
      }
    } catch (_) {}
    return null;
  }

  // ─── 7. LRCLIB ──────────────────────────────────────────────────────────────
  static Future<LyricsFetchResult?> _lrclibGet({
    required String trackName,
    required String artistName,
    required Duration duration,
  }) async {
    if (trackName.isEmpty) return null;
    try {
      final params = {
        'track_name': trackName,
        'artist_name': artistName,
        if (duration.inSeconds > 0) 'duration': duration.inSeconds.toString(),
      };
      final url = Uri.https('lrclib.net', '/api/get', params);
      final res = await http.get(url, headers: {
        'User-Agent': 'OmniPlayer/3.0 (Android; Hi-Fi)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final synced = data['syncedLyrics']?.toString() ?? '';
        if (synced.isNotEmpty) {
          final parsed = Track.parseLrc(synced);
          if (parsed.isNotEmpty) return LyricsFetchResult(provider: 'LRCLib', lines: parsed);
        }
        final plain = data['plainLyrics']?.toString() ?? '';
        if (plain.isNotEmpty) {
          return LyricsFetchResult(provider: 'LRCLib', lines: _distributeLines(plain, duration));
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<LyricsFetchResult?> _lrclibSearch(String query, Duration trackDuration) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;
    try {
      final url = Uri.https('lrclib.net', '/api/search', {'q': clean});
      final res = await http.get(url, headers: {
        'User-Agent': 'OmniPlayer/3.0 (Android; Hi-Fi)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty) {
          String bestSynced = '';
          String bestPlain = '';
          int bestDiff = 999999;

          for (final item in data) {
            final itemDur = (item['duration'] as num?)?.toInt() ?? 0;
            final diff = (itemDur - trackDuration.inSeconds).abs();
            final synced = item['syncedLyrics']?.toString() ?? '';
            final plain = item['plainLyrics']?.toString() ?? '';

            if (synced.isNotEmpty && diff < bestDiff) {
              bestDiff = diff;
              bestSynced = synced;
              bestPlain = plain;
            } else if (synced.isEmpty && plain.isNotEmpty && bestSynced.isEmpty && diff < bestDiff) {
              bestDiff = diff;
              bestPlain = plain;
            }
          }

          if (bestSynced.isNotEmpty) {
            final parsed = Track.parseLrc(bestSynced);
            if (parsed.isNotEmpty) return LyricsFetchResult(provider: 'LRCLib', lines: parsed);
          }
          if (bestPlain.isNotEmpty) {
            return LyricsFetchResult(
                provider: 'LRCLib', lines: _distributeLines(bestPlain, trackDuration));
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 8. NETEASE, JIOSAAVN & LYRICS.OVH ──────────────────────────────────────
  static Future<LyricsFetchResult?> _neteaseSearch(String title, String artist) async {
    final q = '$title $artist'.trim();
    if (q.isEmpty) return null;
    try {
      final searchUrl = Uri.parse(
          'https://music.163.com/api/search/get/web?s=${Uri.encodeComponent(q)}&type=1&offset=0&total=true&limit=3');
      final sRes = await http.get(searchUrl, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 3));

      if (sRes.statusCode == 200) {
        final sData = jsonDecode(sRes.body);
        final songs = sData['result']?['songs'] as List<dynamic>? ?? [];
        if (songs.isNotEmpty) {
          final songId = songs.first['id'];
          final lyricUrl =
              Uri.parse('https://music.163.com/api/song/lyric?os=pc&id=$songId&lv=-1&kv=-1&tv=-1');
          final lRes = await http.get(lyricUrl).timeout(const Duration(seconds: 3));
          if (lRes.statusCode == 200) {
            final lData = jsonDecode(lRes.body);
            final lrc = lData['lrc']?['lyric']?.toString() ?? '';
            if (lrc.isNotEmpty) {
              final parsed = Track.parseLrc(lrc);
              if (parsed.isNotEmpty) return LyricsFetchResult(provider: 'Netease', lines: parsed);
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<LyricsFetchResult?> _jioSaavnLyrics(
      String title, String artist, Duration duration) async {
    final q = '$title $artist'.trim();
    if (q.isEmpty) return null;
    try {
      final searchUrl = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=search.getResults&q=${Uri.encodeComponent(q)}&_format=json&_marker=0&ctx=android&n=5&p=1');
      final res = await http.get(searchUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List<dynamic>? ?? [];
        for (final item in results) {
          final songId = item['id']?.toString();
          if (songId != null && (item['has_lyrics'] == 'true' || item['has_lyrics'] == true)) {
            final lyricUrl = Uri.parse(
                'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$songId&ctx=android&_format=json');
            final lRes = await http.get(lyricUrl).timeout(const Duration(seconds: 4));
            if (lRes.statusCode == 200) {
              final lData = jsonDecode(lRes.body);
              final raw = lData['lyrics']?.toString() ?? '';
              if (raw.isNotEmpty) {
                final cleanLyrics =
                    raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
                return LyricsFetchResult(
                  provider: 'JioSaavn',
                  lines: _distributeLines(cleanLyrics, duration),
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<LyricsFetchResult?> _lyricsOvh(
      String title, String artist, Duration duration) async {
    if (title.isEmpty || artist.isEmpty) return null;
    try {
      final url = Uri.parse(
          'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}');
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lyrics = data['lyrics']?.toString() ?? '';
        if (lyrics.isNotEmpty) {
          return LyricsFetchResult(
            provider: 'Lyrics.ovh',
            lines: _distributeLines(lyrics, duration),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── TTML PARSER (BetterLyrics & Apple Music TTML) ─────────────────────────
  static List<LyricLine> _parseTtml(String ttml) {
    try {
      final doc = XmlDocument.parse(ttml);
      final lines = <LyricLine>[];

      for (final p in doc.findAllElements('p')) {
        final beginAttr = p.getAttribute('begin');
        if (beginAttr == null || beginAttr.isEmpty) continue;
        final lineStart = _parseTtmlTime(beginAttr);
        final agent = _getAttrByLocalName(p, 'agent');

        final words = <LyricWord>[];
        final textBuf = StringBuffer();

        for (final node in p.children) {
          if (node is XmlElement && node.name.local == 'span') {
            final role = _getAttrByLocalName(node, 'role');
            if (role == 'x-translation' || role == 'x-roman') continue;
            if (role == 'x-bg') {
              // Background vocal
              final bgText = node.innerText.trim();
              final bgBegin = node.getAttribute('begin');
              if (bgText.isNotEmpty) {
                lines.add(LyricLine(
                  time: bgBegin != null ? _parseTtmlTime(bgBegin) : lineStart,
                  text: bgText,
                  isBackground: true,
                  agent: agent,
                ));
              }
              continue;
            }
            final wText = node.innerText.trim();
            final wb = node.getAttribute('begin');
            final we = node.getAttribute('end');
            if (wText.isNotEmpty && wb != null && we != null) {
              if (textBuf.isNotEmpty) textBuf.write(' ');
              textBuf.write(wText);
              words.add(LyricWord(
                start: _parseTtmlTime(wb),
                end: _parseTtmlTime(we),
                text: wText,
              ));
            }
          }
        }

        final finalText =
            textBuf.isNotEmpty ? textBuf.toString().trim() : p.innerText.trim();
        if (finalText.isNotEmpty) {
          lines.add(LyricLine(
            time: lineStart,
            text: finalText,
            words: words,
            agent: agent,
          ));
        }
      }

      lines.sort((a, b) => a.time.compareTo(b.time));
      return lines;
    } catch (e) {
      debugPrint('TTML parse error: $e');
      return const [];
    }
  }

  static String? _getAttrByLocalName(XmlElement el, String localName) {
    for (final attr in el.attributes) {
      if (attr.name.local == localName) return attr.value;
    }
    return null;
  }

  static Duration _parseTtmlTime(String raw) {
    final clean = raw.trim();
    if (clean.endsWith('s')) {
      final sec = double.tryParse(clean.substring(0, clean.length - 1)) ?? 0.0;
      return Duration(milliseconds: (sec * 1000).round());
    }
    final parts = clean.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = double.tryParse(parts[2]) ?? 0.0;
      return Duration(milliseconds: ((h * 3600 + m * 60 + s) * 1000).round());
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = double.tryParse(parts[1]) ?? 0.0;
      return Duration(milliseconds: ((m * 60 + s) * 1000).round());
    }
    final s = double.tryParse(clean) ?? 0.0;
    return Duration(milliseconds: (s * 1000).round());
  }

  // ─── AI / GOOGLE TRANSLATION OF LYRICS ──────────────────────────────────────
  static Future<List<LyricLine>> translateLyrics(
    List<LyricLine> lines, {
    String targetLang = 'en',
  }) async {
    if (lines.isEmpty) return lines;
    final prefs = await SharedPreferences.getInstance();
    final aiEndpoint = prefs.getString('omni_ai_endpoint') ?? '';
    final aiKey = prefs.getString('omni_ai_key') ?? '';
    final aiModel = prefs.getString('omni_ai_model') ?? 'gpt-4o-mini';

    // If user configured an AI API Key in AI Settings (OpenRouter, OpenAI, Gemini, Groq, API Route)
    if (aiKey.isNotEmpty && aiEndpoint.isNotEmpty) {
      try {
        final numbered = [
          for (int i = 0; i < lines.length; i++) '$i: ${lines[i].text}',
        ].join('\n');
        final resp = await http
            .post(
              Uri.parse(aiEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $aiKey',
              },
              body: jsonEncode({
                'model': aiModel,
                'messages': [
                  {
                    'role': 'system',
                    'content':
                        'Translate each numbered lyric line naturally into $targetLang. Return ONLY lines formatted as "index: translated text", preserving every index.',
                  },
                  {'role': 'user', 'content': numbered},
                ],
                'temperature': 0.2,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body);
          final content = json['choices']?[0]?['message']?['content']?.toString() ?? '';
          if (content.isNotEmpty) {
            final map = <int, String>{};
            for (final line in content.split('\n')) {
              final idx = line.indexOf(':');
              if (idx > 0) {
                final k = int.tryParse(line.substring(0, idx).trim());
                final v = line.substring(idx + 1).trim();
                if (k != null && v.isNotEmpty) map[k] = v;
              }
            }
            if (map.isNotEmpty) {
              return [
                for (int i = 0; i < lines.length; i++)
                  lines[i].copyWith(translation: map[i] ?? lines[i].translation),
              ];
            }
          }
        }
      } catch (e) {
        debugPrint('AI translate fallback to Google Translate: $e');
      }
    }

    // Free built-in Google Translate GTX fallback (zero key required!)
    try {
      final joined = lines.map((l) => l.text).join('\n');
      final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLang,
        'dt': 't',
        'q': joined,
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final translatedFull = (decoded[0] as List)
              .map((seg) => seg is List && seg.isNotEmpty ? seg[0].toString() : '')
              .join();
          final splitLines = translatedFull.split('\n');
          return [
            for (int i = 0; i < lines.length; i++)
              lines[i].copyWith(
                translation: i < splitLines.length ? splitLines[i].trim() : null,
              ),
          ];
        }
      }
    } catch (e) {
      debugPrint('Google Translate error: $e');
    }
    return lines;
  }

  static Future<void> _saveLyricsToDisk(String cacheKey, LyricsFetchResult res) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lrcString = res.lines.map((l) {
        final m = l.time.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = l.time.inSeconds.remainder(60).toString().padLeft(2, '0');
        final ms = (l.time.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
        return '[$m:$s.$ms]${l.text}';
      }).join('\n');
      await prefs.setString('omni_lyrics_$cacheKey', lrcString);
      await prefs.setString('omni_lyrics_prov_$cacheKey', res.provider);
    } catch (_) {}
  }

  static List<LyricLine> _distributeLines(String plain, Duration duration) {
    final rawLines = plain.split('\n').map((l) => l.trim()).toList();
    if (rawLines.isEmpty) return [];

    final cleanedLines = <String>[];
    for (final l in rawLines) {
      if (l.isEmpty) {
        if (cleanedLines.isNotEmpty && cleanedLines.last != '♪  •  •  •  ♪') {
          cleanedLines.add('♪  •  •  •  ♪');
        }
      } else if (!l.startsWith('[') && !l.startsWith('{')) {
        cleanedLines.add(l);
      }
    }

    if (cleanedLines.isEmpty) return [];

    final durMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 190000;
    const introMs = 12000;
    const outroMs = 10000;
    final singingDurMs = (durMs - introMs - outroMs).clamp(30000, durMs);

    final weights = cleanedLines.map((l) {
      if (l == '♪  •  •  •  ♪') return 2.5;
      final words = l.split(RegExp(r'\s+')).length;
      return (words * 0.8 + 1.5).clamp(2.0, 7.0);
    }).toList();

    final totalWeight = weights.fold<double>(0.0, (sum, w) => sum + w);
    final msPerWeight = singingDurMs / (totalWeight > 0 ? totalWeight : 1.0);

    double currentMs = introMs.toDouble();
    final result = <LyricLine>[];

    for (int i = 0; i < cleanedLines.length; i++) {
      result.add(LyricLine(
        time: Duration(milliseconds: currentMs.toInt()),
        text: cleanedLines[i],
      ));
      currentMs += weights[i] * msPerWeight;
    }

    return result;
  }

  static List<LyricLine> _buildFallback(Track track) {
    final lines = [
      '✨ Omni Player • Studio Master Audio',
      '♪ "${track.title}" — ${track.artist} ♪',
      '♪ [Instrumental & Melodic Passage] ♪',
      '♪ No synced lyrics available for this track yet ♪',
      '♪ Tap the Provider pill above to try another source ♪',
    ];
    final totalMs = track.duration.inMilliseconds > 0 ? track.duration.inMilliseconds : 180000;
    final step = totalMs ~/ (lines.length + 1);
    return [
      for (int i = 0; i < lines.length; i++)
        LyricLine(time: Duration(milliseconds: (i + 1) * step), text: lines[i])
    ];
  }
}
