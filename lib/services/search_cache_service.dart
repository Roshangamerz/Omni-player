import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

/// 0ms local database/in-memory caching layer for search history and instant query matching
class SearchCacheService {
  static final SearchCacheService _instance = SearchCacheService._internal();
  factory SearchCacheService() => _instance;
  SearchCacheService._internal();

  static const String _historyKey = 'omni_search_history_v1';
  final List<String> _searchHistory = [];
  final Map<String, List<Track>> _memoryQueryCache = {};

  List<String> get searchHistory => _searchHistory.take(4).toList();

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_historyKey);
      if (saved != null) {
        _searchHistory.clear();
        _searchHistory.addAll(saved.take(4));
      }
    } catch (_) {}
  }

  /// 0ms synchronous local search: instantly yields matches from history and memory cache
  List<Track> searchLocalCacheSync(String query, {List<Track> localLibrary = const []}) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final matched = <String, Track>{};

    // 1. Match from in-memory cached network queries
    for (final entry in _memoryQueryCache.entries) {
      if (entry.key.contains(clean) || clean.contains(entry.key)) {
        for (final track in entry.value) {
          if (track.title.toLowerCase().contains(clean) ||
              track.artist.toLowerCase().contains(clean)) {
            matched[track.id] = track;
          }
        }
      }
    }

    // 2. Match from local library / liked tracks
    for (final track in localLibrary) {
      if (track.title.toLowerCase().contains(clean) ||
          track.artist.toLowerCase().contains(clean)) {
        matched[track.id] = track;
      }
    }

    return matched.values.toList();
  }

  /// Synchronously filter matching history queries (latest 4)
  List<String> filterHistorySync(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return _searchHistory.take(4).toList();
    return _searchHistory
        .where((item) => item.toLowerCase().contains(clean))
        .take(4)
        .toList();
  }

  /// Save query to history explicitly on submit (max 4)
  Future<void> addQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty || clean.length < 2) return;

    _searchHistory.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    _searchHistory.insert(0, clean);
    if (_searchHistory.length > 4) {
      _searchHistory.removeRange(4, _searchHistory.length);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, _searchHistory);
    } catch (_) {}
  }

  /// Cache network tracks for query
  void cacheResults(String query, List<Track> tracks) {
    final clean = query.trim().toLowerCase();
    if (clean.isNotEmpty && tracks.isNotEmpty) {
      _memoryQueryCache[clean] = tracks;
    }
  }

  /// Clear a single history item
  Future<void> removeHistoryItem(String query) async {
    _searchHistory.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, _searchHistory);
    } catch (_) {}
  }

  /// Clear all history
  Future<void> clearHistory() async {
    _searchHistory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}
