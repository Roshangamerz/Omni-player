import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/extension_engine.dart';
import '../services/share_receiver_service.dart';
import '../theme/animated_touch.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'music_flow_screen.dart';
import 'now_playing_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine extensionEngine;

  const HomeShell({
    super.key,
    required this.playerService,
    required this.extensionEngine,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late final PageController _pageController;
  StreamSubscription<String>? _shareSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _shareSub = ShareReceiverService().statusStream.listen((msg) {
      if (mounted && msg.isNotEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  void _openFullPlayer() {
    final theme = AppThemeProvider.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NowPlayingScreen(
        playerService: widget.playerService,
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: SafeArea(
        bottom: false,
        top: _currentIndex != 1, // Music Flow is full-bleed
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_currentIndex != index) {
                    setState(() => _currentIndex = index);
                  }
                },
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  HomeScreen(
                    playerService: widget.playerService,
                    extensionEngine: widget.extensionEngine,
                    theme: theme,
                    onNavigateTab: _onTabTapped,
                  ),
                  MusicFlowScreen(
                    playerService: widget.playerService,
                    extensionEngine: widget.extensionEngine,
                    theme: theme,
                    onOpenFullPlayer: _openFullPlayer,
                  ),
                  ExploreScreen(
                    playerService: widget.playerService,
                    theme: theme,
                  ),
                  SearchScreen(
                    playerService: widget.playerService,
                    extensionEngine: widget.extensionEngine,
                    theme: theme,
                  ),
                  LibraryScreen(
                    playerService: widget.playerService,
                    theme: theme,
                  ),
                ],
              ),

              // Floating Liquid Glass Mini-Player + Floating 5-Tab Bar
              ListenableBuilder(
                listenable: widget.playerService,
                builder: (context, _) {
                  final currentTrack = widget.playerService.currentTrack;
                  return Stack(
                    children: [
                      if (currentTrack != null && _currentIndex != 1)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 78 + bottomPad,
                          child: _buildFloatingMiniPlayer(currentTrack, theme),
                        ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12 + bottomPad,
                        child: _buildFloatingGlassDock(theme),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMiniPlayer(Track track, AppTheme theme) {
    final pos = widget.playerService.position;
    final dur = widget.playerService.duration.inMilliseconds > 0
        ? widget.playerService.duration
        : track.duration;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isLiked = widget.playerService.isTrackLiked(track.id);

    return Dismissible(
      key: ValueKey('mini_player_${track.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.playerService.stopAndClear();
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white),
      ),
      child: AnimatedTouch(
        onTap: _openFullPlayer,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: BoxDecoration(
                color: theme.isDarkMode
                    ? const Color(0xFF141418).withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.isDarkMode
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      EchoArtwork(url: track.artworkUrl, size: 44, radius: 12),
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
                                fontWeight: FontWeight.w700,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? theme.primary : theme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.playerService.toggleLike(track);
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.playerService.togglePlayPause();
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primary,
                          ),
                          child: Center(
                            child: widget.playerService.isBuffering
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: theme.primaryForeground,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    widget.playerService.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: theme.primaryForeground,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.2,
                      backgroundColor: theme.textSecondary.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingGlassDock(AppTheme theme) {
    final items = [
      (icon: Icons.home_rounded, label: 'Home'),
      (icon: Icons.graphic_eq_rounded, label: 'Flow'),
      (icon: Icons.explore_rounded, label: 'Explore'),
      (icon: Icons.search_rounded, label: 'Search'),
      (icon: Icons.library_music_rounded, label: 'Library'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.isDarkMode
                ? const Color(0xFF121216).withValues(alpha: 0.80)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTabTapped(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentIndex == i
                            ? theme.primary.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[i].icon,
                            size: 21,
                            color: _currentIndex == i ? theme.primary : theme.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: _currentIndex == i ? FontWeight.w800 : FontWeight.w600,
                              color: _currentIndex == i ? theme.primary : theme.textSecondary,
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
    );
  }
}
