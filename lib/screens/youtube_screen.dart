import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/extension_engine.dart';
import '../theme/animated_touch.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_loading.dart';
import 'now_playing_screen.dart';

class YouTubeScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine extensionEngine;
  final AppTheme theme;

  const YouTubeScreen({
    super.key,
    required this.playerService,
    required this.extensionEngine,
    required this.theme,
  });

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Track> _youtubeTracks = [];
  bool _isLoading = false;
  String _selectedCategory = 'Trending Music';

  final List<String> _categories = [
    'Trending Music',
    'Top 100 Music Videos',
    'Live & Acoustic',
    'Lo-Fi & Study Beats',
    'Remixes & Mashups',
    'Chill Anime Beats',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategory('Trending Music');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    String query = 'youtube music trending 2024';
    if (category == 'Trending Music') query = 'trending music video hits';
    if (category == 'Top 100 Music Videos') query = 'top 100 songs billboard';
    if (category == 'Live & Acoustic') query = 'acoustic live performance unplugged';
    if (category == 'Lo-Fi & Study Beats') query = 'lofi hip hop radio beats to relax';
    if (category == 'Remixes & Mashups') query = 'club remix mashup dance';
    if (category == 'Chill Anime Beats') query = 'anime lofi relaxing beats';

    final results = await widget.extensionEngine.search(query);
    if (mounted) {
      setState(() {
        _youtubeTracks = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchYouTube(String query) async {
    if (query.trim().isEmpty) {
      _loadCategory(_selectedCategory);
      return;
    }
    setState(() => _isLoading = true);
    final results = await widget.extensionEngine.search('$query youtube');
    if (mounted) {
      setState(() {
        _youtubeTracks = results;
        _isLoading = false;
      });
    }
  }

  void _openPlayer(Track track, List<Track> playlist) {
    widget.playerService.playTrack(track, playlist: playlist);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NowPlayingScreen(
        playerService: widget.playerService,
        theme: widget.theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ytRed = Color(0xFFFF0033);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // YouTube Header Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ytRed.withValues(alpha: 0.18),
                              border: Border.all(color: ytRed.withValues(alpha: 0.5)),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: ytRed, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YouTube Music',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Trending Videos & Live Streams',
                                style: TextStyle(fontSize: 12, color: Colors.white60),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ytRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ytRed.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Live Audio', style: TextStyle(color: ytRed, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // YouTube Search Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      cursorColor: ytRed,
                      onSubmitted: _searchYouTube,
                      decoration: InputDecoration(
                        hintText: 'Search YouTube Music videos, remixes, lives...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: ytRed, size: 22),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _loadCategory(_selectedCategory);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // YouTube Category Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AnimatedTouch(
                            onTap: () => _loadCategory(cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? ytRed : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSel ? ytRed : Colors.white12,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Track List or Loading
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: AnimatedLoadingWidget(
                  theme: widget.theme,
                  message: 'Connecting to YouTube Music Streams...',
                  size: 65,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _youtubeTracks[index];
                    final isPlayingThis = widget.playerService.currentTrack?.id == track.id;
                    final isLiked = widget.playerService.isTrackLiked(track.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: AnimatedTouch(
                        onTap: () => _openPlayer(track, _youtubeTracks),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPlayingThis
                                ? ytRed.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPlayingThis
                                  ? ytRed.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isPlayingThis ? ytRed : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  track.artworkUrl,
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, error, stackTrace) => Container(
                                    width: 46,
                                    height: 46,
                                    color: Colors.white10,
                                    child: const Icon(Icons.play_circle_filled, color: ytRed),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isPlayingThis ? ytRed : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isLiked ? Colors.redAccent : Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () => widget.playerService.toggleLike(track),
                              ),
                              Icon(
                                isPlayingThis && widget.playerService.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: ytRed,
                                size: 34,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _youtubeTracks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
