import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/echo_models.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/echo_innertube_service.dart';
import '../services/extension_engine.dart';
import '../services/weather_ambient_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';
import '../widgets/omni_logo.dart';
import 'browse_detail_screen.dart';
import 'listen_together_screen.dart';
import 'omni_find_screen.dart';
import 'settings_screen.dart';
import 'stats_wrapped_screen.dart';

/// Echo Music Reconstructed Home Screen — Keeps Omni Player's own Logo & Branding
class HomeScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine extensionEngine;
  final AppTheme theme;
  final ValueChanged<int> onNavigateTab;

  const HomeScreen({
    super.key,
    required this.playerService,
    required this.extensionEngine,
    required this.theme,
    required this.onNavigateTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  EchoHomeFeed _feed = const EchoHomeFeed();
  List<Track> _quickPicks = [];
  WeatherSnapshot? _weather;
  bool _loading = true;
  int _selectedChipIndex = -1;
  final PageController _heroCtrl = PageController(viewportFraction: 0.84);

  @override
  void initState() {
    super.initState();
    _quickPicks = widget.extensionEngine.curatedTracks;
    widget.playerService.addListener(_onServiceChange);
    _loadInitial();
  }

  @override
  void dispose() {
    widget.playerService.removeListener(_onServiceChange);
    _heroCtrl.dispose();
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitial({String? moodParams}) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        EchoInnerTubeService().getHomeFeed(params: moodParams),
        WeatherAmbientService().getCurrentWeatherMood(),
      ]);
      final feed = results[0] as EchoHomeFeed;
      final weather = results[1] as WeatherSnapshot?;

      final harvestedTracks = <Track>[];
      for (final sec in feed.sections) {
        harvestedTracks.addAll(sec.tracks);
      }
      if (harvestedTracks.isEmpty) {
        final fallback = await EchoInnerTubeService().searchTracks('top trending music 2026');
        harvestedTracks.addAll(fallback);
      }

      if (!mounted) return;
      setState(() {
        _feed = feed;
        if (weather != null) _weather = weather;
        if (harvestedTracks.isNotEmpty) _quickPicks = harvestedTracks;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCollection(AudioCollection col) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowseDetailScreen(
          collection: col,
          playerService: widget.playerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = AppThemeProvider.of(context);
    final history = widget.playerService.history;

    final chips = _feed.chips.isNotEmpty
        ? _feed.chips
        : const [
            EchoMoodChip(title: 'Feel good'),
            EchoMoodChip(title: 'Romance'),
            EchoMoodChip(title: 'Relax'),
            EchoMoodChip(title: 'Party'),
            EchoMoodChip(title: 'Energize'),
            EchoMoodChip(title: 'Focus'),
          ];

    final heroTracks = _quickPicks.take(8).toList();
    final forgottenFavorites =
        history.isNotEmpty ? history.take(6).toList() : _quickPicks.skip(2).take(6).toList();

    return RefreshIndicator(
      onRefresh: () => _loadInitial(),
      color: theme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 155),
        children: [
          // 1. ECHO-STYLE TOP HEADER WITH OMNI PLAYER LOGO & QUICK TOOLS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const OmniLogo(size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Omni Player',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Omni Find (Shazam)',
                  icon: Icon(Icons.mic_rounded, color: theme.textPrimary, size: 22),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OmniFindScreen(playerService: widget.playerService),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Stats & Omni Wrapped',
                  icon: Icon(Icons.auto_graph_rounded, color: theme.textPrimary, size: 22),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatsWrappedScreen(playerService: widget.playerService),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Listen Together',
                  icon: Icon(Icons.groups_rounded, color: theme.textPrimary, size: 22),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListenTogetherScreen(playerService: widget.playerService),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        playerService: widget.playerService,
                        extensionEngine: widget.extensionEngine,
                        theme: theme,
                      ),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: theme.primary.withValues(alpha: 0.22),
                    child: Icon(Icons.settings_rounded, color: theme.primary, size: 19),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 2. MOOD CHIPS ROW (InnerTube Home Chips)
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _selectedChipIndex == i;
                final chip = chips[i];
                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    if (selected) {
                      setState(() => _selectedChipIndex = -1);
                      _loadInitial();
                    } else {
                      setState(() => _selectedChipIndex = i);
                      if (chip.params != null && chip.params!.isNotEmpty) {
                        _loadInitial(moodParams: chip.params);
                      } else {
                        final res = await EchoInnerTubeService().searchTracks('${chip.title} music');
                        if (mounted && res.isNotEmpty) {
                          setState(() => _quickPicks = res);
                        }
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.primary
                          : theme.textPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        chip.title,
                        style: TextStyle(
                          color: selected ? theme.primaryForeground : theme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 3. WEATHER AMBIENT PILL (Reverse-Engineered from Echo Music WeatherRepository)
          if (_weather != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: EchoSurfaceCard(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () async {
                  final tracks =
                      await EchoInnerTubeService().searchTracks(_weather!.recommendedQuery);
                  if (tracks.isNotEmpty) {
                    await widget.playerService.playTrack(tracks.first, playlist: tracks);
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      _weather!.isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                      color: theme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_weather!.city} • ${_weather!.tempC.round()}°C • ${_weather!.moodLabel} Mix',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.play_arrow_rounded, color: theme.primary),
                  ],
                ),
              ),
            ),

          // 4. CENTERED HERO CAROUSEL (Echo Music Home.png Signature)
          if (_loading && heroTracks.isEmpty)
            const SizedBox(
              height: 270,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (heroTracks.isNotEmpty)
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _heroCtrl,
                itemCount: heroTracks.length,
                itemBuilder: (_, i) {
                  final t = heroTracks[i];
                  return GestureDetector(
                    onTap: () => widget.playerService.playTrack(t, playlist: heroTracks),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EchoArtwork(url: t.artworkUrl, size: 420, radius: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 18),

          // 5. MUSIC FLOW ENTRY CARD (Echo DESIGN.md spec)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EchoSurfaceCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              onTap: () => widget.onNavigateTab(1),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.textPrimary,
                    child: Icon(Icons.graphic_eq_rounded, color: theme.scaffoldBg, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Music Flow',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Vertical swipe discovery with live synced lyrics & canvas',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: theme.textSecondary, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // 6. FORGOTTEN FAVORITES / QUICK PICKS (Grouped Translucent List Card)
          if (forgottenFavorites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    history.isNotEmpty ? 'FORGOTTEN FAVORITES' : 'QUICK PICKS',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textPrimary,
                      side: BorderSide(color: theme.textSecondary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => widget.playerService.playTrack(
                      forgottenFavorites.first,
                      playlist: forgottenFavorites,
                    ),
                    child: const Text('Play all', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EchoSurfaceCard(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final t in forgottenFavorites)
                      ListTile(
                        leading: EchoArtwork(url: t.artworkUrl, size: 48, radius: 12),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          t.artist,
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
                        onTap: () => widget.playerService.playTrack(t, playlist: forgottenFavorites),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],

          // 7. DYNAMIC YOUTUBE MUSIC INNERTUBE HOME SHELVES
          for (final sec in _feed.sections) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sec.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (sec.tracks.isNotEmpty)
                    TextButton(
                      onPressed: () => widget.playerService
                          .playTrack(sec.tracks.first, playlist: sec.tracks),
                      child: Text('Play all', style: TextStyle(color: theme.primary, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (sec.collections.isNotEmpty)
              SizedBox(
                height: 204,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: sec.collections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final col = sec.collections[i];
                    return GestureDetector(
                      onTap: () => _openCollection(col),
                      child: SizedBox(
                        width: 146,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EchoArtwork(url: col.artworkUrl, size: 146, radius: 20),
                            const SizedBox(height: 8),
                            Text(
                              col.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              col.creator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              SizedBox(
                height: 204,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: sec.tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final tr = sec.tracks[i];
                    return GestureDetector(
                      onTap: () => widget.playerService.playTrack(tr, playlist: sec.tracks),
                      onLongPress: () => showEchoTrackMenu(
                        context,
                        track: tr,
                        playerService: widget.playerService,
                        theme: theme,
                      ),
                      child: SizedBox(
                        width: 146,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EchoArtwork(url: tr.artworkUrl, size: 146, radius: 20),
                            const SizedBox(height: 8),
                            Text(
                              tr.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              tr.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
