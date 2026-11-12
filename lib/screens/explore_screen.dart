import 'package:flutter/material.dart';
import '../models/echo_models.dart';
import '../models/track.dart';
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
