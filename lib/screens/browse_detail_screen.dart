import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/echo_innertube_service.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';

/// Echo Music Album / Playlist / Artist / Mood Browse Detail Screen
class BrowseDetailScreen extends StatefulWidget {
  final AudioCollection collection;
  final AudioPlayerService playerService;

  const BrowseDetailScreen({
    super.key,
    required this.collection,
    required this.playerService,
  });

  @override
  State<BrowseDetailScreen> createState() => _BrowseDetailScreenState();
}

class _BrowseDetailScreenState extends State<BrowseDetailScreen> {
  late AudioCollection _collection;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    if (_collection.tracks.isEmpty && _collection.id.isNotEmpty) {
      _loadRemote();
    }
  }

  Future<void> _loadRemote() async {
    setState(() => _loading = true);
    final res = await EchoInnerTubeService().browseDetail(
      _collection.id,
      params: _collection.params,
      fallbackTitle: _collection.title,
    );
    if (!mounted) return;
    setState(() {
      _collection = AudioCollection(
        id: res.id,
        title: res.title.isNotEmpty ? res.title : _collection.title,
        creator: res.creator.isNotEmpty ? res.creator : _collection.creator,
        type: res.type,
        artworkUrl: res.artworkUrl.isNotEmpty ? res.artworkUrl : _collection.artworkUrl,
        tracks: res.tracks,
        params: res.params,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);
    final tracks = _collection.tracks;

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textPrimary,
          title: Text(
            _collection.type.toUpperCase(),
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: theme.primary))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  Center(
                    child: EchoArtwork(
                      url: _collection.artworkUrl,
                      size: 210,
                      radius: 24,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _collection.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_collection.creator} • ${tracks.length} tracks',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: theme.primaryForeground,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: tracks.isEmpty
                            ? null
                            : () => widget.playerService.playTrack(tracks.first, playlist: tracks),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textPrimary,
                          side: BorderSide(color: theme.textSecondary.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: tracks.isEmpty
                            ? null
                            : () {
                                final shuffled = List<Track>.from(tracks)..shuffle();
                                widget.playerService.playTrack(shuffled.first, playlist: shuffled);
                              },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('Shuffle'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Download All',
                        icon: Icon(Icons.download_for_offline_outlined, color: theme.textPrimary),
                        onPressed: tracks.isEmpty
                            ? null
                            : () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Downloading ${tracks.length} tracks...')),
                                );
                                for (final t in tracks.take(15)) {
                                  await DownloadService().downloadTrack(t);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (tracks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No tracks found in this collection.',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                      ),
                    )
                  else
                    EchoSurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (int i = 0; i < tracks.length; i++)
                            ListTile(
                              leading: EchoArtwork(url: tracks[i].artworkUrl, size: 48, radius: 12),
                              title: Text(
                                tracks[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                tracks[i].artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: theme.textSecondary, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary),
                                onPressed: () => showEchoTrackMenu(
                                  context,
                                  track: tracks[i],
                                  playerService: widget.playerService,
                                  theme: theme,
                                ),
                              ),
                              onTap: () => widget.playerService.playTrack(
                                tracks[i],
                                playlist: tracks,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
