import 'dart:async';
import '../models/track.dart';
import 'extension_engine.dart';
import 'innertube_service.dart';
import 'search_cache_service.dart';

class SearchResultState {
  final String query;
  final List<Track> tracks;
  final List<String> suggestions;
  final List<String> historySuggestions;
  final List<AudioCollection> collections;
  final bool isLoading;
  final bool isLocalInstant;

  const SearchResultState({
    required this.query,
    required this.tracks,
    required this.suggestions,
    required this.historySuggestions,
    required this.collections,
    required this.isLoading,
    required this.isLocalInstant,
  });

  factory SearchResultState.empty() => const SearchResultState(
        query: '',
        tracks: [],
        suggestions: [],
        historySuggestions: [],
        collections: [],
        isLoading: false,
        isLocalInstant: false,
      );
}

/// Ultra-Lean, High-Performance Unified Search Engine
class UnifiedSearchService {
  static final UnifiedSearchService _instance = UnifiedSearchService._internal();
  factory UnifiedSearchService() => _instance;
  UnifiedSearchService._internal();

  final InnerTubeService _innerTubeService = InnerTubeService();
  final SearchCacheService _cacheService = SearchCacheService();
  final ExtensionEngine _extensionEngine = ExtensionEngine();

  Timer? _debounceTimer;
  int _searchSequence = 0;

  static final RegExp _spacesRegex = RegExp(r'\s+');

  final StreamController<SearchResultState> _stateController =
      StreamController<SearchResultState>.broadcast();

  Stream<SearchResultState> get searchStream => _stateController.stream;

  /// Initiate search with clean debounce and smooth results delivery without screen jumping
  void query(
    String queryString, {
    String sourceFilter = 'All',
    List<Track> localLibrary = const [],
  }) {
    final clean = queryString.trim();

    if (clean.isEmpty) {
      _debounceTimer?.cancel();
      _searchSequence++;
      _stateController.add(SearchResultState.empty());
      return;
    }

    // Emit suggestions for instant typing feedback without swapping out tracks under user's fingers
    final instantHistory = _cacheService.filterHistorySync(clean);
    final cachedNetworkTracks = _cacheService.searchLocalCacheSync(clean, localLibrary: localLibrary);

    _stateController.add(
      SearchResultState(
        query: clean,
        tracks: cachedNetworkTracks,
        suggestions: instantHistory,
        historySuggestions: instantHistory,
        collections: const [],
        isLoading: true,
        isLocalInstant: cachedNetworkTracks.isNotEmpty,
      ),
    );

    // Fast 220ms debounce
    _debounceTimer?.cancel();
    final seq = ++_searchSequence;

    _debounceTimer = Timer(const Duration(milliseconds: 220), () async {
      if (seq != _searchSequence) return;
      await _executeNetworkSearch(clean, sourceFilter, seq);
    });
  }

