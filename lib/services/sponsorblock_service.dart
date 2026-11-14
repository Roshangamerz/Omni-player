import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// SponsorBlock Segment model mirroring Echo Music's SponsorBlockSegment
class SponsorBlockSegment {
  final double start;
  final double end;
  final String category;
  final String actionType;
  final String uuid;

  const SponsorBlockSegment({
    required this.start,
    required this.end,
    required this.category,
    required this.actionType,
    required this.uuid,
  });

  bool containsSecond(double second) => second >= start && second < end;
}

/// Production SponsorBlock Service
/// Auto-skips sponsor segments, non-music intros/outros, and self-promotion
/// exactly like Echo Music (:data module).
class SponsorBlockService {
  static final SponsorBlockService _instance = SponsorBlockService._internal();
  factory SponsorBlockService() => _instance;
  SponsorBlockService._internal();

  final http.Client _client = http.Client();
  final Map<String, List<SponsorBlockSegment>> _cache = {};

  static const List<String> categories = [
    'sponsor',
    'intro',
    'outro',
    'interaction',
    'selfpromo',
    'music_offtopic',
  ];

  /// Fetch skip segments for a YouTube video ID
  Future<List<SponsorBlockSegment>> getSkipSegments(String rawVideoId) async {
    final videoId = rawVideoId.replaceAll('yt_', '').replaceAll('ytm_', '').trim();
    if (videoId.isEmpty) return const [];

    if (_cache.containsKey(videoId)) {
      return _cache[videoId]!;
    }

    try {
      final categoriesParam = jsonEncode(categories);
      final uri = Uri.parse(
        'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=${Uri.encodeComponent(categoriesParam)}',
      );

      final resp = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        final segments = <SponsorBlockSegment>[];

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final seg = item['segment'] as List<dynamic>?;
            if (seg != null && seg.length >= 2) {
              final start = (seg[0] as num).toDouble();
              final end = (seg[1] as num).toDouble();
              segments.add(SponsorBlockSegment(
                start: start,
                end: end,
                category: item['category']?.toString() ?? 'sponsor',
                actionType: item['actionType']?.toString() ?? 'skip',
                uuid: item['UUID']?.toString() ?? '',
              ));
            }
          }
        }

        _cache[videoId] = segments;
        return segments;
      }
    } catch (e) {
      debugPrint('SponsorBlock error for $videoId: $e');
    }

    _cache[videoId] = const [];
    return const [];
  }

  void clearCache() {
    _cache.clear();
  }
}
