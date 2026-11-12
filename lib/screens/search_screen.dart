import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/echo_models.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/echo_innertube_service.dart';
import '../services/extension_engine.dart';
import '../services/extension_manager_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';
import 'browse_detail_screen.dart';
import 'omni_find_screen.dart';

/// Echo Music Reconstructed Search & Discovery Screen
/// Features Apple Music Top 100 paginated chart, Country selector, InnerTube Search & Suggestions.
class SearchScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine extensionEngine;
  final AppTheme theme;

  const SearchScreen({
    super.key,
    required this.playerService,
    required this.extensionEngine,
    required this.theme,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchCtrl = TextEditingController();
  final EchoInnerTubeService _ytm = EchoInnerTubeService();

  String _countryCode = 'IN';
  int _topPage = 0;
  List<AppleTopEntry> _appleTopSongs = [];
  List<AppleTopEntry> _appleTopAlbums = [];
  bool _loadingCharts = true;

  Timer? _suggestDebounce;
  List<String> _suggestions = [];
  bool _searching = false;
  String _activeTab = 'Songs';
  List<Track> _songResults = [];
  List<AudioCollection> _collectionResults = [];

  static const Map<String, String> _regions = {
    'IN': 'India',
    'US': 'United States',
    'GB': 'United Kingdom',
    'JP': 'Japan',
    'KR': 'South Korea',
    'DE': 'Germany',
    'BR': 'Brazil',
    'AU': 'Australia',
  };

  @override
  void initState() {
    super.initState();
    _countryCode = _ytm.regionCode;
    _loadCharts();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCharts() async {
    setState(() => _loadingCharts = true);
    final res = await Future.wait([
      _ytm.getAppleMusicTopSongs(country: _countryCode),
      _ytm.getAppleMusicTopAlbums(country: _countryCode),
    ]);
    if (!mounted) return;
    setState(() {
      _appleTopSongs = res[0];
      _appleTopAlbums = res[1];
      _topPage = 0;
      _loadingCharts = false;
    });
  }

  void _onQueryChanged(String val) {
    setState(() {});
    _suggestDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _songResults = [];
        _collectionResults = [];
      });
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 220), () async {
      final list = await _ytm.getSearchSuggestions(val.trim());
      if (mounted && _searchCtrl.text.trim().isNotEmpty) {
        setState(() => _suggestions = list);
      }
    });
  }

  Future<void> _executeSearch(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _suggestions = [];
    });

    try {
      if (_activeTab == 'Songs') {
        final res = await Future.wait([
          _ytm.searchTracks(q, filterParams: EchoInnerTubeService.filterSongs),
          if (ExtensionManagerService().hasEnabledAddons)
            ExtensionManagerService().searchAddons(q),
        ]);
        final merged = <Track>[
          if (res.length > 1) ...res[1],
          ...res[0],
        ];
        if (mounted) setState(() => _songResults = merged);
      } else if (_activeTab == 'Videos') {
        final tracks = await _ytm.searchTracks(q, filterParams: EchoInnerTubeService.filterVideos);
        if (mounted) setState(() => _songResults = tracks);
      } else if (_activeTab == 'All') {
        final tracks = await widget.extensionEngine.searchAcrossAllSources(q);
        if (mounted) setState(() => _songResults = tracks);
      } else {
        final filter = _activeTab == 'Albums'
            ? EchoInnerTubeService.filterAlbums
            : _activeTab == 'Artists'
                ? EchoInnerTubeService.filterArtists
                : EchoInnerTubeService.filterPlaylists;
        final cols = await _ytm.searchCollections(q, filterParams: filter);
        if (mounted) setState(() => _collectionResults = cols);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _playAppleEntry(AppleTopEntry entry) async {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading "${entry.title}"...'),
        duration: const Duration(milliseconds: 900),
      ),
    );
    final hits = await _ytm.searchTracks('${entry.title} ${entry.artist}',
        filterParams: EchoInnerTubeService.filterSongs);
    if (hits.isNotEmpty) {
      await widget.playerService.playTrack(hits.first, playlist: hits);
    }
  }

  void _showRegionPicker(AppTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.isDarkMode ? const Color(0xFF141418) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Charts & Catalog Region',
              style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          for (final e in _regions.entries)
            ListTile(
              title: Text('${e.value} (${e.key})', style: TextStyle(color: theme.textPrimary)),
              trailing: _countryCode == e.key
                  ? Icon(Icons.check_circle_rounded, color: theme.primary)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _countryCode = e.key);
                _ytm.regionCode = e.key;
                _loadCharts();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = AppThemeProvider.of(context);
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    final hasResults =
        (_activeTab == 'Songs' || _activeTab == 'Videos' || _activeTab == 'All')
            ? _songResults.isNotEmpty
            : _collectionResults.isNotEmpty;

    final totalPages = (_appleTopSongs.length / 5).ceil().clamp(1, 20);
    final pageItems = _appleTopSongs.skip(_topPage * 5).take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 155),
      children: [
        // 1. PILL SEARCH BAR + GLOBE REGION PICKER + OMNI FIND MIC
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onQueryChanged,
                  onSubmitted: _executeSearch,
                  style: TextStyle(color: theme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search YouTube Music...',
                    hintStyle: TextStyle(color: theme.textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (hasQuery)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onQueryChanged('');
                  },
                )
              else ...[
                IconButton(
                  tooltip: 'Omni Find (Identify Song)',
                  icon: Icon(Icons.mic_rounded, color: theme.primary, size: 22),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OmniFindScreen(playerService: widget.playerService),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Region: $_countryCode',
                  icon: Icon(Icons.public_rounded, color: theme.textPrimary, size: 22),
                  onPressed: () => _showRegionPicker(theme),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. LIVE SEARCH SUGGESTIONS
        if (_suggestions.isNotEmpty && !hasResults)
          EchoSurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final s in _suggestions.take(8))
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.north_west_rounded, color: theme.textSecondary, size: 18),
                    title: Text(s, style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                    onTap: () {
                      _searchCtrl.text = s;
                      _executeSearch(s);
                    },
                  ),
              ],
            ),
          )
        else if (hasQuery && (hasResults || _searching)) ...[
          // 3. FILTER TABS (Songs, Videos, Albums, Artists, Playlists, All)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tab in const ['Songs', 'Videos', 'Albums', 'Artists', 'Playlists', 'All'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: _activeTab == tab,
                      selectedColor: theme.primary,
                      labelStyle: TextStyle(
                        color: _activeTab == tab ? theme.primaryForeground : theme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        setState(() => _activeTab = tab);
                        _executeSearch(_searchCtrl.text);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_searching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: theme.primary)),
            )
          else if (_activeTab == 'Albums' || _activeTab == 'Artists' || _activeTab == 'Playlists')
            EchoSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final col in _collectionResults)
                    ListTile(
                      leading: EchoArtwork(
                        url: col.artworkUrl,
                        size: 50,
                        radius: _activeTab == 'Artists' ? 25 : 12,
                      ),
                      title: Text(
                        col.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        col.creator,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BrowseDetailScreen(
                            collection: col,
                            playerService: widget.playerService,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            EchoSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final t in _songResults)
                    ListTile(
                      leading: EchoArtwork(url: t.artworkUrl, size: 50, radius: 12),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${t.artist} • ${t.sourcePluginId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary),
                        onPressed: () => showEchoTrackMenu(
                          context,
                          track: t,
                          playerService: widget.playerService,
                          theme: theme,
                        ),
                      ),
                      onTap: () => widget.playerService.playTrack(t, playlist: _songResults),
                    ),
                ],
              ),
            ),
        ] else ...[
          // 4. ECHO MUSIC IDLE STATE: APPLE MUSIC TOP 100 + TRENDING ALBUMS/ARTISTS
          Text(
            'Apple Music Top 100',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${_regions[_countryCode] ?? _countryCode} • Live Chart',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loadingCharts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pageItems.isNotEmpty) ...[
            EchoSurfaceCard(
              borderRadius: 24,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final entry in pageItems)
                    ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${entry.rank}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: entry.rank <= 3 ? theme.primary : theme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          EchoArtwork(url: entry.artworkUrl, size: 48, radius: 12),
                        ],
                      ),
                      title: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        entry.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                      ),
                      onTap: () => _playAppleEntry(entry),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.textPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.chevron_left_rounded, color: theme.textPrimary),
                      onPressed: _topPage > 0 ? () => setState(() => _topPage--) : null,
                    ),
                    Text(
                      '${_topPage + 1} of $totalPages',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.chevron_right_rounded, color: theme.textPrimary),
                      onPressed:
                          _topPage + 1 < totalPages ? () => setState(() => _topPage++) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),
          if (_appleTopAlbums.isNotEmpty) ...[
            Text(
              'Trending Albums & Artists',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 175,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _appleTopAlbums.take(15).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final alb = _appleTopAlbums[i];
                  return GestureDetector(
                    onTap: () {
                      _searchCtrl.text = '${alb.title} ${alb.artist}';
                      setState(() => _activeTab = 'Albums');
                      _executeSearch(_searchCtrl.text);
                    },
                    child: SizedBox(
                      width: 126,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              EchoArtwork(url: alb.artworkUrl, size: 126, radius: 18),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Colors.black.withValues(alpha: 0.72),
                                  child: Text(
                                    '${alb.rank}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            alb.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            alb.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }
}