  Future<void> _executeNetworkSearch(String query, String sourceFilter, int seq) async {
    try {
      final qLower = query.toLowerCase().trim();
      final qTokens = qLower.split(_spacesRegex).where((s) => s.isNotEmpty).toList();

      // Parallel async requests: Instant Apple Music Catalog + YouTube Music + Collections + Suggestions
      final Future<List<Track>> appleFuture = (sourceFilter == 'All' || sourceFilter == 'Apple' || sourceFilter == 'Spotify' || sourceFilter == 'JioSaavn')
          ? ITunesMusicSource().searchTracks(query).catchError((_) => <Track>[])
          : Future.value(const []);

      final Future<List<Track>> ytFuture = (sourceFilter == 'All' || sourceFilter == 'YouTube')
          ? _innerTubeService.searchTracks(query).catchError((_) => <Track>[])
          : Future.value(const []);

      final Future<List<String>> suggestionsFuture =
          _innerTubeService.getSearchSuggestions(query).catchError((_) => <String>[]);

      final Future<List<AudioCollection>> collFuture =
          _extensionEngine.searchCollections(query).catchError((_) => <AudioCollection>[]);

      final results = await Future.wait([appleFuture, ytFuture, suggestionsFuture, collFuture]);

      // Guard: Discard stale response if a newer query was fired while awaiting
      if (seq != _searchSequence) return;

      final appleTracks = results[0] as List<Track>;
      final ytTracks = results[1] as List<Track>;
      final suggestions = results[2] as List<String>;
      final networkCollections = results[3] as List<AudioCollection>;

      // Filter corrupt/blank titles and tracks under 40s (shorts/clips)
      final validTracks = <Track>[];
      for (int i = 0; i < appleTracks.length; i++) {
        final t = appleTracks[i];
        if (t.title.trim().length > 1 && (t.duration == Duration.zero || t.duration.inSeconds >= 40)) {
          validTracks.add(t);
        }
      }
      for (int i = 0; i < ytTracks.length; i++) {
        final t = ytTracks[i];
        if (t.title.trim().length > 1 && (t.duration == Duration.zero || t.duration.inSeconds >= 40)) {
          validTracks.add(t);
        }
      }

      // Synthesize album collections from returned tracks if missing
      final collections = List<AudioCollection>.from(networkCollections);
      final seenCollTitles = collections.map((c) => c.title.toLowerCase()).toSet();

      final albumGroups = <String, List<Track>>{};
      for (final t in validTracks) {
        if (t.album.isNotEmpty && !t.album.toLowerCase().contains('single') && !t.album.toLowerCase().contains('stream')) {
          albumGroups.putIfAbsent(t.album, () => []).add(t);
        }
      }

      for (final entry in albumGroups.entries) {
        if (entry.value.length >= 2 && !seenCollTitles.contains(entry.key.toLowerCase())) {
          seenCollTitles.add(entry.key.toLowerCase());
          final first = entry.value.first;
          final isOst = entry.key.toLowerCase().contains('ost') ||
              entry.key.toLowerCase().contains('soundtrack') ||
              entry.key.toLowerCase().contains('movie');
          final isEp = entry.key.toLowerCase().contains('ep') || entry.value.length <= 6;

          collections.add(
            AudioCollection(
              id: 'synth_${first.id}',
              title: entry.key,
              creator: first.artist,
              type: isOst ? 'soundtrack' : (isEp ? 'ep' : 'album'),
              artworkUrl: first.artworkUrl,
              tracks: entry.value,
            ),
          );
        }
      }

      // Fast relevance score calculation optimized for Indian perspective and high-speed audio
      int computeScore(Track t) {
        final tLower = t.title.toLowerCase();
        final aLower = t.artist.toLowerCase();
        final tFull = '$tLower $aLower ${t.album.toLowerCase()}';
        int score = 0;

        if (tLower == qLower) {
          score += 250;
        } else if (tLower.startsWith(qLower)) {
          score += 150;
        } else if (tLower.contains(qLower)) {
          score += 90;
        }

        if (aLower.contains(qLower)) {
          score += 120;
        }

        for (int i = 0; i < qTokens.length; i++) {
          final tok = qTokens[i];
          if (tLower.contains(tok)) score += 35;
          if (aLower.contains(tok)) score += 25;
        }

        // Boost for studio master / verified tracks
        if (t.streamUrl.isNotEmpty) {
          score += 40;
        }

        // MASSIVE BOOST for Indian Music Artists, Bollywood, Punjabi, South Indian & Desi Hip-Hop
        final indianArtists = [
          'arijit', 'pritam', 'shreya', 'diljit', 'karan aujla', 'sidhu moose', 'ap dhillon',
          'anirudh', 'ar rahman', 'sid sriram', 'vishal', 'shekhar', 'sachin-jigar', 'mithoon',
          'kk', 'atif aslam', 'mohit chauhan', 'sonu nigam', 'kumar sanu', 'alka yagnik',
          'udit narayan', 'sunidhi', 'jubin nautiyal', 'neha kakkar', 'badshah', 'honey singh',
          'seedhe maut', 'krsna', 'kr\$na', 'divine', 'raftaar', 'mc stan', 'king', 'shubh',
          'jasleen royal', 'anuv jain', 'prateek kuhad', 'aditya rikhari', 'chaar diwaari',
          'b praak', 'jaani', 'guru randhawa', 'ammy virk', 'jordan sandhu', 'devi sri prasad',
          'gv prakash', 'santhosh narayanan', 'harris jayaraj', 'yuvan', 'thaman', 'sushin shyam',
          'hesham abdul', 'ilaiyaraaja', 't-series', 'zee music', 'sony music india', 'yrf',
          'tips', 'saregama', 'speed records', 'desi music factory', 'white hill', 'lahari', 'aditya'
        ];

        for (final artistKeyword in indianArtists) {
          if (aLower.contains(artistKeyword) || tLower.contains(artistKeyword)) {
            score += 120;
            break;
          }
        }

        // Boost for Indian Movie OSTs & Regional Musical Dialects
        final indianMusicTags = [
          'bollywood', 'hindi', 'punjabi', 'tamil', 'telugu', 'malayalam', 'kannada',
          'movie', 'soundtrack', 'ost', 'qawwali', 'sufi', 'bhajan', 'lo-fi', 'lofi chill',
          'animal', 'jawan', 'stree', 'pushpa', 'devara', 'leo', 'jailer', 'kabir singh',
          'rockstar', 'aashiqui', 'shershaah', 'brahmastra', 'kedarnath', 'tamasha'
        ];

        for (final tag in indianMusicTags) {
          if (tFull.contains(tag)) {
            score += 60;
            break;
          }
        }

        return score;
      }

      validTracks.sort((a, b) => computeScore(b).compareTo(computeScore(a)));

      // Deduplicate by ID
      final combinedTracks = <Track>[];
      final seenIds = <String>{};
      for (int i = 0; i < validTracks.length; i++) {
        final track = validTracks[i];
        if (seenIds.add(track.id)) {
          combinedTracks.add(track);
        }
      }

      // Cache network results in bounded memory
      _cacheService.cacheResults(query, combinedTracks);

      if (seq == _searchSequence) {
        _stateController.add(
          SearchResultState(
            query: query,
            tracks: combinedTracks,
            suggestions: suggestions.isNotEmpty ? suggestions : _cacheService.filterHistorySync(query),
            historySuggestions: _cacheService.filterHistorySync(query),
            collections: collections,
            isLoading: false,
            isLocalInstant: false,
          ),
        );
      }
    } catch (_) {
      if (seq == _searchSequence) {
        _stateController.add(
          SearchResultState(
            query: query,
            tracks: const [],
            suggestions: const [],
            historySuggestions: _cacheService.filterHistorySync(query),
            collections: const [],
            isLoading: false,
            isLocalInstant: false,
          ),
        );
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _stateController.close();
    _innerTubeService.dispose();
  }
}
