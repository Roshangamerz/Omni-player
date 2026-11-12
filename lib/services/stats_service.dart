import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class TrackStatEntry {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  int playCount;
  int totalListenSeconds;

  TrackStatEntry({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    this.playCount = 0,
    this.totalListenSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artworkUrl': artworkUrl,
        'playCount': playCount,
        'totalListenSeconds': totalListenSeconds,
      };

  factory TrackStatEntry.fromJson(Map<String, dynamic> json) => TrackStatEntry(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Unknown',
        artist: json['artist']?.toString() ?? 'Unknown Artist',
        artworkUrl: json['artworkUrl']?.toString() ?? '',
        playCount: (json['playCount'] as num?)?.toInt() ?? 0,
        totalListenSeconds: (json['totalListenSeconds'] as num?)?.toInt() ?? 0,
      );
}

/// Echo Music Listening Stats & Omni Wrapped Engine
class StatsService extends ChangeNotifier {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  static const String _statsKey = 'omni_listening_stats_v1';
  final Map<String, TrackStatEntry> _entries = {};

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _entries.clear();
        for (final item in list) {
          final entry = TrackStatEntry.fromJson(item as Map<String, dynamic>);
          if (entry.id.isNotEmpty) _entries[entry.id] = entry;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> recordPlay(Track track) async {
    final existing = _entries[track.id];
    if (existing != null) {
      existing.playCount++;
      existing.totalListenSeconds += track.duration.inSeconds > 0 ? track.duration.inSeconds : 180;
    } else {
      _entries[track.id] = TrackStatEntry(
        id: track.id,
        title: track.title,
        artist: track.artist,
        artworkUrl: track.artworkUrl,
        playCount: 1,
        totalListenSeconds: track.duration.inSeconds > 0 ? track.duration.inSeconds : 180,
      );
    }
    await _save();
    notifyListeners();
  }

  List<TrackStatEntry> get topTracks {
    final list = _entries.values.toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return list;
  }

  List<({String artist, int plays, int minutes, String artworkUrl})> get topArtists {
    final map = <String, ({int plays, int seconds, String artworkUrl})>{};
    for (final e in _entries.values) {
      final artist = e.artist.split(RegExp(r'[,&•]')).first.trim();
      if (artist.isEmpty) continue;
      final cur = map[artist];
      map[artist] = (
        plays: (cur?.plays ?? 0) + e.playCount,
        seconds: (cur?.seconds ?? 0) + e.totalListenSeconds,
        artworkUrl: cur?.artworkUrl.isNotEmpty == true ? cur!.artworkUrl : e.artworkUrl,
      );
    }
    final list = map.entries
        .map((e) => (
              artist: e.key,
              plays: e.value.plays,
              minutes: (e.value.seconds / 60).round(),
              artworkUrl: e.value.artworkUrl,
            ))
        .toList()
      ..sort((a, b) => b.plays.compareTo(a.plays));
    return list;
  }

  int get totalPlays => _entries.values.fold(0, (sum, e) => sum + e.playCount);
  int get totalMinutes =>
      (_entries.values.fold(0, (sum, e) => sum + e.totalListenSeconds) / 60).round();
  int get uniqueSongs => _entries.length;

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _statsKey, jsonEncode(_entries.values.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}
