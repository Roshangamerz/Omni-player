import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/echo_models.dart';

/// Reverse-engineered Echo Music "Music DNA" Service
/// Queries Genius API for song/album/artist metadata and Wikipedia API for backstory & bio.
class MusicDnaService {
  static final MusicDnaService _instance = MusicDnaService._internal();
  factory MusicDnaService() => _instance;
  MusicDnaService._internal();

  final Map<String, MusicDnaInfo> _cache = {};

  Future<MusicDnaInfo> fetchMusicDna({
    required String title,
    required String artist,
    String album = '',
  }) async {
    final cleanTitle = title
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
    final cleanArtist = artist.split(RegExp(r'[,&•]')).first.trim();
    final key = '${cleanTitle.toLowerCase()}|${cleanArtist.toLowerCase()}';
    if (_cache.containsKey(key)) return _cache[key]!;

    String resolvedAlbum = album.isNotEmpty ? album : 'Single / Unknown';
    String aboutSong = 'No editorial story found for this track.';
    String artistBio = 'No artist biography found.';
    String? geniusUrl;

    try {
      // 1. Genius Multi-Search
      final query = Uri.encodeComponent('$cleanArtist $cleanTitle');
      final searchResp = await http
          .get(Uri.parse('https://genius.com/api/search/multi?q=$query'))
          .timeout(const Duration(seconds: 6));

      int songId = -1;
      if (searchResp.statusCode == 200) {
        final root = jsonDecode(searchResp.body);
        final sections = root['response']?['sections'] as List<dynamic>? ?? const [];
        for (final sec in sections) {
          final type = sec['type']?.toString() ?? '';
          if (type == 'top_hit' || type == 'song') {
            final hits = sec['hits'] as List<dynamic>? ?? const [];
            if (hits.isNotEmpty) {
              final result = hits.first['result'];
              if (result is Map<String, dynamic>) {
                songId = (result['id'] as num?)?.toInt() ?? -1;
                geniusUrl = result['url']?.toString();
                break;
              }
            }
          }
        }
      }

      if (songId != -1) {
        final songResp = await http
            .get(Uri.parse('https://genius.com/api/songs/$songId?text_format=plain'))
            .timeout(const Duration(seconds: 6));
        if (songResp.statusCode == 200) {
          final songObj = jsonDecode(songResp.body)['response']?['song'];
          if (songObj is Map<String, dynamic>) {
            final gAlbum = songObj['album']?['name']?.toString();
            if (gAlbum != null && gAlbum.isNotEmpty) resolvedAlbum = gAlbum;
            final desc = songObj['description']?['plain']?.toString().trim() ?? '';
            if (desc.isNotEmpty && desc != '?') aboutSong = desc;

            final artistId = (songObj['primary_artist']?['id'] as num?)?.toInt() ?? -1;
            if (artistId != -1) {
              final artResp = await http
                  .get(Uri.parse('https://genius.com/api/artists/$artistId?text_format=plain'))
                  .timeout(const Duration(seconds: 6));
              if (artResp.statusCode == 200) {
                final artDesc =
                    jsonDecode(artResp.body)['response']?['artist']?['description']?['plain']
                            ?.toString()
                            .trim() ??
                        '';
                if (artDesc.isNotEmpty && artDesc != '?') artistBio = artDesc;
              }
            }
          }
        }
      }

      // 2. Wikipedia fallback for Track Story
      if (aboutSong.startsWith('No editorial')) {
        final wpExtract = await _fetchWikipediaExtract('$cleanTitle $cleanArtist song');
        if (wpExtract != null && wpExtract.isNotEmpty) {
          aboutSong = wpExtract;
        }
      }

      // 3. Wikipedia fallback for Artist Bio
      if (artistBio.startsWith('No artist') && cleanArtist.isNotEmpty) {
        final wpArt = await _fetchWikipediaExtract('$cleanArtist musician singer');
        if (wpArt != null && wpArt.isNotEmpty) {
          artistBio = wpArt;
        }
      }
    } catch (e) {
      debugPrint('Music DNA fetch error: $e');
    }

    final info = MusicDnaInfo(
      title: cleanTitle,
      artist: cleanArtist,
      album: resolvedAlbum,
      aboutSong: aboutSong,
      artistBio: artistBio,
      geniusUrl: geniusUrl,
    );
    _cache[key] = info;
    return info;
  }

  Future<String?> _fetchWikipediaExtract(String query) async {
    try {
      final sUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'utf8': '',
        'format': 'json',
      });
      final sResp = await http.get(sUri).timeout(const Duration(seconds: 5));
      if (sResp.statusCode != 200) return null;
      final list = jsonDecode(sResp.body)['query']?['search'] as List<dynamic>? ?? const [];
      if (list.isEmpty) return null;

      final wpTitle = list.first['title']?.toString() ?? '';
      if (wpTitle.isEmpty) return null;

      final eUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'prop': 'extracts',
        'exsentences': '4',
        'exlimit': '1',
        'titles': wpTitle,
        'explaintext': '1',
        'format': 'json',
      });
      final eResp = await http.get(eUri).timeout(const Duration(seconds: 5));
      if (eResp.statusCode != 200) return null;
      final pages = jsonDecode(eResp.body)['query']?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;
      final extract = pages.values.first['extract']?.toString().trim() ?? '';
      if (extract.isNotEmpty && !extract.contains('may refer to')) {
        return extract;
      }
    } catch (_) {}
    return null;
  }
}
