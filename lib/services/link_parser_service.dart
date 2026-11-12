import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import '../models/track.dart';
import 'api_sources_service.dart';
import 'extension_engine.dart';

class ParsedPlaylist {
  final String title;
  final String author;
  final String artworkUrl;
  final List<Track> tracks;

  const ParsedPlaylist({
    required this.title,
    required this.author,
    required this.artworkUrl,
    required this.tracks,
  });
}

class LinkParseResult {
  final bool isPlaylist;
  final Track? track;
  final ParsedPlaylist? playlist;
  final String? errorMessage;

  bool get isTrack => !isPlaylist && track != null;

  const LinkParseResult.track(this.track)
      : isPlaylist = false,
        playlist = null,
        errorMessage = null;

  const LinkParseResult.playlist(this.playlist)
      : isPlaylist = true,
        track = null,
        errorMessage = null;

  const LinkParseResult.error(this.errorMessage)
      : isPlaylist = false,
        track = null,
        playlist = null;
}

class LinkParserService {
  static final LinkParserService _instance = LinkParserService._internal();
  factory LinkParserService() => _instance;
  LinkParserService._internal();

  final ExtensionEngine _extensionEngine = ExtensionEngine();

  /// Parse any pasted music URL (YouTube, YouTube Music, Spotify, JioSaavn)
  Future<LinkParseResult> parseUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) {
      return const LinkParseResult.error('Please enter or paste a valid link.');
    }

    try {
      // 1. YouTube / YouTube Music Playlist
      final playlistRegex = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
      final playlistMatch = playlistRegex.firstMatch(clean);
      if (playlistMatch != null) {
        final listId = playlistMatch.group(1);
        if (listId != null && listId.isNotEmpty && listId != 'WL' && listId != 'LM') {
          return await _parseYouTubePlaylist(listId);
        }
      }

      // 2. YouTube / YouTube Music Track
      String? videoId;
      if (clean.contains('youtu.be/')) {
        final reg = RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})');
        final m = reg.firstMatch(clean);
        videoId = m?.group(1);
      } else if (clean.contains('watch?v=') || clean.contains('watch?')) {
        final reg = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})');
        final m = reg.firstMatch(clean);
        videoId = m?.group(1);
      } else if (clean.contains('/shorts/')) {
        final reg = RegExp(r'\/shorts\/([a-zA-Z0-9_-]{11})');
        final m = reg.firstMatch(clean);
        videoId = m?.group(1);
      } else if (clean.contains('/embed/')) {
        final reg = RegExp(r'\/embed\/([a-zA-Z0-9_-]{11})');
        final m = reg.firstMatch(clean);
        videoId = m?.group(1);
      }

      if (videoId != null && videoId.isNotEmpty) {
        return await _parseYouTubeTrack(videoId);
      }

      // 3. Spotify Track / Playlist
      if (clean.contains('spotify.com/')) {
        final uri = Uri.parse(clean);
        if (clean.contains('/playlist/')) {
          return await _parseSpotifyPlaylist(uri);
        } else if (clean.contains('/track/')) {
          return await _parseSpotifyTrack(clean);
        } else if (clean.contains('/album/')) {
          return await _parseSpotifyPlaylist(uri);
        }
      }

      // 4. JioSaavn URL
      if (clean.contains('jiosaavn.com/')) {
        return await _parseJioSaavnLink(clean);
      }

      // Fallback: Search across all active engines
      final searchHits = await _extensionEngine.searchAcrossAllSources(clean);
      if (searchHits.isNotEmpty) {
        return LinkParseResult.track(searchHits.first);
      }

      return const LinkParseResult.error('Could not recognize or load audio from this link.');
    } catch (e) {
      return LinkParseResult.error('Error parsing link: $e');
    }
  }

  Future<LinkParseResult> _parseYouTubePlaylist(String listId) async {
    // Strategy 1: YoutubeExplode direct playlist video stream (Fastest & 100% authentic)
    final yt = yte.YoutubeExplode();
    try {
      final pl = await yt.playlists.get(listId).timeout(const Duration(seconds: 6));
      final title = pl.title.isNotEmpty ? pl.title : 'YouTube Playlist';
      final author = pl.author.isNotEmpty ? pl.author : 'YouTube Music';
      String thumbnail = pl.thumbnails.highResUrl.isNotEmpty
          ? pl.thumbnails.highResUrl
          : (pl.thumbnails.standardResUrl.isNotEmpty
              ? pl.thumbnails.standardResUrl
              : (pl.thumbnails.mediumResUrl.isNotEmpty
                  ? pl.thumbnails.mediumResUrl
                  : ''));

      final tracks = <Track>[];
      await for (final video in yt.playlists.getVideos(listId).take(50)) {
        final vId = video.id.value;
        if (vId.isEmpty) continue;

        if (thumbnail.isEmpty) {
          thumbnail = 'https://img.youtube.com/vi/$vId/hqdefault.jpg';
        }

        tracks.add(
          Track(
            id: 'yt_$vId',
            title: video.title,
            artist: video.author.isNotEmpty ? video.author : author,
            streamUrl: '', // Dynamically resolved on playback
            artworkUrl: 'https://img.youtube.com/vi/$vId/hqdefault.jpg',
            duration: video.duration ?? const Duration(seconds: 210),
            sourcePluginId: 'YouTube',
          ),
        );
      }

      if (tracks.isNotEmpty) {
        return LinkParseResult.playlist(
          ParsedPlaylist(
            title: title,
            author: author,
            artworkUrl: thumbnail.isNotEmpty ? thumbnail : 'https://img.youtube.com/vi/$listId/hqdefault.jpg',
            tracks: tracks,
          ),
        );
      }
    } catch (_) {
    } finally {
      yt.close();
    }

    // Strategy 2: Multi-instance Piped API fallback
    final instances = ApiSourcesService().pipedInstances;
    for (final base in instances) {
      try {
        final resp = await http
            .get(Uri.parse('$base/playlists/$listId'))
            .timeout(const Duration(seconds: 4));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final title = data['name'] ?? 'Imported Playlist';
          final author = data['uploader'] ?? 'YouTube';
          final thumbnail = data['thumbnailUrl'] ??
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500';

          final relatedStreams = data['relatedStreams'] as List? ?? [];
          final tracks = <Track>[];

          for (final item in relatedStreams) {
            final url = item['url'] as String? ?? '';
            final videoId = url.replaceFirst('/watch?v=', '');
            if (videoId.isEmpty) continue;

            tracks.add(
              Track(
                id: 'yt_$videoId',
                title: item['title'] ?? 'Unknown Track',
                artist: item['uploaderName'] ?? author,
                streamUrl: '',
                artworkUrl: item['thumbnailUrl'] ?? thumbnail,
                duration: Duration(seconds: (item['duration'] as num?)?.toInt() ?? 210),
                sourcePluginId: 'YouTube',
              ),
            );
          }

          if (tracks.isNotEmpty) {
            return LinkParseResult.playlist(
              ParsedPlaylist(
                title: title,
                author: author,
                artworkUrl: thumbnail,
                tracks: tracks,
              ),
            );
          }
        }
      } catch (_) {}
    }

    return const LinkParseResult.error('Could not load YouTube playlist tracks.');
  }

  Future<LinkParseResult> _parseYouTubeTrack(String videoId) async {
    String title = 'YouTube Track';
    String artist = 'YouTube Music';
    String artworkUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    String directStreamUrl = '';

    try {
      final oEmbedUrl = 'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json';
      final resp = await http.get(Uri.parse(oEmbedUrl)).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        title = data['title'] ?? title;
        artist = data['author_name'] ?? artist;
        artworkUrl = data['thumbnail_url'] ?? artworkUrl;
      }
    } catch (_) {}

    return LinkParseResult.track(
      Track(
        id: 'yt_$videoId',
        title: title,
        artist: artist,
        streamUrl: directStreamUrl,
        artworkUrl: artworkUrl,
        duration: const Duration(seconds: 210),
        sourcePluginId: 'YouTube',
      ),
    );
  }

  Future<LinkParseResult> _parseSpotifyPlaylist(Uri uri) async {
    String playlistId = '';
    final bool isAlbum = uri.path.contains('/album/');
    for (int i = 0; i < uri.pathSegments.length; i++) {
      if (uri.pathSegments[i] == 'playlist' || uri.pathSegments[i] == 'album') {
        if (i + 1 < uri.pathSegments.length) {
          playlistId = uri.pathSegments[i + 1].split('?').first;
          break;
        }
      }
    }

    if (playlistId.isEmpty) {
      playlistId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('?').first : '';
    }

    if (playlistId.isEmpty) {
      return const LinkParseResult.error('Invalid Spotify playlist URL.');
    }

    String playlistTitle = isAlbum ? 'Spotify Album' : 'Spotify Playlist';
    String playlistAuthor = 'Spotify';
    String artworkUrl = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500';

    // Step 1: Query oEmbed for authentic playlist metadata
    try {
      final oEmbedUri = Uri.parse('https://open.spotify.com/oembed?url=${uri.toString()}');
      final oEmbedResp = await http.get(oEmbedUri).timeout(const Duration(seconds: 4));
      if (oEmbedResp.statusCode == 200) {
        final oData = jsonDecode(oEmbedResp.body);
        playlistTitle = oData['title'] ?? playlistTitle;
        artworkUrl = oData['thumbnail_url'] ?? artworkUrl;
      }
    } catch (_) {}

    // Step 2: Scrape Spotify Embed page for authentic tracklist
    final tracks = <Track>[];
    try {
      final embedUrl = Uri.parse('https://open.spotify.com/embed/${isAlbum ? 'album' : 'playlist'}/$playlistId');
      final embedResp = await http.get(
        embedUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 6));

      if (embedResp.statusCode == 200) {
        final body = embedResp.body;

        // Path A: __NEXT_DATA__ JSON script
        final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(body);
        if (nextDataMatch != null) {
          final jsonStr = nextDataMatch.group(1);
          if (jsonStr != null) {
            final parsed = jsonDecode(jsonStr);
            final entities = [
              parsed['props']?['pageProps']?['state']?['data']?['entity'],
              parsed['props']?['pageProps']?['initialStoreState']?['data']?['entity'],
              parsed['props']?['pageProps']?['entity'],
            ];

            for (final entity in entities) {
              if (entity == null) continue;
              playlistTitle = entity['name'] ?? entity['title'] ?? playlistTitle;
              final coverSources = entity['coverArt']?['sources'] as List? ?? entity['images'] as List?;
              if (coverSources != null && coverSources.isNotEmpty) {
                artworkUrl = coverSources.first['url'] ?? artworkUrl;
              }

              final rawTrackList = entity['trackList'] as List? ??
                  entity['tracks']?['items'] as List? ??
                  [];

              for (final rawItem in rawTrackList) {
                final t = (rawItem is Map && rawItem.containsKey('track')) ? rawItem['track'] : rawItem;
                if (t == null || t is! Map) continue;

                final tTitle = (t['name'] ?? t['title'] ?? '').toString();
                if (tTitle.isEmpty) continue;

                final tArtist = (t['artists'] is List)
                    ? (t['artists'] as List).map((a) => (a is Map ? a['name'] : a.toString()) ?? '').join(', ')
                    : (t['subtitle'] ?? t['artists']?.toString() ?? playlistAuthor);
                final tDurationMs = t['duration_ms'] as int? ?? t['duration'] as int? ?? 180000;
                final tUri = (t['uri']?.toString() ?? t['id']?.toString() ?? '').replaceAll('spotify:track:', '');

                tracks.add(
                  Track(
                    id: 'sp_${tUri.isNotEmpty ? tUri : UniqueKey().toString()}',
                    title: tTitle,
                    artist: tArtist.toString().trim(),
                    streamUrl: '', // Dynamically resolved on playback
                    artworkUrl: artworkUrl,
                    duration: Duration(milliseconds: tDurationMs),
                    sourcePluginId: 'Spotify',
                  ),
                );
              }
              if (tracks.isNotEmpty) break;
            }
          }
        }

        // Path B: Spotify.Entity fallback
        if (tracks.isEmpty) {
          final resourceMatch = RegExp(r'Spotify\.Entity\s*=\s*(\{.*?\});', dotAll: true).firstMatch(body);
          if (resourceMatch != null) {
            final entityJson = jsonDecode(resourceMatch.group(1)!);
            final rawTracks = entityJson['tracks']?['items'] as List? ?? entityJson['trackList'] as List? ?? [];
            for (final item in rawTracks) {
              final trk = (item is Map && item.containsKey('track')) ? item['track'] : item;
              if (trk == null || trk is! Map) continue;
              final trkTitle = trk['name'] ?? trk['title'] ?? '';
              final trkArtists = (trk['artists'] as List?)?.map((a) => a is Map ? a['name'] : a.toString()).join(', ') ?? 'Spotify';
              final durMs = trk['duration_ms'] as int? ?? trk['duration'] as int? ?? 180000;
              final trkId = (trk['id'] ?? trk['uri'] ?? UniqueKey().toString()).toString().replaceAll('spotify:track:', '');

              if (trkTitle.toString().isNotEmpty) {
                tracks.add(
                  Track(
                    id: 'sp_$trkId',
                    title: trkTitle.toString(),
                    artist: trkArtists.toString().trim(),
                    streamUrl: '',
                    artworkUrl: artworkUrl,
                    duration: Duration(milliseconds: durMs),
                    sourcePluginId: 'Spotify',
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify embed scraper error: $e');
    }

    if (tracks.isNotEmpty) {
      return LinkParseResult.playlist(
        ParsedPlaylist(
          title: playlistTitle,
          author: playlistAuthor,
          artworkUrl: artworkUrl,
          tracks: tracks,
        ),
      );
    }

    return const LinkParseResult.error('Could not extract tracks from this Spotify playlist/album. Please ensure the playlist is public.');
  }

  Future<LinkParseResult> _parseSpotifyTrack(String url) async {
    try {
      final oEmbedUri = Uri.parse('https://open.spotify.com/oembed?url=$url');
      final resp = await http.get(oEmbedUri).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final title = data['title'] ?? 'Spotify Track';
        final thumbnail = data['thumbnail_url'] ??
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500';

        // Resolve highest quality audio via DES 320k / InnerTube
        final hits = await _extensionEngine.searchAcrossAllSources(title);
        if (hits.isNotEmpty) {
          return LinkParseResult.track(hits.first.copyWith(artworkUrl: thumbnail));
        }

        return LinkParseResult.track(
          Track(
            id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            artist: 'Spotify',
            streamUrl: '',
            artworkUrl: thumbnail,
            duration: const Duration(seconds: 200),
            sourcePluginId: 'Spotify',
          ),
        );
      }
    } catch (_) {}

    return const LinkParseResult.error('Could not load Spotify track details.');
  }

  Future<LinkParseResult> _parseJioSaavnLink(String url) async {
    final hits = await _extensionEngine.searchAcrossAllSources(url);
    if (hits.isNotEmpty) {
      return LinkParseResult.track(hits.first);
    }
    return const LinkParseResult.error('Could not locate JioSaavn track stream.');
  }
}
