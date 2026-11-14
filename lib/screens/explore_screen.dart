import 'package:flutter/material.dart';
import '../models/echo_models.dart';
import '../models/track.dart';
import '../services/ai_playlist_service.dart';
import '../services/audio_player_service.dart';
import '../services/echo_innertube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/echo_components.dart';
import 'browse_detail_screen.dart';

/// Echo Music Explore Tab (New Releases, Top Charts, Moods & Genres from YouTube Music InnerTube)
class ExploreScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final AppTheme theme;

  const ExploreScreen({
    super.key,
    required this.playerService,
    required this.theme,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  EchoExploreData _data = const EchoExploreData();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExplore();
  }

  Future<void> _loadExplore() async {
    setState(() => _loading = true);
    final res = await EchoInnerTubeService().getExploreData();
    if (!mounted) return;
    setState(() {
      _data = res;
      _loading = false;
    });
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

  void _showAiPlaylistGenerator(BuildContext context) {
    final promptCtrl = TextEditingController();
    bool isGenerating = false;
    final theme = widget.theme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.isDarkMode ? const Color(0xFF141418) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.primary, theme.primary.withValues(alpha: 0.6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Mood Playlist Generator',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Echo Music AI • Weather & Acoustic Vibe Matching',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Rainy drive at midnight, cyberpunk workout, chill indie',
                  hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: theme.isDarkMode ? const Color(0xFF1C1C22) : const Color(0xFFF2F2F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final mood in [
                    '🌙 Late Night Lo-Fi',
                    '⚡ Cyberpunk Synth',
                    '☕ Coffee Shop Indie',
                    '🌧️ Melancholic Rain',
                    '🔥 High Energy Gym',
                  ])
                    ActionChip(
                      label: Text(mood, style: const TextStyle(fontSize: 11)),
                      backgroundColor: theme.isDarkMode ? const Color(0xFF1E1E26) : const Color(0xFFEAEAEE),
                      onPressed: () {
                        promptCtrl.text = mood;
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isGenerating
                      ? null
                      : () async {
                          final prompt = promptCtrl.text.trim();
                          if (prompt.isEmpty) return;
                          setModalState(() => isGenerating = true);
                          try {
                            final tracks = await AiPlaylistService().generatePlaylistFromPrompt(
                              userPrompt: prompt,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (tracks.isNotEmpty) {
                              widget.playerService.playTrack(tracks.first, playlist: tracks);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Playing AI Playlist: ${tracks.length} tracks')),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not generate tracks. Check connection.')),
                                );
                              }
                            }
                          } catch (e) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('AI Error: $e')),
                              );
                            }
                          }
                        },
                  icon: isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.play_arrow_rounded, color: Colors.black),
                  label: Text(
                    isGenerating ? 'Curating AI Playlist...' : 'Generate & Play',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = widget.theme;

    return RefreshIndicator(
      onRefresh: _loadExplore,
      color: theme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
                onPressed: _loadExplore,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Echo Music AI Mood Playlist Generator Banner
          GestureDetector(
            onTap: () => _showAiPlaylistGenerator(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withValues(alpha: 0.25),
                    theme.primary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: theme.primary.withValues(alpha: 0.3), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate AI Mood Playlist',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Custom mix matched to your vibe & weather',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: theme.primary, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: theme.primary)),
            )
          else ...[
            if (_data.newReleaseAlbums.isNotEmpty) ...[
              Text(
                'NEW RELEASES',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 206,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _data.newReleaseAlbums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final album = _data.newReleaseAlbums[i];
                    return GestureDetector(
                      onTap: () => _openCollection(album),
                      child: SizedBox(
                        width: 148,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EchoArtwork(url: album.artworkUrl, size: 148, radius: 20),
                            const SizedBox(height: 8),
                            Text(
                              album.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              album.creator,
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
              const SizedBox(height: 22),
            ],

            for (final sec in _data.chartSections) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sec.title.toUpperCase(),
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
                      child: Text('Play all', style: TextStyle(color: theme.primary)),
                    ),
                ],
              ),
              if (sec.tracks.isNotEmpty)
                EchoSurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (int i = 0; i < sec.tracks.take(6).length; i++)
                        ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '${i + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: i < 3 ? theme.primary : theme.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              EchoArtwork(url: sec.tracks[i].artworkUrl, size: 46, radius: 12),
                            ],
                          ),
                          title: Text(
                            sec.tracks[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            sec.tracks[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.textSecondary, fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary),
                            onPressed: () => showEchoTrackMenu(
                              context,
                              track: sec.tracks[i],
                              playerService: widget.playerService,
                              theme: theme,
                            ),
                          ),
                          onTap: () => widget.playerService
                              .playTrack(sec.tracks[i], playlist: sec.tracks),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),
            ],

            if (_data.moodsAndGenres.isNotEmpty) ...[
              Text(
                'MOODS & GENRES',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _data.moodsAndGenres.take(24).length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.8,
                ),
                itemBuilder: (_, i) {
                  final mg = _data.moodsAndGenres[i];
                  final stripe = Color(mg.stripeColorValue | 0xFF000000);
                  return EchoSurfaceCard(
                    borderRadius: 16,
                    padding: EdgeInsets.zero,
                    onTap: () => _openCollection(AudioCollection(
                      id: mg.browseId,
                      params: mg.params,
                      title: mg.title,
                      creator: 'Mood & Genre',
                      type: 'playlist',
                      artworkUrl: '',
                      tracks: const [],
                    )),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          decoration: BoxDecoration(
                            color: stripe,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mg.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
