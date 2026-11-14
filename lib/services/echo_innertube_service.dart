import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/echo_models.dart';
import '../models/track.dart';
import 'innertube_service.dart';

/// Reverse-engineered YouTube Music InnerTube (WEB_REMIX / ANDROID_VR / IOS) + Apple Music RSS Client
/// Mirrors Echo Music's :innertube module and AppleMusicScraper.
class EchoInnerTubeService {
  static final EchoInnerTubeService _instance = EchoInnerTubeService._internal();
  factory EchoInnerTubeService() => _instance;
  EchoInnerTubeService._internal();

  /// Minimum song duration in seconds (removes shorts, intros, previews, ringtones under 40s)
  static const int minSongDurationSeconds = 40;

  static const String _ytmApiBase = 'https://music.youtube.com/youtubei/v1/';
  static const String _ytmOrigin = 'https://music.youtube.com';
  static const String _webRemixVersion = '1.20260213.01.00';
  static const String _webUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0';

  final http.Client _client = http.Client();
  String _regionCode = 'IN';
  String _languageCode = 'en';
  String? _visitorData;

  String get regionCode => _regionCode;
  set regionCode(String value) {
    if (value.trim().length == 2) {
      _regionCode = value.trim().toUpperCase();
    }
  }

  Map<String, dynamic> _webRemixContext() => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': _webRemixVersion,
          'gl': _regionCode,
          'hl': _languageCode,
          if (_visitorData != null) 'visitorData': _visitorData,
        }
      };

  Map<String, String> _webRemixHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': _webUserAgent,
        'X-Goog-Api-Format-Version': '1',
        'X-YouTube-Client-Name': '67',
        'X-YouTube-Client-Version': _webRemixVersion,
        'X-Origin': _ytmOrigin,
        'Referer': '$_ytmOrigin/',
        if (_visitorData != null) 'X-Goog-Visitor-Id': _visitorData!,
      };

  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 9),
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$_ytmApiBase$endpoint?prettyPrint=false'),
            headers: _webRemixHeaders(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          final vd = decoded['responseContext']?['visitorData']?.toString();
          if (vd != null && vd.isNotEmpty) _visitorData = vd;
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('InnerTube $endpoint error: $e');
    }
    return null;
  }

  // ─── 1. HOME FEED (FEmusic_home) ────────────────────────────────────────────
  Future<EchoHomeFeed> getHomeFeed({String? params}) async {
    final data = await _post('browse', {
      'context': _webRemixContext(),
      'browseId': 'FEmusic_home',
      if (params != null && params.isNotEmpty) 'params': params,
    });
    if (data == null) return const EchoHomeFeed();

    final tabContent = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]
        ?['tabRenderer']?['content']?['sectionListRenderer'];
    if (tabContent is! Map<String, dynamic>) return const EchoHomeFeed();

    final chips = <EchoMoodChip>[];
    final chipItems = tabContent['header']?['chipCloudRenderer']?['chips'];
    if (chipItems is List) {
      for (final c in chipItems) {
        final renderer = c['chipCloudChipRenderer'];
        if (renderer is Map<String, dynamic>) {
          final title = _extractRunsText(renderer['text']);
          final ep = renderer['navigationEndpoint']?['browseEndpoint'];
          if (title.isNotEmpty && ep is Map<String, dynamic>) {
            chips.add(EchoMoodChip(
              title: title,
              browseId: ep['browseId']?.toString(),
              params: ep['params']?.toString(),
            ));
          }
        }
      }
    }

    final sections = <EchoHomeSection>[];
    final contents = tabContent['contents'];
    if (contents is List) {
      for (final item in contents) {
        final carousel = item['musicCarouselShelfRenderer'];
        if (carousel is Map<String, dynamic>) {
          final parsed = _parseCarouselSection(carousel);
          if (parsed != null) sections.add(parsed);
        }
      }
    }

    return EchoHomeFeed(chips: chips, sections: sections);
  }

  // ─── 2. EXPLORE PAGE (New Releases, Moods & Genres, Charts) ─────────────────
  Future<EchoExploreData> getExploreData() async {
    final results = await Future.wait([
      _post('browse', {'context': _webRemixContext(), 'browseId': 'FEmusic_explore'}),
      _post('browse', {
        'context': _webRemixContext(),
        'browseId': 'FEmusic_charts',
        'params': 'ggMGCgQIgAQ%3D',
      }),
      getMoodsAndGenres(),
    ]);

    final exploreJson = results[0] as Map<String, dynamic>?;
    final chartsJson = results[1] as Map<String, dynamic>?;
    final moods = results[2] as List<EchoMoodGenreItem>;

    final newReleases = <AudioCollection>[];
    if (exploreJson != null) {
      final contents = exploreJson['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]
              ?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
          as List<dynamic>?;
      if (contents != null) {
        for (final c in contents) {
          final shelf = c['musicCarouselShelfRenderer'];
          if (shelf is Map<String, dynamic>) {
            final section = _parseCarouselSection(shelf);
            if (section != null && section.collections.isNotEmpty) {
              newReleases.addAll(section.collections);
            }
          }
        }
      }
    }

    final chartSections = <EchoHomeSection>[];
    if (chartsJson != null) {
      final contents = chartsJson['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]
              ?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
          as List<dynamic>?;
      if (contents != null) {
        for (final c in contents) {
          final shelf = c['musicCarouselShelfRenderer'];
          if (shelf is Map<String, dynamic>) {
            final section = _parseCarouselSection(shelf);
            if (section != null) chartSections.add(section);
          }
        }
      }
    }

    return EchoExploreData(
      newReleaseAlbums: newReleases,
      moodsAndGenres: moods,
      chartSections: chartSections,
    );
  }

  Future<List<EchoMoodGenreItem>> getMoodsAndGenres() async {
    final data = await _post('browse', {
      'context': _webRemixContext(),
      'browseId': 'FEmusic_moods_and_genres',
    });
    if (data == null) return const [];

    final items = <EchoMoodGenreItem>[];
    final contents = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]
            ?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
        as List<dynamic>?;
    if (contents == null) return items;

    for (final section in contents) {
      final gridItems = section['gridRenderer']?['items'] as List<dynamic>?;
      if (gridItems == null) continue;
      for (final g in gridItems) {
        final btn = g['musicNavigationButtonRenderer'];
        if (btn is Map<String, dynamic>) {
          final title = _extractRunsText(btn['buttonText']);
          final stripeColor = (btn['solid']?['leftStripeColor'] as num?)?.toInt() ?? 0xFFED5564;
          final ep = btn['clickCommand']?['browseEndpoint'];
          final browseId = ep?['browseId']?.toString() ?? '';
          final params = ep?['params']?.toString();
          if (title.isNotEmpty && browseId.isNotEmpty) {
            items.add(EchoMoodGenreItem(
              title: title,
              stripeColorValue: stripeColor,
              browseId: browseId,
              params: params,
            ));
          }
        }
      }
    }
    return items;
  }

  // ─── 3. BROWSE DETAIL (Playlist / Album / Artist / Mood Page) ────────────────
  Future<AudioCollection> browseDetail(String browseId, {String? params, String fallbackTitle = 'Collection'}) async {
    final data = await _post('browse', {
      'context': _webRemixContext(),
      'browseId': browseId,
      if (params != null && params.isNotEmpty) 'params': params,
    });
    if (data == null) {
      return AudioCollection(
        id: browseId,
        title: fallbackTitle,
        creator: 'YouTube Music',
        type: 'playlist',
        artworkUrl: '',
        tracks: const [],
      );
    }

    String title = fallbackTitle;
    String creator = 'YouTube Music';
    String artwork = '';
    final tracks = <Track>[];

    // Header parsing (both responsive header & detail header)
    final header = data['header']?['musicDetailHeaderRenderer'] ??
        data['header']?['musicImmersiveHeaderRenderer'] ??
        data['header']?['musicHeaderRenderer'] ??
        data['contents']?['twoColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents']?[0]?['musicResponsiveHeaderRenderer'];

    if (header is Map<String, dynamic>) {
      final t = _extractRunsText(header['title']);
      if (t.isNotEmpty) title = t;
      final sub = _extractRunsText(header['subtitle'] ?? header['straplineTextOne']);
      if (sub.isNotEmpty) creator = sub;
      artwork = _extractThumbnail(header['thumbnail']) ?? artwork;
    }

    // Recursively harvest all musicResponsiveListItemRenderer & musicTwoRowItemRenderer tracks
    _collectItemsFromNode(data['contents'], tracks, fallbackArtwork: artwork);

    return AudioCollection(
      id: browseId,
      title: title,
      creator: creator,
      type: browseId.startsWith('MPREb_')
          ? 'album'
          : browseId.startsWith('UC')
              ? 'artist'
              : 'playlist',
      artworkUrl: artwork.isNotEmpty ? artwork : (tracks.isNotEmpty ? tracks.first.artworkUrl : ''),
      tracks: tracks,
      params: params,
    );
  }

  // ─── 4. SEARCH (Songs, Videos, Albums, Artists, Playlists) ──────────────────
  static const String filterSongs = 'EgWKAQIIAWoKEAoQBRAKEAMQBA%3D%3D';
  static const String filterVideos = 'EgWKAQIQAWoKEAoQBRAKEAMQBA%3D%3D';
  static const String filterAlbums = 'EgWKAQIYAWoKEAoQBRAKEAMQBA%3D%3D';
  static const String filterArtists = 'EgWKAQIgAWoKEAoQBRAKEAMQBA%3D%3D';
  static const String filterPlaylists = 'EgWKAQIoAWoKEAoQBRAKEAMQBA%3D%3D';

  Future<List<Track>> searchTracks(String query, {String? filterParams}) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    final data = await _post('search', {
      'context': _webRemixContext(),
      'query': clean,
      if (filterParams != null) 'params': filterParams,
    });

    final tracks = <Track>[];
    if (data != null) {
      _collectItemsFromNode(data['contents'], tracks);
    }

    final filtered = tracks
        .where((t) => t.duration == Duration.zero || t.duration.inSeconds >= minSongDurationSeconds)
        .toList();
    if (filtered.isNotEmpty) return filtered;

    // Fallback to existing YoutubeExplode search
    final fb = await InnerTubeService().searchTracks(clean);
    return fb
        .where((t) => t.duration == Duration.zero || t.duration.inSeconds >= minSongDurationSeconds)
        .toList();
  }

  Future<List<AudioCollection>> searchCollections(String query, {required String filterParams}) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    final data = await _post('search', {
      'context': _webRemixContext(),
      'query': clean,
      'params': filterParams,
    });
    if (data == null) return const [];

    final collections = <AudioCollection>[];
    _collectCollectionsFromNode(data['contents'], collections);
    return collections;
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    final data = await _post(
      'music/get_search_suggestions',
      {'context': _webRemixContext(), 'input': clean},
      timeout: const Duration(seconds: 3),
    );
    final suggestions = <String>[];
    if (data != null) {
      final contents = data['contents'];
      if (contents is List) {
        for (final sec in contents) {
          final items = sec['searchSuggestionsSectionRenderer']?['contents'];
          if (items is List) {
            for (final item in items) {
              final text = _extractRunsText(item['searchSuggestionRenderer']?['suggestion']);
              if (text.isNotEmpty && !suggestions.contains(text)) {
                suggestions.add(text);
              }
            }
          }
        }
      }
    }
    if (suggestions.isNotEmpty) return suggestions;
    return InnerTubeService().getSearchSuggestions(clean);
  }

  // ─── 5. ECHO BRAIN / RELATED AUTO-QUEUE (next endpoint) ─────────────────────
  Future<List<Track>> getNextRadioTracks(String rawVideoId) async {
    final videoId = rawVideoId.replaceAll('yt_', '').replaceAll('ytm_', '').trim();
    if (videoId.isEmpty) return const [];

    final data = await _post('next', {
      'context': _webRemixContext(),
      'videoId': videoId,
      'isAudioOnly': true,
    });
    if (data == null) return const [];

    final tracks = <Track>[];
    final contents = data['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']
            ?['watchNextTabbedResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']
            ?['musicQueueRenderer']?['content']?['playlistPanelRenderer']?['contents']
        as List<dynamic>?;

    if (contents != null) {
      for (final item in contents) {
        final renderer = item['playlistPanelVideoRenderer'];
        if (renderer is Map<String, dynamic>) {
          final vid = renderer['videoId']?.toString() ?? '';
          if (vid.isEmpty || vid == videoId) continue;
          final title = _extractRunsText(renderer['title']);
          final artist = _extractRunsText(renderer['shortBylineText'] ?? renderer['longBylineText']);
          final thumb = _extractThumbnail(renderer['thumbnail']) ??
              'https://img.youtube.com/vi/$vid/hqdefault.jpg';
          final durText = _extractRunsText(renderer['lengthText']);
          final dur = _parseDuration(durText);
          if (dur > Duration.zero && dur.inSeconds < minSongDurationSeconds) continue;
          tracks.add(Track(
            id: 'yt_$vid',
            title: title.isNotEmpty ? title : 'Recommended Track',
            artist: artist.isNotEmpty ? artist.split('•').first.trim() : 'YouTube Music',
            duration: dur,
            artworkUrl: thumb,
            streamUrl: '',
            sourcePluginId: 'YouTube Music Radio',
            isRecommended: true,
          ));
        }
      }
    }
    return tracks;
  }

  // ─── 6. APPLE MUSIC RSS TOP 100 & ALBUMS (AppleMusicScraper.kt) ────────────
  Future<List<AppleTopEntry>> getAppleMusicTopSongs({String? country}) async {
    final cc = (country ?? _regionCode).toLowerCase();
    return _fetchAppleRss(
      'https://rss.applemarketingtools.com/api/v2/$cc/music/most-played/100/songs.json',
      size: '600x600',
    );
  }

  Future<List<AppleTopEntry>> getAppleMusicTopAlbums({String? country}) async {
    final cc = (country ?? _regionCode).toLowerCase();
    return _fetchAppleRss(
      'https://rss.applemarketingtools.com/api/v2/$cc/music/most-played/25/albums.json',
      size: '600x600',
    );
  }

  Future<List<AppleTopEntry>> _fetchAppleRss(String url, {required String size}) async {
    try {
      final resp = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      ).timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final results = json['feed']?['results'] as List<dynamic>? ?? const [];
        final entries = <AppleTopEntry>[];
        for (int i = 0; i < results.length; i++) {
          final item = results[i] as Map<String, dynamic>;
          final art = (item['artworkUrl100']?.toString() ?? '')
              .replaceAll(RegExp(r'\d+x\d+'), size);
          entries.add(AppleTopEntry(
            rank: i + 1,
            title: item['name']?.toString() ?? '',
            artist: item['artistName']?.toString() ?? '',
            artworkUrl: art,
            appleUrl: item['url']?.toString() ?? '',
          ));
        }
        return entries;
      }
    } catch (e) {
      debugPrint('Apple RSS error ($url): $e');
    }
    return const [];
  }

  // ─── 7. ECHO MUSIC INNERTUBE FAST RESPONSE PLAYER ENGINE ──────────────────
  /// Extracts high-speed direct CDN streams using Echo Music's proven client hierarchy:
  /// 1. VISIONOS (probed to serve 100% complete files without 1MiB throttle)
  /// 2. ANDROID_VR 1.65.10 (Oculus Quest 3 whole-file stream)
  /// 3. ANDROID (Android 14 gzip no-auth direct stream)
  /// 4. IOS (last resort fallback)
  Future<String?> resolveStreamUrlDirect(String rawVideoId, {String quality = 'auto'}) async {
    final videoId = rawVideoId.replaceAll('yt_', '').replaceAll('ytm_', '').trim();
    if (videoId.isEmpty) return null;

    final clients = [
      {
        'clientName': 'VISIONOS',
        'clientVersion': '0.1',
        'clientId': '101',
        'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
        'origin': 'https://www.youtube.com',
        'osName': 'visionOS',
        'osVersion': '1.3.21O771',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice14,1',
      },
      {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.65.10',
        'clientId': '28',
        'userAgent':
            'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
        'origin': 'https://www.youtube.com',
        'osName': 'Android',
        'osVersion': '12L',
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
        'androidSdkVersion': '32',
      },
      {
        'clientName': 'ANDROID',
        'clientVersion': '21.03.38',
        'clientId': '3',
        'userAgent': 'com.google.android.youtube/21.03.38 (Linux; U; Android 14) gzip',
        'origin': 'https://www.youtube.com',
      },
      {
        'clientName': 'IOS',
        'clientVersion': '21.03.1',
        'clientId': '5',
        'userAgent': 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
        'origin': 'https://www.youtube.com',
        'osVersion': '18.2.22C152',
      },
    ];

    for (final c in clients) {
      try {
        final origin = c['origin']!;
        final resp = await _client
            .post(
              Uri.parse('$origin/youtubei/v1/player?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': c['userAgent']!,
                'X-YouTube-Client-Name': c['clientId']!,
                'X-YouTube-Client-Version': c['clientVersion']!,
                'Origin': origin,
                if (_visitorData != null) 'X-Goog-Visitor-Id': _visitorData!,
              },
              body: jsonEncode({
                'context': {
                  'client': {
                    'clientName': c['clientName'],
                    'clientVersion': c['clientVersion'],
                    'gl': _regionCode,
                    'hl': _languageCode,
                    if (c['osName'] != null) 'osName': c['osName'],
                    if (c['osVersion'] != null) 'osVersion': c['osVersion'],
                    if (c['deviceMake'] != null) 'deviceMake': c['deviceMake'],
                    if (c['deviceModel'] != null) 'deviceModel': c['deviceModel'],
                    if (c['androidSdkVersion'] != null) 'androidSdkVersion': c['androidSdkVersion'],
                    if (_visitorData != null) 'visitorData': _visitorData,
                  },
                },
                'videoId': videoId,
                'contentCheckOk': true,
                'racyCheckOk': true,
              }),
            )
            .timeout(const Duration(milliseconds: 2500));

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final playStatus = json['playabilityStatus']?['status']?.toString();
          if (playStatus == 'OK') {
            final adaptive = json['streamingData']?['adaptiveFormats'] as List<dynamic>? ?? const [];
            final progressive = json['streamingData']?['formats'] as List<dynamic>? ?? const [];
            final allFormats = [...adaptive, ...progressive];

            // Filter for playable audio formats with direct unthrottled CDN URLs
            final audioFormats = allFormats.where((f) {
              final mime = (f['mimeType']?.toString() ?? '').toLowerCase();
              final url = f['url']?.toString() ?? '';
              return (mime.contains('audio') || mime.contains('mp4')) && url.isNotEmpty;
            }).toList();

            if (audioFormats.isNotEmpty) {
              if (quality == '128k') {
                audioFormats.sort((a, b) {
                  final brA = (a['bitrate'] as num?)?.toInt() ?? 128000;
                  final brB = (b['bitrate'] as num?)?.toInt() ?? 128000;
                  return (brA - 128000).abs().compareTo((brB - 128000).abs());
                });
              } else {
                audioFormats.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
              }
              final url = audioFormats.first['url']?.toString();
              if (url != null && url.isNotEmpty) return url;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ─── JSON PARSERS ───────────────────────────────────────────────────────────
  EchoHomeSection? _parseCarouselSection(Map<String, dynamic> carousel) {
    final header = carousel['header']?['musicCarouselShelfBasicHeaderRenderer'];
    final title = _extractRunsText(header?['title']);
    if (title.isEmpty) return null;
    final subtitle = _extractRunsText(header?['strapline']);
    final moreEp = header?['moreContentButton']?['buttonRenderer']?['navigationEndpoint']
        ?['browseEndpoint'];

    final tracks = <Track>[];
    final collections = <AudioCollection>[];
    final contents = carousel['contents'] as List<dynamic>? ?? const [];

    for (final c in contents) {
      final twoRow = c['musicTwoRowItemRenderer'];
      if (twoRow is Map<String, dynamic>) {
        final videoId = twoRow['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
        final browseEp = twoRow['navigationEndpoint']?['browseEndpoint'];
        final itemTitle = _extractRunsText(twoRow['title']);
        final itemSub = _extractRunsText(twoRow['subtitle']);
        final thumb = _extractThumbnail(twoRow['thumbnailRenderer']) ?? '';
        if (videoId != null && videoId.isNotEmpty && itemTitle.isNotEmpty) {
          tracks.add(Track(
            id: 'yt_$videoId',
            title: itemTitle,
            artist: itemSub.isNotEmpty ? itemSub.split('•').first.trim() : 'YouTube Music',
            duration: const Duration(seconds: 210),
            artworkUrl: thumb.isNotEmpty ? thumb : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            streamUrl: '',
            sourcePluginId: 'YouTube Music',
          ));
        } else if (browseEp is Map<String, dynamic> && itemTitle.isNotEmpty) {
          final bId = browseEp['browseId']?.toString() ?? '';
          if (bId.isNotEmpty) {
            collections.add(AudioCollection(
              id: bId,
              title: itemTitle,
              creator: itemSub.isNotEmpty ? itemSub : 'YouTube Music',
              type: bId.startsWith('MPREb_')
                  ? 'album'
                  : bId.startsWith('UC')
                      ? 'artist'
                      : 'playlist',
              artworkUrl: thumb,
              tracks: const [],
              params: browseEp['params']?.toString(),
            ));
          }
        }
      }
      final listItem = c['musicResponsiveListItemRenderer'];
      if (listItem is Map<String, dynamic>) {
        final track = _parseResponsiveTrack(listItem);
        if (track != null) tracks.add(track);
      }
    }

    if (tracks.isEmpty && collections.isEmpty) return null;
    return EchoHomeSection(
      title: title,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      browseId: moreEp?['browseId']?.toString(),
      params: moreEp?['params']?.toString(),
      tracks: tracks,
      collections: collections,
    );
  }

  void _collectItemsFromNode(dynamic node, List<Track> out, {String fallbackArtwork = ''}) {
    if (out.length >= 60) return;
    if (node is Map<String, dynamic>) {
      if (node.containsKey('musicResponsiveListItemRenderer')) {
        final t = _parseResponsiveTrack(
          node['musicResponsiveListItemRenderer'] as Map<String, dynamic>,
          fallbackArtwork: fallbackArtwork,
        );
        if (t != null && !out.any((e) => e.id == t.id)) {
          out.add(t);
        }
        return;
      }
      if (node.containsKey('musicTwoRowItemRenderer')) {
        final r = node['musicTwoRowItemRenderer'] as Map<String, dynamic>;
        final vid = r['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
        if (vid != null && vid.isNotEmpty) {
          final title = _extractRunsText(r['title']);
          final sub = _extractRunsText(r['subtitle']);
          final thumb = _extractThumbnail(r['thumbnailRenderer']) ?? fallbackArtwork;
          if (title.isNotEmpty && !out.any((e) => e.id == 'yt_$vid')) {
            out.add(Track(
              id: 'yt_$vid',
              title: title,
              artist: sub.isNotEmpty ? sub.split('•').first.trim() : 'YouTube Music',
              duration: const Duration(seconds: 210),
              artworkUrl: thumb.isNotEmpty ? thumb : 'https://img.youtube.com/vi/$vid/hqdefault.jpg',
              streamUrl: '',
              sourcePluginId: 'YouTube Music',
            ));
          }
        }
        return;
      }
      for (final val in node.values) {
        _collectItemsFromNode(val, out, fallbackArtwork: fallbackArtwork);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectItemsFromNode(item, out, fallbackArtwork: fallbackArtwork);
      }
    }
  }

  void _collectCollectionsFromNode(dynamic node, List<AudioCollection> out) {
    if (out.length >= 30) return;
    if (node is Map<String, dynamic>) {
      if (node.containsKey('musicResponsiveListItemRenderer')) {
        final r = node['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
        final ep = r['navigationEndpoint']?['browseEndpoint'];
        final bId = ep?['browseId']?.toString() ?? '';
        if (bId.isNotEmpty) {
          final cols = r['flexColumns'] as List<dynamic>? ?? const [];
          final title = cols.isNotEmpty
              ? _extractRunsText(cols[0]['musicResponsiveListItemFlexColumnRenderer']?['text'])
              : '';
          final sub = cols.length > 1
              ? _extractRunsText(cols[1]['musicResponsiveListItemFlexColumnRenderer']?['text'])
              : '';
          final thumb = _extractThumbnail(r['thumbnail']) ?? '';
          if (title.isNotEmpty && !out.any((c) => c.id == bId)) {
            out.add(AudioCollection(
              id: bId,
              title: title,
              creator: sub.isNotEmpty ? sub : 'YouTube Music',
              type: bId.startsWith('MPREb_')
                  ? 'album'
                  : bId.startsWith('UC')
                      ? 'artist'
                      : 'playlist',
              artworkUrl: thumb,
              tracks: const [],
              params: ep?['params']?.toString(),
            ));
          }
        }
        return;
      }
      for (final val in node.values) {
        _collectCollectionsFromNode(val, out);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectCollectionsFromNode(item, out);
      }
    }
  }

  Track? _parseResponsiveTrack(Map<String, dynamic> r, {String fallbackArtwork = ''}) {
    String videoId = r['playlistItemData']?['videoId']?.toString() ??
        r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                ?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']
                ?['videoId']
            ?.toString() ??
        '';
    if (videoId.isEmpty) {
      videoId = r['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';
    }
    if (videoId.isEmpty) return null;

    final cols = r['flexColumns'] as List<dynamic>? ?? const [];
    final title = cols.isNotEmpty
        ? _extractRunsText(cols[0]['musicResponsiveListItemFlexColumnRenderer']?['text'])
        : '';
    if (title.isEmpty) return null;

    String artist = 'YouTube Music';
    String? artistId;
    String album = '';
    String? albumId;
    Duration duration = const Duration(seconds: 210);

    if (cols.length > 1) {
      final runs = cols[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
          as List<dynamic>?;
      if (runs != null && runs.isNotEmpty) {
        final artistNames = <String>[];
        for (final run in runs) {
          final text = run['text']?.toString().trim() ?? '';
          if (text.isEmpty || text == '•' || text == ',' || text == '&') continue;
          final bId = run['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          if (bId.startsWith('UC')) {
            artistId ??= bId;
            artistNames.add(text);
          } else if (bId.startsWith('MPREb_')) {
            albumId ??= bId;
            album = text;
          } else if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(text)) {
            duration = _parseDuration(text);
          } else if (artistNames.isEmpty && !text.contains('plays') && !text.contains('views')) {
            artistNames.add(text);
          }
        }
        if (artistNames.isNotEmpty) artist = artistNames.join(', ');
      }
    }

    final fixedCols = r['fixedColumns'] as List<dynamic>? ?? const [];
    if (fixedCols.isNotEmpty) {
      final dText = _extractRunsText(
          fixedCols[0]['musicResponsiveListItemFixedColumnRenderer']?['text']);
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(dText)) {
        duration = _parseDuration(dText);
      }
    }

    final thumb = _extractThumbnail(r['thumbnail']) ??
        (fallbackArtwork.isNotEmpty
            ? fallbackArtwork
            : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg');

    if (duration > Duration.zero && duration.inSeconds < minSongDurationSeconds) {
      return null;
    }

    return Track(
      id: 'yt_$videoId',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artworkUrl: thumb,
      streamUrl: '',
      sourcePluginId: 'YouTube Music',
      artistId: artistId,
      albumId: albumId,
    );
  }

  String _extractRunsText(dynamic node) {
    if (node is Map<String, dynamic>) {
      if (node['simpleText'] is String) return node['simpleText'].toString().trim();
      final runs = node['runs'];
      if (runs is List) {
        return runs.map((r) => r['text']?.toString() ?? '').join().trim();
      }
    }
    return '';
  }

  String? _extractThumbnail(dynamic thumbNode) {
    if (thumbNode is! Map<String, dynamic>) return null;
    final list = thumbNode['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
        thumbNode['croppedSquareThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
        thumbNode['thumbnails'];
    if (list is List && list.isNotEmpty) {
      var url = list.last['url']?.toString() ?? '';
      if (url.startsWith('//')) url = 'https:$url';
      if (url.contains('lh3.googleusercontent.com') && url.contains('=w')) {
        url = url.replaceAll(RegExp(r'=w\d+-h\d+[^&]*'), '=w720-h720-l90-rj');
      }
      return url.isNotEmpty ? url : null;
    }
    return null;
  }

  Duration _parseDuration(String raw) {
    final parts = raw.trim().split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
    if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    return const Duration(seconds: 210);
  }
}
