import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/lyrics_service.dart';
import '../services/odesli_service.dart';
import '../theme/app_theme.dart';
import '../widgets/canvas_artwork_player.dart';
import '../widgets/echo_components.dart';
import '../widgets/retro_turntable_player.dart';
import 'equalizer_screen.dart';

/// Echo Music Reconstructed Now Playing Screen
/// Supports Apple Inspired Mode, Material Expressive Mode (Scalloped Play Button),
/// Fullscreen Word-by-Word Synced Lyrics with Provider Switcher + AI Translation + Offset,
/// Ambient Mode, Queue Drawer, Sleep Timer, and Music DNA.
class NowPlayingScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final AppTheme theme;

  const NowPlayingScreen({
    super.key,
    required this.playerService,
    required this.theme,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyrics = false;
  bool _ambientMode = false;
  bool _dragging = false;
  double _dragFraction = 0.0;

  // Lyrics state
  String _lastTrackId = '';
  String _lyricsProvider = 'Auto';
  bool _loadingLyrics = false;
  bool _hasWordSync = false;
  bool _showTranslation = false;
  bool _translating = false;
  int _timingOffsetMs = 0;
  List<LyricLine> _lyrics = const [];
  final ScrollController _lyricsScroll = ScrollController();
  int _activeLineIdx = -1;

  @override
  void initState() {
    super.initState();
    widget.playerService.addListener(_onPlayerUpdate);
    _syncTrackAndLyrics();
  }

  @override
  void dispose() {
    widget.playerService.removeListener(_onPlayerUpdate);
    _lyricsScroll.dispose();
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    _syncTrackAndLyrics();
    if (_showLyrics && _lyrics.isNotEmpty) {
      _updateActiveLyricIndex();
    }
    setState(() {});
  }

  void _syncTrackAndLyrics() {
    final track = widget.playerService.currentTrack;
    if (track != null && track.id != _lastTrackId) {
      _lastTrackId = track.id;
      _loadLyrics(track);
    }
  }

  Future<void> _loadLyrics(Track track, {String? provider, bool force = false}) async {
    setState(() {
      _loadingLyrics = true;
      _showTranslation = false;
    });
    final offset = await LyricsService.getTrackOffsetMs(track.id);
    final res = await LyricsService.fetchRichLyrics(
      track,
      preferredProvider: provider == 'Auto' ? null : provider,
      forceRefresh: force,
    );
    if (!mounted || widget.playerService.currentTrack?.id != track.id) return;
    setState(() {
      _timingOffsetMs = offset;
      _lyrics = res.lines;
      _lyricsProvider = res.provider;
      _hasWordSync = res.hasWordSync;
      _loadingLyrics = false;
      _activeLineIdx = -1;
    });
  }

  void _updateActiveLyricIndex() {
    final posMs = widget.playerService.position.inMilliseconds + _timingOffsetMs;
    int idx = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].time.inMilliseconds <= posMs) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _activeLineIdx && idx >= 0) {
      _activeLineIdx = idx;
      if (_lyricsScroll.hasClients) {
        final targetOffset = (idx * 72.0 - 160).clamp(0.0, _lyricsScroll.position.maxScrollExtent);
        _lyricsScroll.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _toggleTranslate() async {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
      return;
    }
    if (_lyrics.any((l) => l.translation != null && l.translation!.isNotEmpty)) {
      setState(() => _showTranslation = true);
      return;
    }
    setState(() => _translating = true);
    final translated = await LyricsService.translateLyrics(_lyrics);
    if (!mounted) return;
    setState(() {
      _lyrics = translated;
      _translating = false;
      _showTranslation = true;
    });
  }

  Future<void> _adjustOffset(int deltaMs) async {
    final track = widget.playerService.currentTrack;
    if (track == null) return;
    final next = _timingOffsetMs + deltaMs;
    setState(() => _timingOffsetMs = next);
    await LyricsService.setTrackOffsetMs(track.id, next);
  }

  void _showQueueSheet() {
    final theme = widget.theme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final queue = widget.playerService.playlist;
          final curId = widget.playerService.currentTrack?.id;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Up Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${queue.length} tracks • Omni Brain ${widget.playerService.isOmniBrainEnabled ? "ON" : "OFF"}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      Switch(
                        value: widget.playerService.isOmniBrainEnabled,
                        activeThumbColor: theme.primary,
                        onChanged: (v) {
                          widget.playerService.toggleOmniBrain(v);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: scrollCtrl,
                    itemCount: queue.length,
                    onReorder: (oldI, newI) {
                      widget.playerService.reorderQueue(oldI, newI);
                      setModalState(() {});
                    },
                    itemBuilder: (_, i) {
                      final item = queue[i];
                      final isCur = item.id == curId;
                      return ListTile(
                        key: ValueKey('q_${item.id}_$i'),
                        leading: EchoArtwork(url: item.artworkUrl, size: 46, radius: 10),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCur ? theme.primary : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.drag_handle_rounded, color: Colors.white38),
                        onTap: () => widget.playerService.playTrack(item, playlist: queue),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Timer',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final mins in [10, 15, 30, 45, 60])
              ListTile(
                leading: Icon(Icons.timer_outlined, color: widget.theme.primary),
                title: Text('$mins minutes', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  widget.playerService.setSleepTimer(Duration(minutes: mins));
                  Navigator.pop(ctx);
                },
              ),
            if (widget.playerService.sleepTimerRemaining != null)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
                title: const Text('Cancel Sleep Timer', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  widget.playerService.setSleepTimer(null);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAudioSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final s = widget.playerService;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: widget.theme.primary, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Audio & Playback Controls',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Playback Speed
                const Text(
                  'PLAYBACK SPEED',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0.75, 1.0, 1.25, 1.5, 2.0].map((spd) {
                    final isSel = (s.playbackSpeed - spd).abs() < 0.05;
                    return ChoiceChip(
                      label: Text('${spd}x'),
                      selected: isSel,
                      selectedColor: widget.theme.primary,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        s.setPlaybackSpeed(spd);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // DJ Beat Crossfade
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DJ Seamless Crossfade',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          s.isSmartCrossfade ? '${s.crossfadeSeconds}s equal-power fade' : 'Disabled',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: s.isSmartCrossfade,
                      activeThumbColor: widget.theme.primary,
                      onChanged: (v) {
                        s.toggleSmartCrossfade(v);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                if (s.isSmartCrossfade) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [3, 5, 8, 10, 12].map((sec) {
                      final isSel = s.crossfadeSeconds == sec;
                      return ChoiceChip(
                        label: Text('${sec}s'),
                        selected: isSel,
                        selectedColor: widget.theme.primary,
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          s.setCrossfadeSeconds(sec);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // Audio Quality
                const Text(
                  'STREAMING QUALITY',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    {'key': 'auto', 'label': 'Auto'},
                    {'key': '320k', 'label': '320k FLAC'},
                    {'key': '256k', 'label': '256k AAC'},
                    {'key': '128k', 'label': '128k Eco'},
                  ].map((q) {
                    final isSel = s.streamingQuality == q['key'];
                    return ChoiceChip(
                      label: Text(q['label']!),
                      selected: isSel,
                      selectedColor: widget.theme.primary,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        s.setStreamingQuality(q['key']!);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackBadges() {
    final s = widget.playerService;
    return GestureDetector(
      onTap: _showAudioSettingsSheet,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 12, color: widget.theme.primary),
                    const SizedBox(width: 4),
                    Text(
                      s.activeQualityBadge,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (s.isSmartCrossfade)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 11, color: widget.theme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${s.crossfadeSeconds}s Fade',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              if (s.playbackSpeed != 1.0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.theme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.theme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${s.playbackSpeed}x Speed',
                    style: TextStyle(color: widget.theme.primary, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              if (s.currentSponsorSegments.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        'SponsorBlock (${s.currentSponsorSegments.length})',
                        style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.playerService.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final isAppleStyle = widget.playerService.playerStyle == 'apple';
    final isPlaying = widget.playerService.isPlaying;
    final isBuffering = widget.playerService.isBuffering;
    final isLiked = widget.playerService.isTrackLiked(track.id);
    final isDownloaded = DownloadService().isDownloaded(track.id);

    final dur = widget.playerService.duration.inMilliseconds > 0
        ? widget.playerService.duration
        : track.duration;
    final pos = widget.playerService.position;
    final fraction = _dragging
        ? _dragFraction
        : (dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Atmospheric Blurred Backdrop (Echo Music Player Backdrop)
          if (track.artworkUrl.startsWith('http'))
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: CachedNetworkImage(
                imageUrl: track.artworkUrl,
                fit: BoxFit.cover,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),

          // APPLE INSPIRED FULL-BLEED BACKGROUND ARTWORK / CANVAS
          if (isAppleStyle && !_showLyrics)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CanvasArtworkPlayer(
                    track: track,
                    enabled: widget.playerService.isCanvasEnabled &&
                        !widget.playerService.isDataSaverEnabled,
                    isPlaying: isPlaying,
                    borderRadius: 0,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.35, 0.65, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.48),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.94),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SafeArea(
            child: _ambientMode
                ? _buildAmbientOverlay(track, isPlaying)
                : _showLyrics
                    ? _buildLyricsView(track, pos, dur, fraction, isPlaying, isBuffering)
                    : widget.playerService.playerStyle == 'vinyl'
                        ? _buildVinylPlayerView(track)
                        : isAppleStyle
                            ? _buildApplePlayerView(
                                track, pos, dur, fraction, isPlaying, isBuffering, isLiked)
                            : _buildMaterialPlayerView(
                                track, pos, dur, fraction, isPlaying, isBuffering, isLiked, isDownloaded),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientOverlay(Track track, bool isPlaying) {
    return GestureDetector(
      onTap: () => setState(() => _ambientMode = false),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'AMBIENT MODE • TAP TO EXIT',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 300,
              height: 300,
              child: CanvasArtworkPlayer(
                track: track,
                enabled: widget.playerService.isCanvasEnabled,
                isPlaying: isPlaying,
                borderRadius: 32,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              track.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              track.artist,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChrome(Track track) {
    final style = widget.playerService.playerStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showAudioSettingsSheet,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(
                    widget.playerService.activeQualityBadge,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (widget.playerService.sleepTimerRemaining != null)
                    Text(
                      'Sleep ${_fmt(widget.playerService.sleepTimerRemaining!)}',
                      style: TextStyle(color: widget.theme.primary, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Switch Player Style (${style == "apple" ? "Apple" : style == "vinyl" ? "Retro Turntable" : "Material"})',
            icon: Icon(
              style == 'vinyl'
                  ? Icons.album_rounded
                  : style == 'apple'
                      ? Icons.fullscreen_rounded
                      : Icons.style_rounded,
              color: style == 'vinyl' ? const Color(0xFFE2B170) : Colors.white,
              size: 22,
            ),
            onPressed: widget.playerService.cyclePlayerStyle,
          ),
          IconButton(
            tooltip: 'Ambient Mode',
            icon: const Icon(Icons.nightlight_round, color: Colors.white, size: 20),
            onPressed: () => setState(() => _ambientMode = true),
          ),
          IconButton(
            tooltip: 'Equalizer',
            icon: const Icon(Icons.equalizer_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EqualizerScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVinylPlayerView(Track track) {
    return Column(
      children: [
        _buildTopChrome(track),
        Expanded(
          child: RetroTurntablePlayer(
            track: track,
            playerService: widget.playerService,
            theme: widget.theme,
            onToggleLyrics: () => setState(() => _showLyrics = !_showLyrics),
            onOpenQueue: _showQueueSheet,
            onOpenEqualizer: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EqualizerScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplePlayerView(
    Track track,
    Duration pos,
    Duration dur,
    double fraction,
    bool isPlaying,
    bool isBuffering,
    bool isLiked,
  ) {
    return Column(
      children: [
        _buildTopChrome(track),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                      onPressed: () => showEchoTrackMenu(
                        context,
                        track: track,
                        playerService: widget.playerService,
                        theme: widget.theme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    child: IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? widget.theme.primary : Colors.white,
                        size: 20,
                      ),
                      onPressed: () => widget.playerService.toggleLike(track),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPlaybackBadges(),
              _buildCapsuleSlider(dur, pos, fraction),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white, size: 42),
                    onPressed: widget.playerService.previous,
                  ),
                  GestureDetector(
                    onTap: widget.playerService.togglePlayPause,
                    child: isBuffering
                        ? const SizedBox(
                            width: 54,
                            height: 54,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 62,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 42),
                    onPressed: widget.playerService.next,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildBottomUtilityBar(track),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialPlayerView(
    Track track,
    Duration pos,
    Duration dur,
    double fraction,
    bool isPlaying,
    bool isBuffering,
    bool isLiked,
    bool isDownloaded,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          _buildTopChrome(track),
          const Spacer(),
          AspectRatio(
            aspectRatio: 1,
            child: CanvasArtworkPlayer(
              track: track,
              enabled: widget.playerService.isCanvasEnabled &&
                  !widget.playerService.isDataSaverEnabled,
              isPlaying: isPlaying,
              borderRadius: 26,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  icon: Icon(
                    isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                    color: Colors.black,
                  ),
                  onPressed: () => DownloadService().downloadTrack(track),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? widget.theme.primary : Colors.black,
                  ),
                  onPressed: () => widget.playerService.toggleLike(track),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPlaybackBadges(),
          _buildCapsuleSlider(dur, pos, fraction),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                child: IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 30),
                  onPressed: widget.playerService.previous,
                ),
              ),
              ExpressivePlayButton(
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                onTap: widget.playerService.togglePlayPause,
                size: 82,
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                child: IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
                  onPressed: widget.playerService.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildBottomUtilityBar(track),
        ],
      ),
    );
  }

  Widget _buildLyricsView(
    Track track,
    Duration pos,
    Duration dur,
    double fraction,
    bool isPlaying,
    bool isBuffering,
  ) {
    final effectivePosMs = pos.inMilliseconds + _timingOffsetMs;

    return Column(
      children: [
        // Lyrics Header Toolbar (Provider Switcher, Offset, AI Translate)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => setState(() => _showLyrics = false),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF18181D),
                onSelected: (prov) => _loadLyrics(track, provider: prov, force: true),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'Auto', child: Text('Auto (Best Sync)', style: TextStyle(color: Colors.white))),
                  for (final p in LyricsService.allProviders)
                    PopupMenuItem(
                        value: p, child: Text(p, style: const TextStyle(color: Colors.white))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hasWordSync ? '$_lyricsProvider • Word Sync' : _lyricsProvider,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delay Lyrics (-0.25s)',
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
                onPressed: () => _adjustOffset(-250),
              ),
              Text(
                '${(_timingOffsetMs / 1000).toStringAsFixed(2)}s',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              IconButton(
                tooltip: 'Advance Lyrics (+0.25s)',
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                onPressed: () => _adjustOffset(250),
              ),
              IconButton(
                tooltip: 'AI Translate Lyrics',
                icon: _translating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        Icons.translate_rounded,
                        color: _showTranslation ? widget.theme.primary : Colors.white,
                        size: 21,
                      ),
                onPressed: _translating ? null : _toggleTranslate,
              ),
            ],
          ),
        ),

        // Synced Lyrics List (Word-by-Word when available, Line-by-Line otherwise)
        Expanded(
          child: _loadingLyrics
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView.builder(
                  controller: _lyricsScroll,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  itemCount: _lyrics.length,
                  itemBuilder: (_, i) {
                    final line = _lyrics[i];
                    final isActive = i == _activeLineIdx;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.playerService.seek(line.time);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isActive && line.words.isNotEmpty)
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  for (final w in line.words)
                                    Text(
                                      w.text,
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                        color: effectivePosMs >= w.start.inMilliseconds
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.42),
                                      ),
                                    ),
                                ],
                              )
                            else
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                style: TextStyle(
                                  fontSize: isActive ? 25 : 21,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                  height: 1.28,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.42),
                                ),
                                child: Text(line.text),
                              ),
                            if (_showTranslation &&
                                line.translation != null &&
                                line.translation!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  line.translation!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: isActive ? 0.85 : 0.45),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Compact Song Bar + Scalloped Play Button (matches Echo lyrics.png)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  EchoArtwork(url: track.artworkUrl, size: 48, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.biotech_rounded, color: Colors.white),
                    tooltip: 'Music DNA',
                    onPressed: () => showMusicDnaSheet(
                      context,
                      track: track,
                      theme: widget.theme,
                    ),
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
              const SizedBox(height: 14),
              _buildCapsuleSlider(dur, pos, fraction),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                      onPressed: widget.playerService.previous,
                    ),
                  ),
                  ExpressivePlayButton(
                    isPlaying: isPlaying,
                    isBuffering: isBuffering,
                    onTap: widget.playerService.togglePlayPause,
                    size: 76,
                  ),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    child: IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                      onPressed: widget.playerService.next,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapsuleSlider(Duration dur, Duration pos, double fraction) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
          ),
          child: Slider(
            value: fraction.clamp(0.0, 1.0),
            onChangeStart: (v) => setState(() {
              _dragging = true;
              _dragFraction = v;
            }),
            onChanged: (v) => setState(() => _dragFraction = v),
            onChangeEnd: (v) {
              setState(() => _dragging = false);
              final target = Duration(milliseconds: (dur.inMilliseconds * v).round());
              widget.playerService.seek(target);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomUtilityBar(Track track) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          tooltip: 'Synced Lyrics',
          icon: const Icon(Icons.lyrics_outlined, color: Colors.white),
          onPressed: () => setState(() => _showLyrics = true),
        ),
        IconButton(
          tooltip: 'Music DNA',
          icon: const Icon(Icons.biotech_rounded, color: Colors.white),
          onPressed: () => showMusicDnaSheet(context, track: track, theme: widget.theme),
        ),
        IconButton(
          tooltip: 'Shuffle / Smart Shuffle',
          icon: Icon(
            Icons.shuffle_rounded,
            color: widget.playerService.isShuffle ? widget.theme.primary : Colors.white70,
          ),
          onPressed: widget.playerService.cycleShuffleMode,
        ),
        IconButton(
          tooltip: 'Repeat Mode',
          icon: Icon(
            widget.playerService.repeatMode == PlaybackRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: widget.playerService.repeatMode != PlaybackRepeatMode.off
                ? widget.theme.primary
                : Colors.white70,
          ),
          onPressed: widget.playerService.toggleRepeat,
        ),
        IconButton(
          tooltip: 'Sleep Timer',
          icon: Icon(
            Icons.timer_outlined,
            color: widget.playerService.sleepTimerRemaining != null
                ? widget.theme.primary
                : Colors.white70,
          ),
          onPressed: _showSleepTimerDialog,
        ),
        IconButton(
          tooltip: 'Playback Controls & FX',
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
          onPressed: _showAudioSettingsSheet,
        ),
        IconButton(
          tooltip: 'Up Next Queue',
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
          onPressed: _showQueueSheet,
        ),
        IconButton(
          tooltip: 'Share via Song.link',
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          onPressed: () => OdesliService.shareTrack(track),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
