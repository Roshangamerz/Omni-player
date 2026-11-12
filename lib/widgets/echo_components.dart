import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/music_dna_service.dart';
import '../services/odesli_service.dart';
import '../theme/app_theme.dart';

/// Echo Music Scalloped / Starburst Expressive Play-Pause Button
class ExpressivePlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTap;
  final double size;
  final Color fillColor;
  final Color iconColor;

  const ExpressivePlayButton({
    super.key,
    required this.isPlaying,
    required this.isBuffering,
    required this.onTap,
    this.size = 72,
    this.fillColor = Colors.white,
    this.iconColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ScallopPainter(color: fillColor, lobes: 10),
          child: Center(
            child: isBuffering
                ? SizedBox(
                    width: size * 0.34,
                    height: size * 0.34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: iconColor,
                    size: size * 0.48,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScallopPainter extends CustomPainter {
  final Color color;
  final int lobes;

  _ScallopPainter({required this.color, this.lobes = 10});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width * 0.455;
    final amp = size.width * 0.045;
    final path = Path();
    const steps = 120;
    for (int i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2 * math.pi;
      final r = baseR + amp * math.cos(lobes * theta);
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ScallopPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lobes != lobes;
}

/// Echo Music DESIGN.md Translucent Surface Card (24dp radius, flat elevation 0)
class EchoSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const EchoSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05));
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: box,
      ),
    );
  }
}

/// Crisp Artwork Widget with CachedNetworkImage & graceful fallback
class EchoArtwork extends StatelessWidget {
  final String url;
  final double size;
  final double radius;

  const EchoArtwork({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (size * 2.5).round().clamp(120, 900),
                placeholder: (_, __) => Container(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white38),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white.withValues(alpha: 0.08),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                ),
              )
            : Container(
                color: Colors.white.withValues(alpha: 0.08),
                child: const Icon(Icons.music_note_rounded, color: Colors.white54),
              ),
      ),
    );
  }
}

/// Echo Music Rich Track Options Sheet (Play Next, Queue, Playlist, Download, Music DNA, Song.link, Ringtone)
Future<void> showEchoTrackMenu(
  BuildContext context, {
  required Track track,
  required AudioPlayerService playerService,
  required AppTheme theme,
}) async {
  HapticFeedback.selectionClick();
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final isLiked = playerService.isTrackLiked(track.id);
      final isDownloaded = DownloadService().isDownloaded(track.id);
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? const Color(0xFF141418).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    EchoArtwork(url: track.artworkUrl, size: 54, radius: 14),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? theme.primary : theme.textSecondary,
                      ),
                      onPressed: () {
                        playerService.toggleLike(track);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: theme.textSecondary.withValues(alpha: 0.14), height: 1),
                const SizedBox(height: 8),
                _menuTile(
                  theme,
                  Icons.playlist_play_rounded,
                  'Play Next',
                  () {
                    playerService.addToQueueNext(track);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing "${track.title}" next')),
                    );
                  },
                ),
                _menuTile(
                  theme,
                  Icons.queue_music_rounded,
                  'Add to Queue',
                  () {
                    playerService.appendToQueue(track);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added "${track.title}" to queue')),
                    );
                  },
                ),
                _menuTile(
                  theme,
                  Icons.playlist_add_rounded,
                  'Add to Playlist',
                  () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistPicker(context, track, playerService, theme);
                  },
                ),
                _menuTile(
                  theme,
                  isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                  isDownloaded ? 'Downloaded Offline' : 'Download Offline',
                  () async {
                    Navigator.pop(ctx);
                    if (!isDownloaded) {
                      await DownloadService().downloadTrack(track);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloaded "${track.title}"')),
                        );
                      }
                    }
                  },
                ),
                _menuTile(
                  theme,
                  Icons.biotech_rounded,
                  'Music DNA (Story & Bio)',
                  () {
                    Navigator.pop(ctx);
                    showMusicDnaSheet(context, track: track, theme: theme);
                  },
                ),
                _menuTile(
                  theme,
                  Icons.share_rounded,
                  'Share via Song.link (Odesli)',
                  () async {
                    Navigator.pop(ctx);
                    await OdesliService.shareTrack(track);
                  },
                ),
                _menuTile(
                  theme,
                  Icons.notifications_active_outlined,
                  'Set as Ringtone',
                  () async {
                    Navigator.pop(ctx);
                    final localPath = DownloadService().getLocalPath(track.id);
                    if (localPath == null || localPath.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Download the track offline first to set as ringtone.')),
                      );
                      return;
                    }
                    final res = await OdesliService.setRingtone(localPath, track.title);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.ok
                              ? 'Ringtone set to "${track.title}"'
                              : res.needsPermission
                                  ? 'Please allow "Modify system settings" and try again'
                                  : 'Could not set ringtone'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _menuTile(AppTheme theme, IconData icon, String label, VoidCallback onTap) {
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
    leading: Icon(icon, color: theme.textPrimary, size: 22),
    title: Text(
      label,
      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
    ),
    onTap: onTap,
  );
}

Future<void> _showAddToPlaylistPicker(
  BuildContext context,
  Track track,
  AudioPlayerService playerService,
  AppTheme theme,
) async {
  final names = playerService.userPlaylists.keys.toList();
  await showModalBottomSheet(
    context: context,
    backgroundColor: theme.isDarkMode ? const Color(0xFF141418) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add to Playlist',
            style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final name in names)
            ListTile(
              leading: Icon(Icons.queue_music_rounded, color: theme.primary),
              title: Text(name, style: TextStyle(color: theme.textPrimary)),
              subtitle: Text(
                '${playerService.userPlaylists[name]?.length ?? 0} tracks',
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                playerService.addToPlaylist(name, track);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to "$name"')),
                );
              },
            ),
        ],
      ),
    ),
  );
}

/// Echo Music "Music DNA" Bottom Sheet (Genius + Wikipedia Track Story & Artist Bio)
Future<void> showMusicDnaSheet(
  BuildContext context, {
  required Track track,
  required AppTheme theme,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.68,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? const Color(0xFF101014).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FutureBuilder(
              future: MusicDnaService().fetchMusicDna(
                title: track.title,
                artist: track.artist,
                album: track.album,
              ),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.primary),
                        const SizedBox(height: 14),
                        Text('Decoding Music DNA via Genius & Wikipedia...',
                            style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  );
                }
                final dna = snap.data!;
                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(22),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.textSecondary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.biotech_rounded, color: theme.primary, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          'Music DNA',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    EchoSurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ALBUM / RELEASE',
                              style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1)),
                          const SizedBox(height: 4),
                          Text(dna.album,
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    EchoSurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ABOUT THIS TRACK',
                              style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          Text(dna.aboutSong,
                              style: TextStyle(
                                  color: theme.textPrimary, fontSize: 14, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    EchoSurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ARTIST BIOGRAPHY',
                              style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          Text(dna.artistBio,
                              style: TextStyle(
                                  color: theme.textPrimary, fontSize: 14, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
