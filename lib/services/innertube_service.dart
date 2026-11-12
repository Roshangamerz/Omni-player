import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import '../models/track.dart';

/// Ultra-Fast, Zero-Bloat YouTube Search & Suggestion Service
class InnerTubeService {
  static final InnerTubeService _instance = InnerTubeService._internal();
  factory InnerTubeService() => _instance;
  InnerTubeService._internal();

  final yte.YoutubeExplode _yt = yte.YoutubeExplode();
  final http.Client _client = http.Client();

  // Static pre-compiled RegExp to eliminate regex compilation churn
  static final RegExp _jsonArrayRegex = RegExp(r'\[.*\]');

  /// Get search suggestions from Google suggest API (0ms instant response)
  Future<List<String>> getSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    try {
      final suggestUri = Uri.parse(
          'https://suggestqueries.google.com/complete/search?client=youtube&ds=yt&gl=in&hl=en-GB&q=${Uri.encodeComponent(clean)}');
      final resp = await _client.get(suggestUri).timeout(const Duration(seconds: 2));

      if (resp.statusCode == 200) {
        final match = _jsonArrayRegex.firstMatch(resp.body);
        if (match != null) {
          final parsed = jsonDecode(match.group(0)!);
          if (parsed is List && parsed.length > 1 && parsed[1] is List) {
            final rawList = parsed[1] as List;
            final suggestions = <String>[];
            for (int i = 0; i < rawList.length; i++) {
              final item = rawList[i];
              if (item is List && item.isNotEmpty) {
                final s = item[0].toString().trim();
                if (s.isNotEmpty && !suggestions.contains(s)) {
                  suggestions.add(s);
                }
              }
            }
            return suggestions;
          }
        }
      }
    } catch (_) {}

    return const [];
  }

  /// Search tracks across YouTube / YouTube Music
  Future<List<Track>> searchTracks(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    try {
      final searchResults = await _yt.search.search(clean).timeout(
        const Duration(seconds: 4),
      );

      final tracks = <Track>[];
      int count = 0;

      for (final video in searchResults) {
        final videoId = video.id.value;
        if (videoId.isEmpty) continue;

        // Skip only obvious phone tech tutorial spam
        final lower = video.title.toLowerCase();
        if (lower.contains('phone hanging') ||
            lower.contains('storage full') ||
            lower.contains('how to transfer file') ||
            lower.contains('internal storage to sd')) {
          continue;
        }

        tracks.add(
          Track(
            id: 'yt_$videoId',
            title: video.title,
            artist: video.author.isNotEmpty ? video.author : 'YouTube Music',
            streamUrl: '', // Dynamically resolved on-demand via AudioStreamService
            artworkUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
            duration: video.duration ?? const Duration(seconds: 210),
            sourcePluginId: 'YouTube',
          ),
        );

        count++;
        if (count >= 25) break;
      }

      if (tracks.isNotEmpty) return tracks;
    } catch (_) {}

    return const [];
  }

  void dispose() {
    _yt.close();
    _client.close();
  }
}
