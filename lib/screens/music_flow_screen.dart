import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/echo_innertube_service.dart';
import '../services/extension_engine.dart';
import '../services/lyrics_service.dart';
import '../services/odesli_service.dart';
import '../theme/app_theme.dart';
import '../widgets/canvas_artwork_player.dart';
import '../widgets/echo_components.dart';

/// Echo Music "Music Flow" — Resso-Style Vertical Swipe Discovery
/// Implements Echo Music DESIGN.md spec: full-bleed blurred backdrop, sharp 24dp artwork/canvas,
/// top 2-line animated synced lyrics, bottom metadata + View Artist pill, right action rail, 2dp progress bar.
class MusicFlowScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine extensionEngine;
  final AppTheme theme;
  final VoidCallback? onOpenFullPlayer;

  const MusicFlowScreen({
    super.key,
    required this.playerService,
    required this.extensionEngine,
    required this.theme,
    this.onOpenFullPlayer,
  });

  @override
  State<MusicFlowScreen> createState() => _MusicFlowScreenState();
}

class _MusicFlowScreenState extends State<MusicFlowScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final PageController _pageController = PageController();
  final List<Track> _feed = [];
  int _activeIndex = 0;
  bool _loading = true;
  bool _showLyricsOverlay = true;
  List<LyricLine> _currentLyrics = const [];
  String _lyricsTrackId = '';

  @override
  void initState() {
    super.initState();
    widget.playerService.addListener(_onPlayerUpdate);
    _loadFlowFeed();
  }

  @override
  void dispose() {
    widget.playerService.removeListener(_onPlayerUpdate);
    _pageController.dispose();
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final cur = widget.playerService.currentTrack;
    if (cur != null && cur.id != _lyricsTrackId) {
      _loadLyricsFor(cur);
    }
    setState(() {});
  }

  Future<void> _loadFlowFeed() async {
    setState(() => _loading = true);
    try {
      final seed = widget.playerService.currentTrack;
      List<Track> tracks = [];
      if (seed != null && seed.cleanVideoId.length == 11) {
        tracks = await EchoInnerTubeService().getNextRadioTracks(seed.cleanVideoId);
      }
      if (tracks.isEmpty) {
        tracks = await EchoInnerTubeService().searchTracks('trending hits 2026');
      }
      if (tracks.isEmpty) {
        tracks = widget.extensionEngine.curatedTracks;
      }
      final validTracks = tracks
          .where((t) => t.duration == Duration.zero || t.duration.inSeconds >= 40)
          .toList();
      if (!mounted) return;
      setState(() {
        _feed
          ..clear()
          ..addAll(validTracks);
        _loading = false;
      });
      if (_feed.isNotEmpty) {
        _loadLyricsFor(_feed.first);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (index >= _feed.length - 3 && _feed.isNotEmpty) {
      final last = _feed.last;
      final more = await EchoInnerTubeService().getNextRadioTracks(last.cleanVideoId);
      if (mounted && more.isNotEmpty) {
        setState(() {
          for (final t in more) {
            if (!_feed.any((e) => e.id == t.id)) _feed.add(t);
          }
        });
      }
    }
  }

  Future<void> _loadLyricsFor(Track track) async {
    _lyricsTrackId = track.id;
    final res = await LyricsService.fetchRichLyrics(track);
    if (!mounted || _lyricsTrackId != track.id) return;
    setState(() => _currentLyrics = res.isFallback ? const [] : res.lines);
  }

  (String current, String next) _activeLyricPair() {
    if (_currentLyrics.isEmpty) return ('', '');
    final pos = widget.playerService.position;
    int idx = 0;
    for (int i = 0; i < _currentLyrics.length; i++) {
      if (_currentLyrics[i].time <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    final cur = _currentLyrics[idx].text;
    final nxt = idx + 1 < _currentLyrics.length ? _currentLyrics[idx + 1].text : '';
    return (cur, nxt);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: widget.theme.primary),
            const SizedBox(height: 12),
            Text('Loading Music Flow...', style: TextStyle(color: widget.theme.textSecondary)),
          ],
        ),
      );
    }

    if (_feed.isEmpty) {
      return Center(
        child: FilledButton(
          onPressed: _loadFlowFeed,
          child: const Text('Reload Music Flow'),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _feed.length,
          onPageChanged: (idx) {
            setState(() => _activeIndex = idx);
            final track = _feed[idx];
            widget.playerService.playTrack(track, playlist: _feed);
            _loadLyricsFor(track);
            _loadMoreIfNeeded(idx);
          },
          itemBuilder: (context, idx) {
            final track = _feed[idx];
            final isCurrent = widget.playerService.currentTrack?.id == track.id;
            final isPlaying = isCurrent && widget.playerService.isPlaying;
            final isLiked = widget.playerService.isTrackLiked(track.id);
            final isDownloaded = DownloadService().isDownloaded(track.id);
            final lyricPair = (isCurrent && _showLyricsOverlay) ? _activeLyricPair() : ('', '');

            final durMs = isCurrent && widget.playerService.duration.inMilliseconds > 0
                ? widget.playerService.duration.inMilliseconds
                : track.duration.inMilliseconds;
            final posMs = isCurrent ? widget.playerService.position.inMilliseconds : 0;
            final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (isCurrent) {
                  isPlaying ? widget.playerService.pause() : widget.playerService.resume();
                } else {
                  widget.playerService.playTrack(track, playlist: _feed);
                }
              },
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                if (!isLiked) widget.playerService.toggleLike(track);
              },
              onLongPress: () => showEchoTrackMenu(
                context,
                track: track,
                playerService: widget.playerService,
                theme: widget.theme,
              ),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred Backdrop
                    if (track.artworkUrl.startsWith('http'))
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                        child: CachedNetworkImage(
                          imageUrl: track.artworkUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    // Top & Bottom Scrim
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),

                    // Centered Artwork / Looping Canvas
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CanvasArtworkPlayer(
                                track: track,
                                enabled: idx == _activeIndex &&
                                    widget.playerService.isCanvasEnabled &&
                                    !widget.playerService.isDataSaverEnabled,
                                isPlaying: isPlaying,
                                borderRadius: 24,
                              ),
                              if (!isPlaying)
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    size: 56,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Bar + 2-Line Animated Synced Lyrics
                    Positioned(
                      top: 10,
                      left: 18,
                      right: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Music Flow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _showLyricsOverlay
                                          ? Icons.lyrics_rounded
                                          : Icons.lyrics_outlined,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        setState(() => _showLyricsOverlay = !_showLyricsOverlay),
                                  ),
                                  if (widget.onOpenFullPlayer != null)
                                    IconButton(
                                      icon: const Icon(Icons.open_in_full_rounded,
                                          color: Colors.white, size: 20),
                                      onPressed: widget.onOpenFullPlayer,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (lyricPair.$1.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              child: Column(
                                key: ValueKey(lyricPair.$1),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lyricPair.$1,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (lyricPair.$2.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      lyricPair.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.48),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Bottom Metadata + Action Row + Progress Bar (above floating dock)
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 108 + MediaQuery.of(context).padding.bottom,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isLiked ? widget.theme.primary : Colors.white,
                                    ),
                                    onPressed: () => widget.playerService.toggleLike(track),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.lyrics_outlined, color: Colors.white),
                                    onPressed: () =>
                                        setState(() => _showLyricsOverlay = !_showLyricsOverlay),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                                    onPressed: () => OdesliService.shareTrack(track),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isDownloaded
                                          ? Icons.download_done_rounded
                                          : Icons.download_rounded,
                                      color: isDownloaded ? widget.theme.primary : Colors.white,
                                    ),
                                    onPressed: () => DownloadService().downloadTrack(track),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                                    onPressed: () => showEchoTrackMenu(
                                      context,
                                      track: track,
                                      playerService: widget.playerService,
                                      theme: widget.theme,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.5,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
      ],
    );
  }
}
