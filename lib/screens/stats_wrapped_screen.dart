import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';

/// Echo Music Listening Stats & Omni Wrapped Screen
class StatsWrappedScreen extends StatelessWidget {
  final AudioPlayerService playerService;

  const StatsWrappedScreen({super.key, required this.playerService});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);
    final stats = StatsService();

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textPrimary,
          title: const Text('Stats & Wrapped', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListenableBuilder(
          listenable: stats,
          builder: (context, _) {
            final topTracks = stats.topTracks;
            final topArtists = stats.topArtists;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // Wrapped Hero Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [theme.primary, theme.secondary, const Color(0xFF141418)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OMNI WRAPPED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats.totalMinutes} mins listened',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${stats.totalPlays} plays across ${stats.uniqueSongs} unique tracks',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (topArtists.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Top Artist: ${topArtists.first.artist} (${topArtists.first.plays} plays)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'TOP ARTISTS',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (topArtists.isEmpty)
                  EchoSurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Start playing music to generate your artist rankings.',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  )
                else
                  SizedBox(
                    height: 136,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topArtists.take(10).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final a = topArtists[i];
                        return SizedBox(
                          width: 96,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  EchoArtwork(url: a.artworkUrl, size: 84, radius: 42),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: theme.primary,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${a.plays} plays',
                                style: TextStyle(color: theme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 22),
                Text(
                  'MY TOP TRACKS',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (topTracks.isEmpty)
                  EchoSurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Your most played tracks will appear here.',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  )
                else
                  EchoSurfaceCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (int i = 0; i < topTracks.take(25).length; i++)
                          ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
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
                                EchoArtwork(url: topTracks[i].artworkUrl, size: 46, radius: 12),
                              ],
                            ),
                            title: Text(
                              topTracks[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              topTracks[i].artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.textSecondary, fontSize: 12),
                            ),
                            trailing: Text(
                              '${topTracks[i].playCount}x',
                              style: TextStyle(
                                color: theme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
