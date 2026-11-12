import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/download_service.dart';
import '../services/extension_engine.dart';
import '../services/link_parser_service.dart';
import '../services/local_music_service.dart';
import '../theme/animated_touch.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_provider.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final AppTheme theme;

  const LibraryScreen({
    super.key,
    required this.playerService,
    required this.theme,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  final DownloadService _downloadService = DownloadService();
  final LocalMusicService _localMusicService = LocalMusicService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.playerService.addListener(_onServiceChange);
    _downloadService.addListener(_onServiceChange);
    _localMusicService.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    widget.playerService.removeListener(_onServiceChange);
    _downloadService.removeListener(_onServiceChange);
    _localMusicService.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All', 'Playlists', 'Liked Songs', 'Local Music', 'Downloaded', 'History'];

  void _showCreatePlaylistDialog() {
    final theme = AppThemeProvider.of(context);
    final controller = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.isDarkMode ? const Color(0xFF0D1424) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.playlist_add_rounded, color: theme.primary),
              const SizedBox(width: 10),
              Text('Create or Import Playlist', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter name or paste Spotify / YouTube link...',
                  hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6), fontSize: 12.5),
                  filled: true,
                  fillColor: theme.primary.withValues(alpha: 0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.primary, width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.content_paste_rounded, color: theme.primary, size: 18),
                    tooltip: 'Paste from Clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text?.trim() ?? '';
                      if (text.isNotEmpty) {
                        controller.text = text;
                        setDialogState(() {});
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '💡 Paste any Spotify playlist/album link or YouTube playlist to import all real tracks automatically.',
                style: TextStyle(fontSize: 11, color: theme.textSecondary),
              ),
              if (isImporting) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Extracting authentic tracks from link...', style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.primaryForeground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isImporting
                  ? null
                  : () async {
                      final input = controller.text.trim();
                      if (input.isEmpty) return;

                      if (input.startsWith('http://') || input.startsWith('https://') || input.contains('spotify.com') || input.contains('youtube.com') || input.contains('youtu.be')) {
                        setDialogState(() => isImporting = true);
                        final parseResult = await LinkParserService().parseUrl(input);
                        if (!mounted) return;

                        if (parseResult.isPlaylist && parseResult.playlist != null) {
                          final pl = parseResult.playlist!;
                          final name = pl.title.isNotEmpty ? pl.title : 'Imported Playlist';
                          widget.playerService.createPlaylist(name);
                          widget.playerService.savePlaylist(name, pl.tracks);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Successfully imported "$name" with ${pl.tracks.length} authentic songs!'),
                              backgroundColor: theme.primary,
                            ),
                          );
                          setState(() {});
                          return;
                        } else if (parseResult.isTrack && parseResult.track != null) {
                          final trk = parseResult.track!;
                          widget.playerService.createPlaylist('Imported Songs');
                          widget.playerService.addToPlaylist('Imported Songs', trk);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Added "${trk.title}" to Imported Songs'),
                              backgroundColor: theme.primary,
                            ),
                          );
                          setState(() {});
                          return;
                        } else {
                          setDialogState(() => isImporting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(parseResult.errorMessage ?? 'Could not extract songs from this link.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                      }

                      // Normal custom playlist creation
                      widget.playerService.createPlaylist(input);
                      Navigator.pop(ctx);
                      setState(() {});
                    },
              child: Text(isImporting ? 'Importing...' : 'Save Playlist'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlaylistDetails(String playlistName, List<Track> tracks, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentTracks = widget.playerService.userPlaylists[playlistName] ?? [];

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            decoration: BoxDecoration(
              color: theme.scaffoldBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: theme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlistName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                          Text(
                            '${currentTracks.length} tracks in playlist',
                            style: TextStyle(fontSize: 13, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Delete Playlist',
                      onPressed: () {
                        widget.playerService.deletePlaylist(playlistName);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    if (currentTracks.isNotEmpty) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primary,
                            foregroundColor: theme.primaryForeground,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            widget.playerService.playPlaylist(playlistName);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00FFC6),
                            side: const BorderSide(color: Color(0xFF00FFC6), width: 1.2),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            _downloadService.downloadPlaylist(playlistName, currentTracks);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloading ${currentTracks.length} tracks from "$playlistName"...'),
                                backgroundColor: const Color(0xFF00FFC6),
                              ),
                            );
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primary,
                          side: BorderSide(color: theme.primary.withValues(alpha: 0.5), width: 1.2),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Songs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          _showAddSongsToPlaylistModal(playlistName, theme, () {
                            setSheetState(() {});
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: currentTracks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.queue_music_rounded, color: theme.primary.withValues(alpha: 0.4), size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No tracks in this playlist yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.textSecondary, fontSize: 14),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primary,
                                  foregroundColor: theme.primaryForeground,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.search_rounded, size: 18),
                                label: const Text('Search & Add Songs', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  _showAddSongsToPlaylistModal(playlistName, theme, () {
                                    setSheetState(() {});
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: currentTracks.length,
                          itemBuilder: (context, idx) {
                            final track = currentTracks[idx];
                            final isDown = _downloadService.isDownloaded(track.id);
                            final isDownloading = _downloadService.isDownloading(track.id);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: track.artworkUrl,
                                  width: 44,
                                  height: 44,
                                  memCacheWidth: 88,
                                  memCacheHeight: 88,
                                  fit: BoxFit.cover,
                                  placeholder: (ctx, _) => Container(
                                    width: 44,
                                    height: 44,
                                    color: theme.cardBg,
                                    child: Icon(Icons.music_note, color: theme.primary, size: 20),
                                  ),
                                  errorWidget: (ctx, _, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: theme.cardBg,
                                    child: Icon(Icons.music_note, color: theme.primary, size: 20),
                                  ),
                                ),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: theme.textSecondary, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDownloading)
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        value: _downloadService.getProgress(track.id),
                                        strokeWidth: 2,
                                        color: const Color(0xFF00FFC6),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: Icon(
                                        isDown ? Icons.check_circle_rounded : Icons.download_rounded,
                                        color: isDown ? const Color(0xFF00FFC6) : theme.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        _downloadService.downloadTrack(track);
                                        setSheetState(() {});
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      widget.playerService.removeFromPlaylist(playlistName, track.id);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                widget.playerService.playTrack(track, playlist: currentTracks);
                                Navigator.pop(ctx);
                              },
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = AppThemeProvider.of(context);
    final liked = widget.playerService.likedTracks;
    final history = widget.playerService.history;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HERO VAULT BADGE (When Marvels Theme is Active)
          if (theme.isMarvels) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Text(
                    theme.marvelHero == 'panther'
                        ? '🐾'
                        : theme.marvelHero == 'spider'
                            ? '🕸️'
                            : theme.marvelHero == 'cap'
                                ? '🛡️'
                                : theme.marvelHero == 'infinity'
                                    ? '💎'
                                    : theme.marvelHero == 'thor'
                                        ? '⚡'
                                        : theme.marvelHero == 'deadpool'
                                            ? '⚔️'
                                            : '⚡',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      theme.marvelHero == 'panther'
                          ? 'WAKANDAN ROYAL AUDIO VAULT'
                          : theme.marvelHero == 'spider'
                              ? 'SPIDER-VERSE CASSETTE VAULT'
                              : theme.marvelHero == 'cap'
                                  ? 'S.H.I.E.L.D. CLASSIFIED ARCHIVES'
                                  : theme.marvelHero == 'infinity'
                                      ? 'COSMIC INFINITY COLLECTION'
                                      : theme.marvelHero == 'thor'
                                          ? 'ASGARDIAN BIFROST AUDIO VAULT'
                                          : theme.marvelHero == 'deadpool'
                                              ? 'DEADPOOL CHIMICHANGA TAPES'
                                              : 'STARK INDUSTRIES ARCHIVES',
                      style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Music',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    color: theme.primary,
                    onPressed: _showCreatePlaylistDialog,
                  ),
                  const SizedBox(width: 4),
                  AnimatedTouch(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => SettingsScreen(
                            playerService: widget.playerService,
                            theme: theme,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primary.withValues(alpha: 0.35)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.settings_rounded,
                          color: theme.primary,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = _selectedTabIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.primary : theme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? theme.primary : theme.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? theme.primaryForeground : theme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Content Switching
          if (_selectedTabIndex == 0) ...[
            _buildPlaylistsView(theme),
            const SizedBox(height: 24),
            _buildLikedHeader(theme, liked),
            const SizedBox(height: 20),
            if (liked.isNotEmpty) ...[
              Text('Liked Tracks (${liked.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 14),
              _buildTrackList(theme, liked, 'No liked songs yet.'),
              const SizedBox(height: 20),
            ],
            if (history.isNotEmpty) ...[
              Text('Recently Played (${history.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
              const SizedBox(height: 14),
              _buildTrackList(theme, history, 'No playback history yet.'),
            ],
          ] else if (_selectedTabIndex == 1) ...[
            _buildPlaylistsView(theme),
          ] else if (_selectedTabIndex == 2) ...[
            _buildLikedHeader(theme, liked),
            const SizedBox(height: 20),
            Text('Liked Tracks (${liked.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            const SizedBox(height: 14),
            _buildTrackList(theme, liked, 'No liked songs yet. Tap the heart icon on any song!'),
          ] else if (_selectedTabIndex == 3) ...[
            _buildLocalMusicView(theme),
          ] else if (_selectedTabIndex == 4) ...[
            _buildDownloadedView(theme),
          ] else if (_selectedTabIndex == 5) ...[
            Text('Recently Played (${history.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            const SizedBox(height: 14),
            _buildTrackList(theme, history, 'No playback history yet.'),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalMusicView(AppTheme theme) {
    final localTracks = _localMusicService.localTracks;
    final isScanning = _localMusicService.isScanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF00FFC6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.folder_copy_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local & Device Music',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${localTracks.length} tracks found on device',
                          style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: theme.primaryForeground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: isScanning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        isScanning ? 'Scanning...' : 'Scan Storage',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: isScanning
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              final ok = await _localMusicService.scanLocalLibrary();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? '✓ Found ${_localMusicService.localTracks.length} local audio files'
                                        : 'Could not scan local files. Check storage permissions in Settings.'),
                                    backgroundColor: ok ? theme.primary : Colors.redAccent,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primary,
                        side: BorderSide(color: theme.primary.withValues(alpha: 0.6), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.audio_file_rounded, size: 18),
                      label: const Text(
                        'Select Files',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        final count = await _localMusicService.pickAudioFiles();
                        if (mounted && count > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Added $count audio file(s) to Local Music!'),
                              backgroundColor: theme.primary,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primary,
                      side: BorderSide(color: theme.primary.withValues(alpha: 0.6), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                    ),
                    child: const Icon(Icons.create_new_folder_rounded, size: 18),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      final count = await _localMusicService.pickFolderAndScan();
                      if (mounted && count > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Indexed $count tracks from selected folder!'),
                            backgroundColor: theme.primary,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (localTracks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.audio_file_outlined, size: 54, color: theme.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No local music loaded yet.',
                    style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Scan Device Music" to auto-import MP3, FLAC, and M4A files from your device, or "Browse Files" to pick files.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tracks (${localTracks.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
              ),
              TextButton.icon(
                icon: Icon(Icons.play_arrow_rounded, color: theme.primary, size: 20),
                label: Text('Play All', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  widget.playerService.playTrack(localTracks.first, playlist: localTracks);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTrackList(theme, localTracks, 'No local music found.'),
        ],
      ],
    );
  }

  Widget _buildDownloadedView(AppTheme theme) {
    final downloaded = _downloadService.downloadedTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FFC6), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.download_done_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Downloads',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${downloaded.length} offline songs saved on device',
                      style: TextStyle(fontSize: 13, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (downloaded.isNotEmpty)
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF00FFC6)),
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    widget.playerService.playTrack(downloaded.first, playlist: downloaded);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Downloaded Songs (${downloaded.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
        const SizedBox(height: 14),
        _buildTrackList(theme, downloaded, 'No offline downloaded songs yet. Download any song or playlist!'),
      ],
    );
  }

  Widget _buildLikedHeader(AppTheme theme, List<Track> liked) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liked Songs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${liked.length} tracks saved',
                  style: TextStyle(fontSize: 13, color: theme.textSecondary),
                ),
              ],
            ),
          ),
          if (liked.isNotEmpty)
            AnimatedTouch(
              onTap: () => widget.playerService.playTrack(liked.first, playlist: liked),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: theme.primaryForeground, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsView(AppTheme theme) {
    final playlists = widget.playerService.userPlaylists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cloud Sync Header Banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFC6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF00FFC6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Sync: Spotify & YouTube', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Auto-sync your playlists to Library', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary.withValues(alpha: 0.2),
                  foregroundColor: theme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.primary.withValues(alpha: 0.4)),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _showCloudSyncSheet(theme);
                },
                child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        if (playlists.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 60, color: theme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No custom playlists yet', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Tap the + button above to create your first playlist or connect Spotify/YouTube.', style: TextStyle(color: theme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: playlists.keys.length,
            itemBuilder: (context, index) {
              final name = playlists.keys.elementAt(index);
              final list = playlists[name]!;
              final isSpotify = name.toLowerCase().contains('spotify');
              final isYouTube = name.toLowerCase().contains('youtube');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _openPlaylistDetails(name, list, theme);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSpotify
                                ? const Color(0xFF1DB954).withValues(alpha: 0.2)
                                : isYouTube
                                    ? const Color(0xFFFF0033).withValues(alpha: 0.2)
                                    : theme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSpotify
                                ? Icons.stream_rounded
                                : isYouTube
                                    ? Icons.smart_display_rounded
                                    : Icons.queue_music_rounded,
                            color: isSpotify
                                ? const Color(0xFF1DB954)
                                : isYouTube
                                    ? const Color(0xFFFF0033)
                                    : theme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSpotify)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Spotify', style: TextStyle(color: Color(0xFF1DB954), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  if (isYouTube)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF0033).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('YouTube', style: TextStyle(color: Color(0xFFFF0033), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${list.length} tracks', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                            ],
                          ),
                        ),
                        if (list.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.play_arrow_rounded, color: theme.primary),
                            onPressed: () => widget.playerService.playPlaylist(name),
                          ),
                        Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTrackList(AppTheme theme, List<Track> tracks, String emptyMessage) {
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Text(emptyMessage, style: TextStyle(color: theme.textSecondary)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = widget.playerService.currentTrack?.id == track.id;
        final isDown = _downloadService.isDownloaded(track.id);
        final isDownloading = _downloadService.isDownloading(track.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AnimatedTouch(
            onTap: () => widget.playerService.playTrack(track, playlist: tracks),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent ? theme.primary.withValues(alpha: 0.15) : theme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? theme.primary : theme.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: track.artworkUrl,
                      width: 48,
                      height: 48,
                      memCacheWidth: 96,
                      memCacheHeight: 96,
                      fit: BoxFit.cover,
                      placeholder: (ctx, _) => Container(
                        width: 48,
                        height: 48,
                        color: theme.cardBg,
                        child: Icon(Icons.music_note, color: theme.primary, size: 22),
                      ),
                      errorWidget: (ctx, _, ___) => Container(
                        width: 48,
                        height: 48,
                        color: theme.cardBg,
                        child: Icon(Icons.music_note, color: theme.primary, size: 22),
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
                            color: isCurrent ? theme.primary : theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isDownloading)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: _downloadService.getProgress(track.id),
                          strokeWidth: 2,
                          color: const Color(0xFF00FFC6),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        isDown ? Icons.check_circle_rounded : Icons.download_rounded,
                        color: isDown ? const Color(0xFF00FFC6) : theme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _downloadService.downloadTrack(track);
                        setState(() {});
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.playlist_add_rounded,
                      color: theme.primary,
                      size: 22,
                    ),
                    tooltip: 'Add to Playlist',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showPickPlaylistDialog(track, theme);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      widget.playerService.isTrackLiked(track.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: widget.playerService.isTrackLiked(track.id) ? Colors.redAccent : theme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => widget.playerService.toggleLike(track),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPickPlaylistDialog(Track track, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final playlists = widget.playerService.userPlaylists.keys.toList();

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            decoration: BoxDecoration(
              color: theme.scaffoldBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: theme.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.playlist_add_rounded, color: theme.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Add to Playlist',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a playlist for "${track.title}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: theme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Button to Create New Playlist directly
                AnimatedTouch(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreatePlaylistDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: theme.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Create New Playlist',
                          style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No playlists yet. Create one above!',
                        style: TextStyle(color: theme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, idx) {
                        final pName = playlists[idx];
                        final pTracks = widget.playerService.userPlaylists[pName] ?? [];
                        final alreadyIn = pTracks.any((t) => t.id == track.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: AnimatedTouch(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (alreadyIn) {
                                widget.playerService.removeFromPlaylist(pName, track.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Removed "${track.title}" from "$pName"'),
                                    backgroundColor: theme.cardBg,
                                  ),
                                );
                              } else {
                                widget.playerService.addToPlaylist(pName, track);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added "${track.title}" to "$pName"'),
                                    backgroundColor: theme.primary,
                                  ),
                                );
                              }
                              Navigator.pop(ctx);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: alreadyIn
                                    ? theme.primary.withValues(alpha: 0.12)
                                    : theme.cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: alreadyIn ? theme.primary : theme.cardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.queue_music_rounded,
                                    color: alreadyIn ? theme.primary : theme.textSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pName,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${pTracks.length} tracks',
                                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    alreadyIn ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                    color: alreadyIn ? theme.primary : theme.textSecondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  void _showAddSongsToPlaylistModal(String playlistName, AppTheme theme, VoidCallback onUpdated) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSongsToPlaylistSheet(
        playlistName: playlistName,
        playerService: widget.playerService,
        theme: theme,
        onPlaylistUpdated: onUpdated,
      ),
    );
  }

  void _showCloudSyncSheet(AppTheme theme) {
    final spotifyController = TextEditingController();
    final ytController = TextEditingController();
    final cloudSync = CloudSyncService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFC6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF00FFC6), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connect Accounts (Cloud Sync)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Sign in with your email or playlist link to auto-sync', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Spotify Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stream_rounded, color: Color(0xFF1DB954), size: 20),
                        const SizedBox(width: 8),
                        const Text('Sign in with Spotify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        if (cloudSync.isSpotifyConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Connected', style: TextStyle(color: Color(0xFF1DB954), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: spotifyController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF1DB954), size: 18),
                        hintText: 'Spotify Email or Playlist Link',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () async {
                          final text = spotifyController.text.trim();
                          if (text.isNotEmpty) {
                            await cloudSync.connectSpotify(text, widget.playerService);
                            setModalState(() {});
                            if (mounted) setState(() {});
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Spotify Playlists Synced for $text!'),
                                backgroundColor: const Color(0xFF1DB954),
                              ),
                            );
                          }
                        },
                        child: const Text('Authorize & Sync Spotify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // YouTube Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF0033).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_display_rounded, color: Color(0xFFFF0033), size: 20),
                        const SizedBox(width: 8),
                        const Text('Sign in with Google / YouTube', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        if (cloudSync.isYouTubeConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0033).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Connected', style: TextStyle(color: Color(0xFFFF0033), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ytController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFFFF0033), size: 18),
                        hintText: 'Google/YouTube Email or Channel Link',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0033),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () async {
                          final text = ytController.text.trim();
                          if (text.isNotEmpty) {
                            await cloudSync.connectYouTube(text, widget.playerService);
                            setModalState(() {});
                            if (mounted) setState(() {});
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ YouTube Music Synced for $text!'),
                                backgroundColor: const Color(0xFFFF0033),
                              ),
                            );
                          }
                        },
                        child: const Text('Authorize & Sync YouTube', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }
}

class _AddSongsToPlaylistSheet extends StatefulWidget {
  final String playlistName;
  final AudioPlayerService playerService;
  final AppTheme theme;
  final VoidCallback onPlaylistUpdated;

  const _AddSongsToPlaylistSheet({
    required this.playlistName,
    required this.playerService,
    required this.theme,
    required this.onPlaylistUpdated,
  });

  @override
  State<_AddSongsToPlaylistSheet> createState() => _AddSongsToPlaylistSheetState();
}

class _AddSongsToPlaylistSheetState extends State<_AddSongsToPlaylistSheet> {
  int _activeTab = 0; // 0 = Search Online, 1 = Recents & Liked
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<Track> _searchResults = [];
  final Set<String> _addedTrackIds = {};

  @override
  void initState() {
    super.initState();
    final existing = widget.playerService.userPlaylists[widget.playlistName] ?? [];
    for (final t in existing) {
      _addedTrackIds.add(t.id);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 80), () async {
      final results = await ExtensionEngine().searchAcrossAllSources(clean);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _addTrack(Track track) {
    HapticFeedback.mediumImpact();
    widget.playerService.addToPlaylist(widget.playlistName, track);
    widget.onPlaylistUpdated();
    setState(() {
      _addedTrackIds.add(track.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('Added "${track.title}" to ${widget.playlistName}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final recentTracks = <Track>[];
    final seen = <String>{};

    for (final t in [...widget.playerService.history, ...widget.playerService.likedTracks]) {
      if (seen.add(t.id)) {
        recentTracks.add(t);
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Songs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      'to ${widget.playlistName}',
                      style: TextStyle(fontSize: 13, color: theme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tab Selector Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? theme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 15,
                              color: _activeTab == 0 ? theme.primaryForeground : theme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Search Online',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 0 ? theme.primaryForeground : theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? theme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 15,
                              color: _activeTab == 1 ? theme.primaryForeground : theme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Local Music',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 1 ? theme.primaryForeground : theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 2 ? theme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 15,
                              color: _activeTab == 2 ? theme.primaryForeground : theme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Recent/Liked',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 2 ? theme.primaryForeground : theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Search Box (if Tab 0)
          if (_activeTab == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  cursorColor: theme.primary,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search any track across universal catalogs...',
                    hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: theme.primary, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Content List
          Expanded(
            child: _activeTab == 0
                ? _buildSearchResults(theme)
                : _activeTab == 1
                    ? _buildLocalMusicList(theme)
                    : _buildRecentAndLikedList(recentTracks, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppTheme theme) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(color: theme.primary, strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text('Searching music catalogs...', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_searchCtrl.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, color: theme.primary.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 12),
            Text(
              'Type song, artist, or album name\nto add tracks directly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No tracks found for "${_searchCtrl.text}"', style: TextStyle(color: theme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      itemCount: _searchResults.length,
      itemBuilder: (context, idx) {
        final track = _searchResults[idx];
        final isAdded = _addedTrackIds.contains(track.id);

        return _buildTrackAddTile(track, isAdded, theme);
      },
    );
  }

  Widget _buildLocalMusicList(AppTheme theme) {
    final localTracks = DownloadService().downloadedTracks;
    if (localTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded, color: theme.textSecondary.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 12),
            Text(
              'No local downloaded music found on device.\nDownload any song to add to your offline library!',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      itemCount: localTracks.length,
      itemBuilder: (context, idx) {
        final track = localTracks[idx];
        final isAdded = _addedTrackIds.contains(track.id);

        return _buildTrackAddTile(track, isAdded, theme);
      },
    );
  }

  Widget _buildRecentAndLikedList(List<Track> recentTracks, AppTheme theme) {
    if (recentTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded, color: theme.textSecondary.withValues(alpha: 0.4), size: 44),
            const SizedBox(height: 10),
            Text('No recently played or liked songs yet.', style: TextStyle(color: theme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      itemCount: recentTracks.length,
      itemBuilder: (context, idx) {
        final track = recentTracks[idx];
        final isAdded = _addedTrackIds.contains(track.id);

        return _buildTrackAddTile(track, isAdded, theme);
      },
    );
  }

  Widget _buildTrackAddTile(Track track, bool isAdded, AppTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: track.artworkUrl,
              width: 44,
              height: 44,
              memCacheWidth: 88,
              memCacheHeight: 88,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 44,
                height: 44,
                color: theme.scaffoldBg,
                child: Icon(Icons.music_note, color: theme.primary, size: 20),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 44,
                height: 44,
                color: theme.scaffoldBg,
                child: Icon(Icons.music_note, color: theme.primary, size: 20),
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
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
              ],
            ),
          ),
          AnimatedTouch(
            onTap: isAdded ? null : () => _addTrack(track),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isAdded ? Colors.green.withValues(alpha: 0.18) : theme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAdded ? Colors.green : theme.primary,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAdded ? Icons.check_rounded : Icons.add_rounded,
                    size: 16,
                    color: isAdded ? Colors.greenAccent : theme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAdded ? 'Added' : 'Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAdded ? Colors.greenAccent : theme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
