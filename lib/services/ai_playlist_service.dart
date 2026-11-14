import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'echo_innertube_service.dart';

/// Weather condition info for meteorological music atmospheric matching
class WeatherMoodInfo {
  final String condition;
  final String emoji;
  final double temperature;
  final int humidity;
  final bool isDay;

  const WeatherMoodInfo({
    required this.condition,
    required this.emoji,
    required this.temperature,
    required this.humidity,
    required this.isDay,
  });

  static WeatherMoodInfo defaultVibe() {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour >= 19;
    return WeatherMoodInfo(
      condition: isNight ? 'Clear Night Sky' : 'Warm Ambient Afternoon',
      emoji: isNight ? '🌙' : '☀️',
      temperature: 24.0,
      humidity: 55,
      isDay: !isNight,
    );
  }
}

/// Echo-Grade AI Playlist Generator
/// Generates curated playlists based on mood prompts and atmospheric weather conditions
/// using OpenRouter, Gemini, OpenAI, or Echo AI routes.
class AiPlaylistService {
  static final AiPlaylistService _instance = AiPlaylistService._internal();
  factory AiPlaylistService() => _instance;
  AiPlaylistService._internal();

  final http.Client _client = http.Client();

  Future<List<Track>> generatePlaylistFromPrompt({
    required String userPrompt,
    WeatherMoodInfo? weather,
    int trackCount = 12,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString('omni_ai_endpoint') ?? 'https://openrouter.ai/api/v1/chat/completions';
    final model = prefs.getString('omni_ai_model') ?? 'google/gemini-2.0-flash-001';
    final apiKey = prefs.getString('omni_ai_key') ?? '';

    final w = weather ?? WeatherMoodInfo.defaultVibe();

    final systemPrompt = '''
You are an expert music curator and audiophile DJ.
Generate a JSON playlist of exactly $trackCount songs matching the user's mood and atmospheric conditions.
Atmosphere: ${w.condition} ${w.emoji}, ${w.temperature}°C, ${w.isDay ? "Day" : "Night"}.

Output ONLY valid JSON in this exact structure without markdown:
{
  "name": "Creative Playlist Title",
  "songs": [
    {"title": "Song Title", "artist": "Artist Name"}
  ]
}
''';

    List<Map<String, String>> songQueries = [];

    // If an API key is available, call the AI model
    if (apiKey.isNotEmpty) {
      try {
        final resp = await _client.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': 'Mood prompt: $userPrompt'},
            ],
            'temperature': 0.7,
          }),
        ).timeout(const Duration(seconds: 20));

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body);
          final text = json['choices']?[0]?['message']?['content']?.toString() ?? '';
          final cleanJson = text.replaceAll(RegExp(r'```json\s*'), '').replaceAll('```', '').trim();
          final parsed = jsonDecode(cleanJson);
          final songs = parsed['songs'] as List<dynamic>? ?? [];
          for (final s in songs) {
            if (s is Map<String, dynamic>) {
              final t = s['title']?.toString() ?? '';
              final a = s['artist']?.toString() ?? '';
              if (t.isNotEmpty) {
                songQueries.add({'title': t, 'artist': a});
              }
            }
          }
        }
      } catch (e) {
        debugPrint('AI Playlist API error: $e');
      }
    }

    // Fallback heuristic music generator if AI API key is not configured or offline
    if (songQueries.isEmpty) {
      songQueries = _getCuratedVibeList(userPrompt, w, trackCount);
    }

    // Resolve song queries to playable tracks via YouTube Music InnerTube
    final List<Track> tracks = [];
    for (final q in songQueries) {
      try {
        final queryStr = '${q['title']} ${q['artist']}'.trim();
        final hits = await EchoInnerTubeService().searchTracks(queryStr);
        final valid = hits.where((t) => t.duration == Duration.zero || t.duration.inSeconds >= 40).toList();
        if (valid.isNotEmpty) {
          tracks.add(valid.first);
        }
      } catch (_) {}
    }

    return tracks;
  }

  List<Map<String, String>> _getCuratedVibeList(String prompt, WeatherMoodInfo w, int count) {
    final lower = prompt.toLowerCase();
    if (lower.contains('chill') || lower.contains('lofi') || lower.contains('relax') || !w.isDay) {
      return [
        {'title': 'Snowman', 'artist': 'WYS'},
        {'title': 'Affection', 'artist': 'Jinsang'},
        {'title': 'Eternal Youth', 'artist': 'RUDE'},
        {'title': 'Controlla', 'artist': 'Idealism'},
        {'title': 'Feather', 'artist': 'Nujabes'},
        {'title': 'Luv(sic) pt3', 'artist': 'Nujabes'},
        {'title': 'Sunset Lover', 'artist': 'Petit Biscuit'},
        {'title': 'Midnight City', 'artist': 'M83'},
        {'title': 'Resonance', 'artist': 'HOME'},
        {'title': 'Reflections', 'artist': 'The Neighbourhood'},
        {'title': 'Chamber of Reflection', 'artist': 'Mac DeMarco'},
        {'title': 'Ylang Ylang', 'artist': 'FKJ'},
      ].take(count).toList();
    } else if (lower.contains('gym') || lower.contains('workout') || lower.contains('hype') || lower.contains('fast')) {
      return [
        {'title': 'Starboy', 'artist': 'The Weeknd'},
        {'title': 'Blinding Lights', 'artist': 'The Weeknd'},
        {'title': 'Levitating', 'artist': 'Dua Lipa'},
        {'title': 'Stronger', 'artist': 'Kanye West'},
        {'title': 'Till I Collapse', 'artist': 'Eminem'},
        {'title': 'Can\'t Hold Us', 'artist': 'Macklemore'},
        {'title': 'Believer', 'artist': 'Imagine Dragons'},
        {'title': 'Industry Baby', 'artist': 'Lil Nas X'},
        {'title': 'Run This Town', 'artist': 'Jay-Z'},
        {'title': 'Lose Yourself', 'artist': 'Eminem'},
        {'title': 'Turn Down for What', 'artist': 'DJ Snake'},
        {'title': 'Animals', 'artist': 'Martin Garrix'},
      ].take(count).toList();
    } else {
      return [
        {'title': 'Cruel Summer', 'artist': 'Taylor Swift'},
        {'title': 'As It Was', 'artist': 'Harry Styles'},
        {'title': 'Shape of You', 'artist': 'Ed Sheeran'},
        {'title': 'Flowers', 'artist': 'Miley Cyrus'},
        {'title': 'Heat Waves', 'artist': 'Glass Animals'},
        {'title': 'Stay', 'artist': 'The Kid LAROI'},
        {'title': 'Save Your Tears', 'artist': 'The Weeknd'},
        {'title': 'Bad Habits', 'artist': 'Ed Sheeran'},
        {'title': 'Good 4 U', 'artist': 'Olivia Rodrigo'},
        {'title': 'Shivers', 'artist': 'Ed Sheeran'},
        {'title': 'Anti-Hero', 'artist': 'Taylor Swift'},
        {'title': 'Daylight', 'artist': 'David Kushner'},
      ].take(count).toList();
    }
  }
}
